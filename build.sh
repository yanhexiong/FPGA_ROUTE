#!/usr/bin/env bash
# 打包在线版到 dist/：路线页面的 4 个文件，加上当前进度快照 state.json。
# GitHub Actions（.github/workflows/pages.yml）推送 frontend 分支时自动运行它并发布到 GitHub Pages。
# 在线版没有本地服务：页面先读 state.json，之后的勾选和笔记只存在访问者的浏览器里。
set -euo pipefail
cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist
cp web/index.html web/style.css web/app.js web/data.js dist/
# 给 CSS、JS 的引用加上内容指纹（?v=前 8 位哈希）。Cloudflare 让浏览器把这些文件缓存 4 小时，
# 不加指纹的话，页面更新后访问者拿到新的 index.html，却还在用旧的 data.js。
for f in style.css data.js app.js; do
  v=$(sha256sum "dist/$f" | cut -c1-8)
  sed -i "s#\(src\|href\)=\"$f\"#\1=\"$f?v=$v\"#" dist/index.html
done
if [ -f notes/state.json ]; then
  cp notes/state.json dist/state.json
fi
echo "已打包到 dist/：$(ls dist | tr '\n' ' ')"
