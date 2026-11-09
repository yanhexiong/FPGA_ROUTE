# S1-05 第一个上板实验：LED 流水灯与按键控制（先 AXU4EVB-E，后移植到 FZ5D）

## 实验目的

完整走通一次 FPGA 开发流程：**RTL → 综合 → 实现 → 生成比特流 → 通过 JTAG 下载到开发板**。随后将同一份 RTL 移植到第二块开发板，理解更换开发板时哪些内容保持不变、哪些内容需要修改：RTL 保持不变，约束文件中的引脚、电平标准与时钟均须重新核对。

本实验不提供 testbench 与参考代码：LED 电路是实验者独立编写的第一个上板设计，引脚分配只能依据两块开发板各自的原理图确定。

## 基本概念

- **约束文件（.xdc）**：指定 Verilog 端口（如 `led[0]`）连接到芯片的哪一个引脚，以及采用何种电平标准（如 `LVCMOS33`）。约束有误时，轻则电路不工作，重则可能损坏器件。
- **PL 时钟的来源**：部分开发板在 PL 侧配有独立晶振（差分或单端），可直接使用；部分开发板的 PL 侧没有晶振，须在 Block Design 中放置 Zynq UltraScale+ MPSoC IP，使用其输出的 `pl_clk0`。两块开发板分别属于哪一类，须查阅各自的原理图确定。
- **比特流（.bit）**：实现完成后生成的配置文件。通过 JTAG 下载的比特流在断电后丢失，适合实验调试使用。

## 实验步骤：AXU4EVB-E（参照 ALINX 教程）

1. 打开 ALINX 资料包中 AXU4EVB-E 的 Vivado 教程，找到 LED 实验一章，核对并记录以下信息：
   - 芯片型号（应为 `xczu4ev-sfvc784-1-i`）；
   - PL 时钟的引脚与频率；
   - LED 与按键的引脚及电平标准。
2. 在 Vivado 中新建 RTL 工程，选择正确的芯片型号。
3. 独立编写 `led_flow.v`：
   - 以计数器将时钟分频至约 4 Hz；
   - 每个分频周期使 LED 移动一位，形成流水灯；
   - 按键按下期间流水灯暂停（或反向）；
   - 按键信号须先经过两级寄存器同步，再用于控制。
4. 编写 `.xdc` 约束文件，基本格式如下，具体引脚以教程与原理图为准：
   ```tcl
   set_property PACKAGE_PIN <时钟引脚> [get_ports clk]
   set_property IOSTANDARD  <电平标准> [get_ports clk]
   create_clock -period <周期 ns> [get_ports clk]
   set_property PACKAGE_PIN <引脚> [get_ports {led[0]}]
   set_property IOSTANDARD  LVCMOS33 [get_ports {led[0]}]
   # ... 其余 LED 与按键
   ```
   若 PL 侧没有晶振，则改用 Block Design 中 Zynq IP 输出的 `pl_clk0`，此时无需编写 `create_clock`。
5. 依次执行 Run Synthesis → Run Implementation → Generate Bitstream，并查看 Timing Summary，WNS 应为正值。
6. 连接 JTAG 并为开发板上电，依次执行 Open Hardware Manager → Auto Connect → Program Device。LED 开始流动即表示实验成功。

## 实验步骤：移植到 FZ5D

1. 从米尔 FZ5 资料包中查找原理图，确认以下信息：FZ5D 的芯片型号与封装；是否有连接到 PL 的用户 LED 与按键；PL 时钟的来源。
   若 PL 侧没有可用的 LED，则改用 PS 的 UART 输出或 GPIO，并将此差异记入下方的差异表。
2. 新建工程（或复制原工程后修改芯片型号）。**RTL 保持不变**，仅重新编写 `.xdc`。
3. 完成综合、实现与下载。
4. 填写差异表。S2 将在此表的基础上继续补充：

   | 项目 | AXU4EVB-E | FZ5D |
   |---|---|---|
   | 芯片型号 / 封装 | | |
   | PL 时钟来源与频率 | | |
   | LED 引脚 / 电平标准 | | |
   | 按键引脚 / 电平标准 | | |
   | JTAG 接口形式 | | |

## 完成标准

- 两块开发板上的流水灯均能正常运行，并可通过按键控制。
- 完成差异表的填写。
- 能够说明：从 RTL 到比特流的五个步骤各自的作用；更换开发板时为何只需修改约束文件。

## 常见问题

- **Hardware Manager 无法识别开发板。** JTAG 驱动未安装，或 USB 设备未直通至虚拟机。也可以在连接开发板的机器上运行 `hw_server`，详见 S2 的环境说明。
- **生成比特流时报告 `NSTD-1` 或 `UCIO-1` 错误。** 存在未指定电平标准或引脚的端口，请检查 `.xdc`。
- **LED 常亮而不闪烁。** 分频计数器的位宽不足，或混淆了 MHz 与 Hz 的换算。
