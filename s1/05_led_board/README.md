# S1-05 第一个上板实验：LED 流水灯 + 按键，先 AXU4EVB-E，再移植到 FZ5D

## 为什么做这个

走通一次 FPGA 的完整流程：**RTL → 综合 → 实现 → 生成比特流 → 通过 JTAG 下载到板子**。
然后把同一份 RTL 移植到第二块板，体会换板时什么不变、什么要改：RTL 不变，约束文件（引脚、电平、时钟）全要重查。

这个实验没有 testbench 和参考代码：LED 电路是你自己写的第一个上板设计，引脚只能对着两块板各自的原理图查。

## 先弄清三个概念

- **约束文件（.xdc）**：告诉 Vivado 你的 Verilog 端口 `led[0]` 接到芯片哪个引脚、用什么电平标准（比如 `LVCMOS33`）。写错了轻则不亮，重则损坏器件。
- **PL 时钟从哪来**：有的板子在 PL 侧有独立晶振（差分或单端），可以直接用；有的板子 PL 没有晶振，要在 Block Design 里放一个 Zynq UltraScale+ MPSoC IP，用它输出的 `pl_clk0`。两块板分别属于哪种，查各自的原理图。
- **比特流（.bit）**：实现完成后生成的配置文件，JTAG 下载后断电即丢失，正好适合做实验。

## 步骤：AXU4EVB-E（照 ALINX 教程）

1. 打开 ALINX 资料包里 AXU4EVB-E 的 Vivado 教程，找到 LED 实验那一章，确认这几项并记下来：
   - 芯片型号（应为 `xczu4ev-sfvc784-1-i`）；
   - PL 时钟的引脚和频率；
   - LED、按键的引脚和电平标准。
2. Vivado 新建 RTL 工程，选对芯片型号。
3. 自己写 `led_flow.v`：
   - 用计数器把时钟分频到约 4 Hz；
   - 每到一次让 LED 移一位，做成流水灯；
   - 按住按键时流水灯暂停（或者反向）。
   - 按键要先过两级寄存器同步，再用来控制。
4. 写 `.xdc`，内容大致如下，引脚以教程和原理图为准：
   ```tcl
   set_property PACKAGE_PIN <时钟引脚> [get_ports clk]
   set_property IOSTANDARD  <电平标准> [get_ports clk]
   create_clock -period <周期 ns> [get_ports clk]
   set_property PACKAGE_PIN <引脚> [get_ports {led[0]}]
   set_property IOSTANDARD  LVCMOS33 [get_ports {led[0]}]
   # ... 其余 LED 和按键
   ```
   如果 PL 侧没有晶振，就改用 Block Design + Zynq IP 的 `pl_clk0`，不写 `create_clock`。
5. 依次 Run Synthesis → Run Implementation → Generate Bitstream。看一眼 Timing Summary，WNS 应为正数。
6. 板子接上 JTAG 并上电，Open Hardware Manager → Auto Connect → Program Device。LED 开始流动就成功了。

## 步骤：移植到 FZ5D

1. 从米尔 FZ5 资料包里找原理图，查清这几项：FZ5D 的芯片型号和封装、有没有接到 PL 的用户 LED 和按键、PL 时钟从哪来。
   如果 PL 上没有可用的 LED，就改用 PS 的 UART 打印或 GPIO，并把这一点记进下面的差异表。
2. 新建一个工程（或者复制工程后修改芯片型号），**RTL 一行不改**，只重写 `.xdc`。
3. 综合、实现、下载。
4. 填一张差异表，S2 会继续往这张表里加东西：

   | 项目 | AXU4EVB-E | FZ5D |
   |---|---|---|
   | 芯片型号 / 封装 | | |
   | PL 时钟来源和频率 | | |
   | LED 引脚 / 电平 | | |
   | 按键引脚 / 电平 | | |
   | JTAG 接口形式 | | |

## 做完的标志

- 两块板上的流水灯都能运行，按键能控制。
- 有一张填好的差异表。
- 能说清：从 RTL 到比特流的五个步骤各自做什么；为什么换板只改约束文件。

## 常见问题

- Hardware Manager 找不到板子：JTAG 驱动没装，或者 USB 没直通进虚拟机。也可以在接板子的机器上跑 `hw_server`，见 S2 的环境说明。
- 生成比特流时报 `NSTD-1` 或 `UCIO-1`：有端口没指定电平标准或引脚，检查 `.xdc`。
- LED 常亮不闪：分频计数器位宽不够，或者把 MHz 和 Hz 算错了。
