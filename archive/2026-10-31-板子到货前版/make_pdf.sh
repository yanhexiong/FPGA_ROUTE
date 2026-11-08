#!/usr/bin/env bash
# 把学习路线导出为 PDF（包含当前的勾选进度和笔记）。
#   ./make_pdf.sh                 输出到 FPGA部署AI学习路线.pdf
#   ./make_pdf.sh 路线-v2.pdf     指定输出文件名
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-FPGA部署AI学习路线.pdf}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
done
if [ -z "$CHROME" ]; then
  echo "没找到 Chrome / Chromium。也可以用 ./start.sh 打开页面，在浏览器里按 Ctrl+P 另存为 PDF。" >&2
  exit 1
fi

# 找一个空闲端口，临时起服务（为了读到 notes/ 里的进度和笔记）
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
python3 -u server.py --no-open --port "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 50); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break
  sleep 0.1
done

PROFILE=$(mktemp -d)
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$PROFILE"' EXIT

"$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$PROFILE" \
  --window-size=794,1123 --virtual-time-budget=10000 \
  --no-pdf-header-footer --generate-pdf-document-outline --print-to-pdf="$OUT" \
  "http://127.0.0.1:$PORT/" 2>/dev/null

if [ ! -s "$OUT" ]; then
  echo "导出失败：没有生成 $OUT" >&2
  exit 1
fi
echo "已导出：$OUT"
