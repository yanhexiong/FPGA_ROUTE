# FPGA 部署 AI 学习路线：配套实验

本仓库是学习路线 <https://fpga.yahenix.top> 的配套代码。路线页面中每个任务均附有“怎么做”说明；需要编写代码的任务，在本仓库中有对应的实验目录，其中的规格说明、接口定义与验收测试均已给出，实验者只需实现电路本身。

```bash
git clone https://github.com/yanhexiong/FPGA_ROUTE.git
cd FPGA_ROUTE/s1/01_first_tb && make
```

路线页面的源码位于 `frontend` 分支，完成实验无需使用该分支。

## 分工

依照路线中“与 AI 助手协同”的约定，各部分的分工如下：

| 已经给出，或可交由 AI 完成 | 须由实验者独立完成 |
|---|---|
| testbench 与验收测试、Python 参考模型、Makefile、环境配置脚本 | 各实验的电路（RTL）；确定应当检查的内容；根据波形定位错误 |

验收测试的作用与 HDLBits 的判题程序相同：完成电路后运行 `make`，输出 PASS 即为通过。未通过时，应从第一条 FAIL 所示的时刻开始分析波形。

## 环境配置（Ubuntu）

```bash
sudo apt install iverilog gtkwave build-essential   # 仿真器、波形查看器、make
python3 -m venv ~/venvs/hdl && source ~/venvs/hdl/bin/activate
pip install cocotb numpy                              # 自 S1-04 起使用 Python 编写测试
```

安装完成后，运行 `iverilog -V` 与 `cocotb-config --version`，能够显示版本号即为安装成功。Verilator 仿真速度更快，但语法检查更为严格，建议在完成 S1 之后再安装。

自 S1-05 起需要 Vivado，安装方法见 [`setup/vivado.md`](setup/vivado.md)，其中分别给出了 Windows 与 Ubuntu（实体机或 KVM 虚拟机）两类环境的安装步骤。

## 目录

| 目录 | 对应任务 | 内容 |
|---|---|---|
| `setup/` | 环境配置 | Vivado 2023.1 安装指南（Windows 与 Ubuntu 两类环境）及安装检查脚本 |
| `s1/01_first_tb/` | 安装仿真工具，运行第一个 testbench | 完整示例：计数器及其 testbench。读懂后自行增加一项检查，并以 `make check` 检验 |
| `s1/02_fifo/` | 带 valid/ready 握手的同步 FIFO | 背景知识、规格、接口与验收测试；实验者实现 FIFO |
| `s1/03_mac/` | INT8 乘加单元 | 规格、接口、Python 参考模型与验收测试；实验者实现 MAC |
| `s1/04_systolic_cocotb/` | 4×4 脉动阵列，以 cocotb 验证 | 规格、接口与 cocotb 测试；实验者实现 PE 与阵列 |
| `s1/05_led_board/` | 第一个上板实验 | 流水灯 RTL 与 testbench（`make` 判题）；在 EdgeBoard FZ5D 上配置 PS、运行 Vitis 裸机程序、驱动 RUN 灯，并以 VIO 观察 PL 流水灯；再在 AXU4EVB-E 上对照，填写差异表 |

S2 及以后各阶段的实验目录将在进入相应阶段时补充，以便根据实际进度调整。

## 通用实验流程

1. 阅读实验 README 中的「实验目的」与「规格」。
2. 画出电路结构图：明确有哪些寄存器，以及每个时钟周期如何更新。
3. 编写 RTL，运行 `make`。
4. 未通过时运行 `make wave` 查看波形，从第一条错误开始分析。
5. 通过后回答 README「完成标准」中的问题，并将答案记入路线页面相应阶段的笔记。

## 参考资料

本仓库仅包含代码，教材与论文不随仓库分发，请从下列出处获取。

### S0 全景认知与路线选型

| 资料 | 出处 | 说明 |
|---|---|---|
| V. Sze, Y.-H. Chen, T.-J. Yang, J. Emer, *Efficient Processing of Deep Neural Networks*, Synthesis Lectures on Computer Architecture, 2020 | [doi:10.1007/978-3-031-01766-7](https://doi.org/10.1007/978-3-031-01766-7) | S0 阶段阅读第 1–2 章。该书为正式出版物，可通过学校图书馆的 SpringerLink 获取 |
| 同一作者的教程页面：书的节选与分章幻灯片 | [eyeriss.mit.edu/tutorial.html](http://eyeriss.mit.edu/tutorial.html) | 由作者公开发布；其中 Overview 与 Popular DNNs 两份幻灯片涵盖第 1–2 章的内容 |
| V. Sze 等, “Efficient Processing of Deep Neural Networks: A Tutorial and Survey,” *Proceedings of the IEEE*, 2017 | [arXiv:1703.09039](https://arxiv.org/abs/1703.09039) | 上述专著的前身，可免费获取，可替代该书的前几章 |
| MIT 6.5930 Hardware Architecture for Deep Learning | [课程主页](https://csg.csail.mit.edu/6.5930/) | 本学期讲义发布于 MIT Canvas，须使用 MIT 账号访问 |
| Vitis AI 文档 | [xilinx.github.io/Vitis-AI](https://xilinx.github.io/Vitis-AI/) | 查阅支持的板卡、模型与 DPU 配置 |
| FINN 文档 | [xilinx.github.io/finn](https://xilinx.github.io/finn/) | 数据流式部署框架，配合 Brevitas 量化工具使用 |
| hls4ml 文档 | [fastmachinelearning.org/hls4ml](https://fastmachinelearning.org/hls4ml/) | 将小型模型直接转换为 HLS 代码 |

### S1 数字电路与 Verilog

| 资料 | 出处 | 用途 |
|---|---|---|
| HDLBits | [hdlbits.01xz.net](https://hdlbits.01xz.net/) | S1 第一个任务 |
| Icarus Verilog | [steveicarus.github.io/iverilog](https://steveicarus.github.io/iverilog/) | 实验 `01`–`03` 使用的仿真器 |
| GTKWave | [gtkwave.sourceforge.net](https://gtkwave.sourceforge.net/) | 波形查看 |
| cocotb | [docs.cocotb.org](https://docs.cocotb.org/) | 实验 `04` 中以 Python 编写 testbench |
| H. T. Kung, “Why Systolic Architectures?”, *IEEE Computer*, 1982 | [doi:10.1109/MC.1982.1653825](https://doi.org/10.1109/MC.1982.1653825) | 实验 `04` 所实现的脉动阵列的原始文献 |
| Vitis HLS 入门示例 | [Xilinx/Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples) | S3 第一个任务 |
