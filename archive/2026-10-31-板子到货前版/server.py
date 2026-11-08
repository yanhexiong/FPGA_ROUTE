#!/usr/bin/env python3
"""学习路线前端的本地服务：提供 web/ 下的静态页面，并把勾选进度和讨论笔记保存到 notes/。

只依赖 Python 标准库。用法见 start.sh。
"""
import argparse
import datetime
import getpass
import json
import os
import socket
import sys
import tempfile
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
WEB_DIR = os.path.join(ROOT, "web")
NOTES_DIR = os.path.join(ROOT, "notes")
STATE_FILE = os.path.join(NOTES_DIR, "state.json")
MD_FILE = os.path.join(NOTES_DIR, "讨论记录.md")
MAX_BODY = 2 * 1024 * 1024
_write_lock = threading.Lock()


def atomic_write(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        # 只打印出错的请求，保持终端干净
        if len(args) > 1 and str(args[1]).startswith(("4", "5")):
            sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def _send_json(self, code: int, payload: bytes) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path.split("?", 1)[0] == "/api/state":
            data = b"{}"
            if os.path.exists(STATE_FILE):
                with open(STATE_FILE, "rb") as f:
                    data = f.read() or b"{}"
            self._send_json(200, data)
            return
        super().do_GET()

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/state":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400, "bad Content-Length")
            return
        if length <= 0 or length > MAX_BODY:
            self.send_error(413 if length > MAX_BODY else 400)
            return
        try:
            body = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self.send_error(400, "invalid JSON")
            return
        state = body.get("state") if isinstance(body, dict) else None
        markdown = body.get("markdown", "") if isinstance(body, dict) else ""
        if not isinstance(state, dict) or not isinstance(markdown, str):
            self.send_error(400, "expected {state: object, markdown: string}")
            return
        with _write_lock:
            atomic_write(STATE_FILE, json.dumps(state, ensure_ascii=False, indent=2))
            atomic_write(MD_FILE, markdown)
        saved_at = datetime.datetime.now().isoformat(timespec="seconds")
        self._send_json(200, json.dumps({"ok": True, "savedAt": saved_at}).encode())


def bind_server(host: str, port: int, tries: int = 20) -> ThreadingHTTPServer:
    last_err = None
    for p in range(port, port + tries):
        try:
            return ThreadingHTTPServer((host, p), Handler)
        except OSError as e:
            last_err = e
    sys.exit(f"端口 {port}-{port + tries - 1} 都被占用了：{last_err}")


def main() -> None:
    ap = argparse.ArgumentParser(description="FPGA 学习路线本地服务")
    ap.add_argument("--host", default=os.environ.get("HOST", "127.0.0.1"),
                    help="监听地址，默认只允许本机访问；用 0.0.0.0 允许局域网访问")
    ap.add_argument("--port", type=int, default=int(os.environ.get("PORT", "8765")))
    ap.add_argument("--no-open", action="store_true", help="不自动打开浏览器")
    args = ap.parse_args()

    httpd = bind_server(args.host, args.port)
    port = httpd.server_address[1]
    url = f"http://127.0.0.1:{port}/"

    print("FPGA 学习路线已启动")
    print(f"  浏览器打开：{url}")
    if args.host == "0.0.0.0":
        print(f"  局域网访问：http://{socket.gethostname()}:{port}/")
    print("  如果这台是远程服务器，在你自己的电脑上执行：")
    print(f"    ssh -N -L {port}:127.0.0.1:{port} {getpass.getuser()}@<服务器地址>")
    print("  然后在本地浏览器打开上面的地址。（VS Code Remote 会自动转发端口）")
    print(f"  勾选和笔记保存在：{os.path.relpath(MD_FILE, ROOT)}")
    print("  按 Ctrl+C 停止")

    has_display = sys.platform in ("darwin", "win32") or os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")
    if has_display and not args.no_open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
