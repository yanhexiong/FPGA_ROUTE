# 从门电路到大模型：FPGA 部署 AI 模型的学习路线

为有 AI 基础、没有硬件基础的研究生设计的学习路线：先打牢数字电路、FPGA 工具和加速器设计的基础，再依次把分类、检测与分割、多模态和语言模型部署到 FPGA 上。

- 在线版：<https://fpga.yahenix.top>
- 主力板：EdgeBoard FZ5D（XCZU5EV）；对照板：ALINX AXU4EVB-E（XCZU4EV）
- 主线约 997 小时，按阶段估算，不按周排期

## 目录

| 路径 | 内容 |
|---|---|
| `web/` | 路线页面（静态 HTML/CSS/JS）。路线内容都在 `web/data.js`，改完刷新即可 |
| `labs/` | 配套实验，**不在本分支**：它是 `main` 分支的 git worktree，本分支的 `.gitignore` 忽略了它 |
| `notes/` | 页面上的勾选进度和笔记，本地服务自动保存到这里 |
| `archive/` | 旧版路线的存档，每份都能单独运行 |
| `FPGA部署AI学习路线*.pdf` | 导出的 PDF |
| `server.py`、`start.sh` | 本地服务：提供页面，并把进度和笔记写进 `notes/` |
| `make_pdf.sh` | 用无头 Chrome 导出带书签的 PDF |
| `build.sh`、`.github/workflows/pages.yml` | 打包在线版，推送后由 GitHub Actions 发布到 GitHub Pages |

## 分支

| 分支 | 内容 | 谁用 |
|---|---|---|
| `main`（默认） | 配套实验代码：规格、接口、验收测试 | 做实验的人，`git clone` 直接拿到 |
| `frontend`（本分支） | 路线页面、PDF、笔记、旧版存档、部署脚本 | 维护路线的人 |

两个分支没有共同的提交历史，互不包含对方的文件。本地同时维护两者：

```bash
git clone -b frontend https://github.com/yanhexiong/FPGA_ROUTE.git FPGA_route
cd FPGA_route
git worktree add labs main      # labs/ 检出 main 分支，在里面提交实验代码
```

## 本地使用

```bash
./start.sh                    # 打开 http://127.0.0.1:8765，勾选和笔记自动保存到 notes/
./make_pdf.sh                 # 导出 PDF（需要 Chrome 或 Chromium）
./make_pdf.sh 路线-v2.pdf     # 指定文件名，避免覆盖旧版
```

只需要 Python 3 标准库，不用装依赖。

## 部署

在线版托管在 GitHub Pages，自定义域名 `fpga.yahenix.top`：

- 推送 `frontend` 分支后，GitHub Actions 自动运行 `build.sh` 并发布，一两分钟后生效。
- 发布的是 `web/` 的 4 个文件，加上 `notes/state.json` 作为进度快照。在线版没有本地服务，访问者的勾选和笔记只存在他们自己的浏览器里。
- 本地预览打包结果：`./build.sh`，产物在 `dist/`（已被 `.gitignore` 忽略）。
