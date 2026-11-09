# FPGA 部署 AI 学习路线：配套实验

这是学习路线 <https://fpga.yahenix.top> 的配套代码。路线页面上每个任务都有“怎么做”；需要动手写代码的任务，这里有对应的目录：规格说明、接口定义、验收测试都已经准备好，你只写电路本身。

```bash
git clone https://github.com/yanhexiong/FPGA_ROUTE.git
cd FPGA_ROUTE/s1/01_first_tb && make
```

路线页面本身的源码在 `frontend` 分支，做实验用不到它。

## 分工

按路线里“和 AI 助手协同”的约定：

| 已经给出，或可以交给 AI | 自己写 |
|---|---|
| testbench / 验收测试、Python 参考模型、Makefile、环境脚本 | 每个实验的电路（RTL）；想清楚“该检查什么”；看波形定位 bug |

验收测试相当于 HDLBits 的判题器：写好电路运行 `make`，打印 PASS 就算通过。没通过时，从第一条 FAIL 的时间点开始看波形。

## 环境（Ubuntu）

```bash
sudo apt install iverilog gtkwave build-essential   # 仿真器、波形查看器、make
python3 -m venv ~/venvs/hdl && source ~/venvs/hdl/bin/activate
pip install cocotb numpy                              # S1-04 起用 Python 写测试
```

装完运行 `iverilog -V`、`cocotb-config --version` 能看到版本号即可。Verilator 更快，但报错更严格，等 S1 做完再装。

## 目录

| 目录 | 对应任务 | 内容 |
|---|---|---|
| `s1/01_first_tb/` | 装好仿真工具，跑通第一个 testbench | 完整示例：计数器 + testbench，读懂后自己加一项检查，用 `make check` 检验 |
| `s1/02_fifo/` | 带 valid/ready 握手的同步 FIFO | 规格 + 接口 + 验收测试，你写 FIFO |
| `s1/03_mac/` | INT8 乘加单元 | 规格 + 接口 + Python 参考模型 + 验收测试，你写 MAC |
| `s1/04_systolic_cocotb/` | 4×4 脉动阵列，cocotb 验证 | 规格 + 接口 + cocotb 测试，你写 PE 和阵列 |
| `s1/05_led_board/` | 第一个上板实验 | Vivado 步骤，先 AXU4EVB-E 再移植 FZ5D，填差异表 |

S2 以后的配套目录，到了那个阶段再补，方便按你当时的实际进度调整。

## 每个实验通用的流程

1. 读 README 里的“为什么做这个”和“规格”。
2. 在纸上画出结构：寄存器有哪些，每拍怎么变。
3. 写 RTL，运行 `make`。
4. 没通过就运行 `make wave` 看波形，从第一条错误开始查。
5. 通过以后回答 README 里“做完的标志”的问题，把答案写进路线页面对应阶段的笔记里。

## 参考资料

仓库只放代码，教材和论文不随仓库分发，请从下面的出处获取。

### S0 全景认知

| 资料 | 出处 | 说明 |
|---|---|---|
| V. Sze, Y.-H. Chen, T.-J. Yang, J. Emer, *Efficient Processing of Deep Neural Networks*, Synthesis Lectures on Computer Architecture, 2020 | [doi:10.1007/978-3-031-01766-7](https://doi.org/10.1007/978-3-031-01766-7) | S0 读第 1–2 章。正式出版物，可以试试学校图书馆的 SpringerLink |
| 同一作者的教程页：书的节选和分章幻灯片 | [eyeriss.mit.edu/tutorial.html](http://eyeriss.mit.edu/tutorial.html) | 作者公开；Overview 和 Popular DNNs 两份幻灯片覆盖第 1–2 章的内容 |
| V. Sze 等, “Efficient Processing of Deep Neural Networks: A Tutorial and Survey,” *Proceedings of the IEEE*, 2017 | [arXiv:1703.09039](https://arxiv.org/abs/1703.09039) | 上面那本书的前身，免费，可以代替书的前几章 |
| MIT 6.5930 Hardware Architecture for Deep Learning | [课程主页](https://csg.csail.mit.edu/6.5930/) | 本学期讲义放在 MIT Canvas 上，需要 MIT 账号 |
| Vitis AI 文档 | [xilinx.github.io/Vitis-AI](https://xilinx.github.io/Vitis-AI/) | 看支持的板卡、模型和 DPU 配置 |
| FINN 文档 | [xilinx.github.io/finn](https://xilinx.github.io/finn/) | 数据流式部署，配合 Brevitas 量化 |
| hls4ml 文档 | [fastmachinelearning.org/hls4ml](https://fastmachinelearning.org/hls4ml/) | 把小模型直接转成 HLS |

### S1 数电与 Verilog

| 资料 | 出处 | 用在 |
|---|---|---|
| HDLBits | [hdlbits.01xz.net](https://hdlbits.01xz.net/) | S1 第一个任务 |
| Icarus Verilog | [steveicarus.github.io/iverilog](https://steveicarus.github.io/iverilog/) | `01`–`03` 的仿真器 |
| GTKWave | [gtkwave.sourceforge.net](https://gtkwave.sourceforge.net/) | 看波形 |
| cocotb | [docs.cocotb.org](https://docs.cocotb.org/) | `04` 用 Python 写 testbench |
| H. T. Kung, “Why Systolic Architectures?”, *IEEE Computer*, 1982 | [doi:10.1109/MC.1982.1653825](https://doi.org/10.1109/MC.1982.1653825) | `04` 脉动阵列的原始文章 |
| Vitis HLS 入门示例 | [Xilinx/Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples) | S3 第一个任务 |
