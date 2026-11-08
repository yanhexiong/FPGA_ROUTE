#!/usr/bin/env bash
# 打包在线版到 dist/：路线页面的 4 个文件，加上当前进度快照 state.json。
# GitHub Actions（.github/workflows/pages.yml）推送 frontend 分支时自动运行它并发布到 GitHub Pages。
# 在线版没有本地服务：页面先读 state.json，之后的勾选和笔记只存在访问者的浏览器里。
set -euo pipefail
cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist
cp web/index.html web/style.css web/app.js web/data.js dist/
if [ -f notes/state.json ]; then
  cp notes/state.json dist/state.json
fi
echo "已打包到 dist/：$(ls dist | tr '\n' ' ')"
