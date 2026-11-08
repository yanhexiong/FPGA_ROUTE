#!/usr/bin/env bash
# 一键启动学习路线前端。
#   ./start.sh              默认 http://127.0.0.1:8765（端口被占用会自动往后找）
#   ./start.sh --port 9000  指定端口
#   ./start.sh --host 0.0.0.0  允许局域网内其他电脑访问
#   ./start.sh --no-open    不自动打开浏览器
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "需要 python3，请先安装。" >&2
  exit 1
fi

exec python3 -u server.py "$@"
