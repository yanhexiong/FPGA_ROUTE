# S1-05 第一个上板实验：PS 最小系统与 PL 流水灯

## 实验目的

完整走通一次 Zynq UltraScale+ MPSoC 的开发流程，并建立 PS（Processing System，处理系统，即 ARM 处理器及其外设）与 PL（Programmable Logic，可编程逻辑，即 FPGA 部分）的基本概念：

1. **仿真**：以 testbench 验证 PL 侧的流水灯 RTL（无需开发板）；
2. **PS 最小系统**：在 Vivado 中配置 PS（DDR、串口、GPIO），导出 XSA，在 Vitis 中运行裸机程序并经串口输出；
3. **PS 控制外设**：用 PS 的 GPIO 驱动板上的 RUN 指示灯；
4. **PL 上板**：将流水灯下载到 PL，经 JTAG 以 VIO 观察其输出；
5. **对照**：在 AXU4EVB-E 上复用同一份 RTL，比较两块开发板的差异。

主力板 EdgeBoard FZ5D 的 PL 侧**没有**用户 LED 与用户按键，无法按常见的“PL 驱动 LED”方式完成实验，因此第 3、4 步分别以 PS 侧的 RUN 灯与 JTAG 调试核（VIO）替代。这一差异本身是本实验要体会的内容之一：不同开发板可供使用的外设不同，实验方案须依据硬件资料确定。

## 准备工作

1. 按 [`setup/vivado.md`](../../setup/vivado.md) 安装 Vivado/Vitis 2023.1，并运行其中的检查脚本，确认输出 `CHECK PASSED`。
2. 仿真工具 Icarus Verilog 与 GTKWave（见 S1-01）。
3. FZ5D 开发板，以及：
   - 12 V/3 A 以上的电源（接 J16）；
   - Micro-USB 线一根（接 J13，调试串口）；
   - JTAG 下载器一个，接到 J1（要求见下节「JTAG 下载器的要求」）；
   - 串口终端软件：Ubuntu 可用 `minicom` 或 `screen`，Windows 可用 PuTTY。J13 上的 USB 转串口芯片为 CP2102N，Windows 须安装其驱动（Silicon Labs 提供），Ubuntu 内核自带驱动。
4. FZ5D 硬件资料（硬件说明文档、原理图、MYIR 的 FPGA 指导手册）。该资料不公开发布，由课程内部提供。本实验的硬件信息均取自这些资料，列于下表，实验者应当自行对照核实。

## FZ5D 本实验所用的硬件资源

| 资源 | 位置与连接 | 说明 |
|---|---|---|
| 芯片 | XCZU5EV，封装 SFVC784，Vivado 器件名 `xczu5ev-sfvc784-1-i` | 须核对芯片表面的型号标注 |
| PS 侧 DDR | DDR4，64 位，8 GB（另有 4 GB 版本） | DDR 参数随版本不同，配置前须先确认手中板卡的容量 |
| 调试串口 | J13（Micro-USB，CP2102N 桥接）→ PS UART0：MIO26 为 RX，MIO27 为 TX | 115200 波特，8 位数据，无校验，1 位停止，无流控 |
| RUN 指示灯 | D46（绿色），经三极管 Q2 由 PS 的 MIO42 驱动 | **唯一可由程序控制的用户 LED**；有效电平待实物确认 |
| 复位按键 | S1、S2 | 仅用于复位，不是用户按键 |
| PL 侧用户 LED / 按键 | **无** | PL 的引脚只引到扩展接口 J15 与视频接口 |
| PL 时钟 | 本实验使用 PS 输出的 `pl_clk0` | 不使用 PL 侧外部时钟 |
| JTAG | J1，6 针 2.54 mm 排针：1 VREF_3.3V，2 TDI，3 TDO，4 TCK，5 TMS，6 GND | 引脚名标注在 PCB 背面。MYIR 快速使用指南写作“J13”，与硬件说明文档不一致，以硬件说明文档与板上标注为准 |
| 启动模式开关 SW1 | 拨码开关，1–4 位依次对应 PS_MODE0–PS_MODE3；ON 表示 0，OFF 表示 1 | JTAG 模式：四位全部拨至 ON（0000）。TF 卡启动为 1010，QSPI 启动为 0100 |

### JTAG 下载器的要求

PS 的初始化、比特流下载与 Vitis 的调试运行，都经 J1 的 JTAG 完成。J13 只是 USB 转串口，**不能代替下载器**。

| 项目 | 要求 |
|---|---|
| 型号 | Vivado 的 `hw_server` 支持的下载器：Xilinx Platform Cable USB II 及其兼容品，或 Digilent JTAG-HS2 / HS3。Intel USB-Blaster 等其他厂商的下载器，以及通用的 FT2232 调试板，一般不被 Vivado 支持 |
| 接口 | J1 为 6 针 2.54 mm 排针，引脚依次为 VREF_3.3V、TDI、TDO、TCK、TMS、GND。下载器的引线须**按引脚名称**一一对应连接，不得按位置猜测 |
| 电平 | VREF 必须连接：下载器据此识别目标板的 I/O 电压（此处为 3.3 V），并使 TDI、TDO、TCK、TMS 的电平与之匹配 |
| 驱动 | Windows：安装 Vivado 时勾选电缆驱动；Ubuntu：安装后执行 `install_drivers`，见 [`setup/vivado.md`](../../setup/vivado.md) |
| 引线 | 普通的单根杜邦线即可：母头接 J1 的排针，另一端接下载器的引线端或转接板。线应尽量短（建议 20 cm 以内），6 根线并在一起，不经面包板。JTAG 时钟频率较高，线过长或接触不良时通信不稳定，表现为间歇性识别不到器件；此时可在 Hardware Manager 中右击目标，打开 Hardware Target Properties，降低 JTAG 时钟频率 |

MYIR 快速使用指南的连接图使用 6 根带标签的单根引线，标签依次为 VREF、TDI/DIN、TDO/DONE、TCK/CCLK、TMS/PROG、GND，插在 J1 的 6 个排针上。这是 Platform Cable USB 一类下载器附带的引线，其次序与 J1 的 1–6 脚一致。

**14 针接口的下载器。** 许多下载器（包括 AXU4EVB-E 所用的）为标准 Xilinx 14 针接口，2.0 mm 间距，2×7 排列，不能直接插到 J1（2.54 mm，6 针）。须经 2.0 mm 14 针转 2.54 mm 的转接板，或使用下载器附带的单根引线，按下表连接。14 针接口的常见定义如下，**以下载器的说明与接口上的标注为准**：

| 信号 | 14 针接口的引脚 | J1 的引脚 |
|---|---|---|
| VREF | 2 | 1 |
| TDI | 10 | 2 |
| TDO | 8 | 3 |
| TCK | 6 | 4 |
| TMS | 4 | 5 |
| GND | 任一奇数脚（1、3、5、7、9、11、13） | 6 |
| 其余（12、14） | 不连接 | 不连接 |

上电前须再核对一次 VREF 与 GND 的连接，二者接反会短接板上的 3.3 V 参考电压。连接完成并上电后，在 Hardware Manager 中执行 **Auto Connect**，应当列出 XCZU5EV 的器件；列不出时，先检查 TDI 与 TDO 是否接反，以及 VREF 是否已连接。

> **版本说明。** MYIR 的手册与示例工程基于 Vivado 2020.1，本路线使用 2023.1。本实验不打开 MYIR 的示例工程，而是依据手册的参数在 2023.1 中从零建立；2023.1 中 PS 的 IP 版本更新，对话框的布局可能与手册截图略有不同，但选项名称与取值含义一致。

## 第一步：流水灯 RTL 与仿真

### 已提供的文件

| 文件 | 作用 | 谁来修改 |
|---|---|---|
| `led_flow.v` | 被测模块，仅含端口与 `TODO`，由实验者完成 | 实验者 |
| `tb_led_flow.v` | 验收用 testbench，检查四段行为 | 不得修改 |
| `Makefile` | `make` 编译并运行仿真；`make wave` 打开波形；`make clean` 清理 | 不得修改 |

### 题目

实现模块 `led_flow`：四个 LED 构成一个独热码，每隔固定的时钟周期数向左循环移动一位，`pause` 有效时停止移动。

| 端口 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `clk` | 输入 | 1 | 时钟，上升沿有效 |
| `rst` | 输入 | 1 | 同步复位，高电平有效 |
| `pause` | 输入 | 1 | 暂停，高电平有效。该信号与 `clk` 异步（实际使用时来自按键），须先经两级寄存器同步，再用于控制 |
| `led` | 输出 | 4 | 寄存器输出，任一时刻只有一位为 1（独热码） |

| 参数 | 默认值 | 说明 |
|---|---|---|
| `DIV` | 25 000 000 | 分频系数：每 `DIV` 个时钟周期出现一个**移位时刻**。时钟为 100 MHz 时，`led` 约每秒移位 4 次 |

**行为规定。**

1. **复位。** 在 `rst` 为 1 的时钟上升沿，`led` 置为 `4'b0001`，计数器清零。同步寄存器是否随 `rst` 清零不作要求。
2. **计数与移位时刻。** 复位撤销后，计数器从 0 开始循环计数，周期为 `DIV` 个时钟周期。复位撤销后的第 `DIV`、`2·DIV`、`3·DIV`、… 个上升沿为移位时刻。
3. **移位。** 在移位时刻，若同步后的 `pause` 为 0，则 `led` 循环左移一位（`0001 → 0010 → 0100 → 1000 → 0001`）；若为 1，则 `led` 保持不变。其余时钟上升沿 `led` 不变。
4. **暂停不影响计数。** `pause` 有效期间，计数器照常循环计数，`pause` 只决定移位时刻是否移位。因此 `pause` 撤销后，下一次移位出现在下一个移位时刻，而不是撤销之后再等待 `DIV` 个周期。
5. **同步延迟。** 两级同步使 `pause` 的变化滞后两个时钟周期。`pause` 的变化须至少领先移位时刻 3 个周期，才能对该次移位生效。

**示例时序（`DIV = 4`，`pause` 始终为 0）。** 表中的“上升沿序号”从复位撤销后的第一个上升沿记为 1，`led` 为该上升沿之后的取值：

| 上升沿序号 | 复位时 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| 是否为移位时刻 | | 否 | 否 | 否 | **是** | 否 | 否 | 否 | **是** | 否 |
| `led` | `0001` | `0001` | `0001` | `0001` | `0010` | `0010` | `0010` | `0010` | `0100` | `0100` |

**提示。** 计数器位宽可用 `$clog2(DIV)` 确定；`led` 的左移可写作 `{led[2:0], led[3]}`。

### 运行与判题

```bash
cd labs/s1/05_led_board
make          # 编译并运行；输出 PASS 即通过
make wave     # 用 GTKWave 查看波形（wave.vcd）
```

`tb_led_flow.v` 取 `DIV = 8`，分四段检查：

| 段 | 内容 | 检查点 |
|---|---|---|
| 1 | 复位 | `rst` 持续 3 个周期后，`led = 0001` |
| 2 | 自由运行 | 连续 12 次移位。每次移位前的 `DIV−1` 个周期 `led` 保持不变，第 `DIV` 个周期变为左移后的值 |
| 3 | 暂停与恢复 | `pause = 1` 持续 `4·DIV` 个周期，`led` 保持不变；`pause` 撤销后，下一个移位时刻恢复移位，之后再连续检查 4 次移位 |
| 4 | 运行中复位 | 在两次移位之间复位一个周期，`led` 回到 `0001`，计时重新开始 |

出错时输出 `FAIL`，并给出时刻、所在段与期望值。最多报告 10 处错误；应先分析第一处，其后的错误往往由它引起。

**testbench 无法判定的内容。** 在仿真中，`pause` 的变化发生在时钟沿之后，因此即使省略两级同步，仿真结果也相同。同步寄存器是否存在，须由实验者对照“行为规定”自行检查，它在上板时才起作用。

### 常见错误

| 现象 | 原因 |
|---|---|
| 第 1 段报错，`led` 为 `xxxx` | 复位分支没有给 `led` 赋值，或 `led` 在复位之外才被赋值 |
| 第 2 段第一次移位就不对，`led` 早了或晚了一个周期 | 计数器计到 `DIV` 而不是 `DIV−1`，或复位后计数的起点差一 |
| 第 2 段 `led` 方向相反 | 误写为右移 |
| 第 3 段 `led` 在暂停期间仍然移位 | `pause` 没有参与移位条件，或参与的是未同步的信号 |
| 第 3 段恢复后移位时刻错位 | 暂停时让计数器停止或清零，违反规定 4 |
| 第 4 段复位后第一次移位时刻错位 | 复位没有清零计数器 |

## 第二步：PS 最小系统与 hello_world

本步的目的是建立 PS 侧的最小系统，并确认串口、DDR 与 JTAG 都能工作。后面所有上板实验都建立在这一步之上。

### 2.1 在 Vivado 中建立工程与 PS

1. 新建 RTL 工程，工程路径中不得含有空格或中文。不添加源文件与约束文件。器件选择 `xczu5ev-sfvc784-1-i`。
2. 在 IP Integrator 中选择 **Create Block Design**，名称保持 `design_1`。
3. 在 Block Design 中添加 **Zynq UltraScale+ MPSoC** IP，双击打开配置界面，按下列各表设置。**本步只设置下列必需项**，其余外设（以太网、USB、DP 等）本实验用不到，可保持默认；完整配置见本文末尾的附表。

   **I/O Configuration**

   | 选项 | 取值 |
   |---|---|
   | BANK0 至 BANK3 的 I/O 电压 | LVCMOS33 |
   | UART 0 | 勾选，引脚 MIO26..27 |
   | GPIO 0 MIO、GPIO 1 MIO | 勾选（MIO42 属于 GPIO 1 组，即 MIO26–51） |

   **Clock Configuration**

   | 选项 | 取值 |
   |---|---|
   | PSS_REF_CLK（输入参考时钟） | 33.333 MHz |
   | PL Fabric Clocks 中的 PL0 | 勾选，100 MHz（默认值），即 `pl_clk0` |

   **DDR Configuration（8 GB 版本）。** 先在 *Load DDR Presets* 中选择 `DDR4_MICRON_MT40A256M16GE_083E`，再按下表修改：

   | 选项 | 取值 |
   |---|---|
   | 内存类型 | DDR4 |
   | 数据位宽 | 64 位，ECC 关闭 |
   | 速度等级 | DDR4-2400P（CL / RCD / RP / CWL = 16 / 16 / 16 / 12），DDR 时钟 1200 MHz |
   | 器件位宽 | 16 位 |
   | 单颗器件容量 | 16384 Mb |
   | 行地址位数 | 17 |
   | 列地址位数 | 10 |
   | Bank Group 地址位数 | 1 |
   | Bank 地址位数 | 2 |
   | Rank 数 | 1 |

   以上参数取自 MYIR 手册 3.1.2 节第 5 项的 8 GB 版本截图。4 GB 版本的器件容量等参数不同（手册图 3-30），**配置错误时 PS 初始化阶段会因 DDR 训练失败而无法运行程序**。

4. 本实验不使用 PS 与 PL 之间的 AXI 接口。在 *PS-PL Configuration* 中在 Master Interface 中取消 `AXI HPM0 FPD`、`AXI HPM1 FPD` 与 `AXI HPM0 LPD`，对应的 AXI 时钟引脚随之消失。

### 2.2 生成 XSA

1. 右击 `design_1.bd`，依次执行 **Generate Output Products** 与 **Create HDL Wrapper**（选择由 Vivado 自动管理）。
2. 执行 **Generate Bitstream**。此时 PL 中没有任何逻辑，比特流是空设计，用于满足导出步骤。
3. 执行 **File → Export → Export Hardware**，选择 **Fixed** 与 **Include bitstream**，将 XSA 保存到工程目录下新建的 `vitis` 文件夹。

> **XSA 的作用。** XSA 是 Vivado 向软件工具交付的硬件描述文件，其中包含 PS 的完整配置（DDR 参数、MIO 分配、时钟）与比特流。Vitis 依据它生成 PS 初始化代码；PS 配置与开发板不符时，生成的代码无法在该开发板上运行。

### 2.3 在 Vitis 中运行 hello_world

1. 将开发板的 SW1 四位全部拨至 ON（JTAG 模式），连接电源、J1（JTAG）与 J13（串口），上电。
2. 在串口终端中打开 J13 对应的串口，参数为 115200、8N1、无流控。Ubuntu 上设备名通常为 `/dev/ttyUSB0`（用户须属于 `dialout` 组）：
   ```bash
   screen /dev/ttyUSB0 115200
   ```
3. 在 Vivado 中选择 **Tools → Launch Vitis**，工作区选择 `vitis` 文件夹。
4. 选择 **Create Application Project**，依次设置：
   - 选择 *Create a new platform from hardware (XSA)*，选中上一步导出的 XSA，保持勾选 *Generate boot components*；
   - 应用工程名为 `hello_world`（不得与 Platform 同名），处理器与操作系统保持默认（`standalone`，即裸机）；
   - 模板选择 **Hello World**。
5. 右击应用工程，选择 **Build Project**。
6. 右击应用工程，选择 **Run As → Run Configurations…**，新建 *Single Application Debug*，确认勾选 *Reset entire system*，然后运行（**Run**）。

串口终端应当输出：

```
Hello World
Successfully ran Hello World application
```

至此 PS、DDR、串口与 JTAG 均已验证。

## 第三步：用 PS 的 GPIO 驱动 RUN 灯

目标：让 RUN 灯（D46，PS 的 MIO42）以 1 Hz 闪烁，并每 0.5 s 通过串口输出一行计数。

1. 以 `ps_led.c` 作为框架：将 `hello_world` 工程中 `helloworld.c` 的内容替换为 `ps_led.c` 的内容。
2. 在 Vitis 中展开 Platform 工程，依次打开 BSP 与 `gpiops` 驱动，利用 *Import Examples* 中的 `xgpiops_polled_example` 了解调用顺序，完成 `ps_led.c` 中三处 `TODO`。
3. 编译并运行，观察串口输出与 RUN 灯。

**说明。**

- PS 的 GPIO 引脚号与 MIO 号一致：MIO42 对应引脚号 42。
- RUN 灯的有效电平尚未由资料确认。若程序中 `level = 1` 时灯灭、`level = 0` 时灯亮，说明为低电平有效，不影响实验结论，在后文的差异表中记录即可。

## 第四步：PL 流水灯上板（以 VIO 观察）

FZ5D 的 PL 没有板载 LED，本步借助 **VIO**（Virtual Input/Output）核代替：VIO 是一个下载到 PL 中的调试核，它的输入探针可经 JTAG 在 Vivado 的 Hardware Manager 中读出，输出探针可由 Hardware Manager 写入。因此流水灯的输出 `led[3:0]` 接到 VIO 的输入探针，在计算机上以 4 个指示灯显示；`pause` 与 `rst` 接到 VIO 的输出探针，在计算机上以开关控制。这一方案不占用任何 PL 引脚，因此**无需编写 `.xdc` 约束文件**。

### 4.1 在 Vivado 中加入流水灯与 VIO

1. 将第一步通过仿真的 `led_flow.v` 加入工程（Add Sources）。
2. 在 Block Design 空白处右击，选择 **Add Module…**，加入 `led_flow`。双击该模块，将参数 `DIV` 设为 `100000000`，使流水灯约每秒移动 1 位。VIO 输入探针的刷新周期默认为 500 ms，每秒 4 次的变化会被漏采，难以观察。
3. 添加 **VIO**（Virtual Input/Output）IP，双击配置：
   - 输入探针数量为 1，位宽 4；
   - 输出探针数量为 2，位宽均为 1，其中 `probe_out1`（用作复位）的初始值设为 `0x1`，`probe_out0`（用作暂停）的初始值保持 `0x0`。
4. 按下表连线：

   | 起点 | 终点 |
   |---|---|
   | PS 的 `pl_clk0` | `led_flow` 的 `clk`；VIO 的 `clk` |
   | VIO 的 `probe_out0` | `led_flow` 的 `pause` |
   | VIO 的 `probe_out1` | `led_flow` 的 `rst` |
   | `led_flow` 的 `led[3:0]` | VIO 的 `probe_in0` |

5. 执行 **Validate Design**，无错误后重新生成 HDL Wrapper，再执行 **Generate Bitstream**。实现完成后打开 **Timing Summary**，`WNS`（最差负裕量）应为正值。
6. 重新导出 XSA（**Include bitstream**，覆盖原文件）。

### 4.2 运行并观察

1. 在 Vitis 中右击 Platform 工程，选择 **Update Hardware Specification**，指向新的 XSA（若没有此菜单项，重新新建 Platform 与应用工程即可）。
2. 在 **Run Configurations** 中，勾选 **Program FPGA**，运行 `ps_led`。该操作先初始化 PS，使 `pl_clk0` 开始输出，再下载比特流。**PS 尚未初始化时，PL 没有时钟，VIO 无法被 Hardware Manager 检测到。**
3. 在 Vivado 中依次执行 **Open Hardware Manager → Open Target → Auto Connect**。选中 XCZU5EV 器件，在其属性中将 *Probes file* 指向 `<工程名>.runs/impl_1/design_1_wrapper.ltx`，然后执行 **Refresh Device**，Hardware Manager 中应出现 `hw_vio_1`。
4. 打开 `hw_vio_1` 的面板，添加全部探针：将 `led` 以二进制显示，将 `pause` 与 `rst` 设为开关。观察并记录：

   | 操作 | 预期现象 |
   |---|---|
   | 初始状态（`rst = 1`） | `led` 保持 `0001` |
   | 将 `rst` 置 0 | `led` 约每秒左移一位：`0001 → 0010 → 0100 → 1000 → 0001` |
   | 将 `pause` 置 1 | `led` 保持不变 |
   | 将 `pause` 置 0 | 在下一个移位时刻恢复移位 |
   | 将 `rst` 置 1 | `led` 回到 `0001` 并保持 |

## 对照实验：AXU4EVB-E

AXU4EVB-E 的 PL 侧有用户 LED 与按键，可以直接以板载元件观察同一份流水灯。本部分要体会：RTL 保持不变，板级的 PS 配置、引脚与约束必须重新核对。

1. 查阅 AXU4EVB-E 的硬件资料（ALINX 提供的用户手册与原理图），记录下方差异表中 AXU4EVB-E 一列的各项。该板的芯片型号为 `xczu4ev-sfvc784-1-i`。
2. 新建工程，器件选择 `xczu4ev-sfvc784-1-i`，在 Block Design 中依据 ALINX 资料配置 PS（DDR 容量与位宽、串口所用的 MIO），其余步骤与第二步相同。完成后运行 `hello_world`，确认串口输出。
3. 加入**未经修改**的 `led_flow.v`：`pl_clk0` 接 `clk`，`DIV` 保持默认值 25 000 000；`rst` 接常量 0 或一个按键；`pause` 接一个按键，`led[3:0]` 引出为顶层端口。仅为这些端口编写 `.xdc`，引脚与电平标准以 ALINX 资料为准。
4. 生成比特流并下载，观察板载 LED 流水以及按键暂停。
5. 填写差异表，S2 将在此表的基础上继续补充：

   | 项目 | EdgeBoard FZ5D | AXU4EVB-E |
   |---|---|---|
   | 芯片型号 / 封装 | | |
   | PS 侧 DDR 容量与位宽 | | |
   | PS 调试串口：接口与 MIO | | |
   | 用户 LED：PS 侧 / PL 侧（引脚、有效电平） | | |
   | 用户按键：PS 侧 / PL 侧 | | |
   | PL 时钟来源 | | |
   | JTAG 接口形式 | | |
   | 启动模式的设置方式 | | |
   | 观察 PL 输出的方式 | | |

## 完成标准

- 第一步：`make` 输出 `PASS`。
- FZ5D：串口输出 `Hello World`；RUN 灯按程序闪烁并有串口计数；VIO 面板上的 `led` 按“预期现象”表变化；`WNS` 为正值。
- AXU4EVB-E：板载 LED 流水，按键可使其暂停。
- 差异表填写完整。
- 能够说明：
  - PS 与 PL 各自的作用，为何 FZ5D 的流水灯不需要 `.xdc`；
  - XSA 中包含哪些内容，PS 配置为什么是板级的；
  - 从 RTL 到比特流的五个步骤（综合、实现、生成比特流等）各自的作用。

## 常见问题

- **串口终端没有任何输出。** 依次检查：J13 是否接入（而不是 J1）；终端的端口号与波特率（115200）；`UART 0` 是否勾选在 MIO26..27；SW1 是否为 JTAG 模式。
- **Vitis 运行时报 DDR 初始化或训练失败。** DDR 参数与板卡容量不符。对照 8 GB 与 4 GB 版本重新核对 *DDR Configuration*。
- **Hardware Manager 无法识别开发板。** JTAG 驱动未安装，或 USB 设备未直通至虚拟机，见 [`setup/vivado.md`](../../setup/vivado.md) 的「常见问题」；也检查 JTAG 排线与 J1 的引脚是否一一对应，VREF 是否接 3.3 V。
- **Hardware Manager 中看不到 `hw_vio_1`。** 依次检查：是否已用 Vitis 运行程序（PS 未初始化时 PL 没有时钟）；*Run Configurations* 中是否勾选 *Program FPGA*；*Probes file* 是否指向最新生成的 `.ltx`；导出 XSA 时是否选择了 *Include bitstream*。
- **RUN 灯不亮。** 先确认串口中程序在循环输出；再将 `level` 取反（有效电平可能为低），仍不亮时核对原理图中 Q2 的接法。
- **生成比特流时报告 `NSTD-1` 或 `UCIO-1`。** 存在未指定电平标准或引脚的顶层端口。FZ5D 的设计不应出现该错误；若出现，检查 `led_flow` 的端口是否被误引为顶层端口。在 AXU4EVB-E 上则检查 `.xdc`。

## 附：MYIR 手册的完整 PS 配置（供 S2、S5 复用）

本表取自 MYIR 手册 3.1.2 节，是 FZ5D 的 PS 完整配置，本实验不要求逐项设置。

| 类别 | 外设 | 配置 |
|---|---|---|
| I/O 电压 | BANK0–3 | LVCMOS33 |
| Low Speed | QSPI | 单片（Single），数据模式 x4 |
| | SD 0（eMMC） | MIO13..22，Slot Type 为 eMMC，8 位；Reset 勾选，MIO23 |
| | SD 1（TF 卡） | MIO46..51，SD 2.0，4 位；CD 勾选，MIO45；WP 勾选，MIO44 |
| | CAN 1 | MIO28..29 |
| | I2C 1 | MIO24..25 |
| | UART 0 / UART 1 | MIO26..27 / MIO8..9 |
| | GPIO | GPIO 0 MIO、GPIO 1 MIO |
| | SWDT 0/1、TTC 0 至 3 | 勾选 |
| High Speed | GEM 3 与 MDIO 3 | MIO64..75 / MIO76..77 |
| | USB 0 | MIO52..63，USB 3.0 使用 GT Lane1 |
| | DisplayPort | DPAUX 为 MIO34..37，Lane Selection 为 Dual Higher |
| 时钟 | PSS_REF_CLK / DP / USB 0 | 33.333 MHz / Ref Clk2，27 MHz / Ref Clk1，26 MHz |
| | Full Power Domain | DP_VIDEO 改为 VPLL，DP_AUDIO 与 DP_STC 改为 RPLL |
| DDR | 见第二步 | 按板卡容量设置 |

## 参考资料

| 资料 | 阅读重点 |
|---|---|
| MYIR，*MYS-ZU5EV FPGA 指导手册*（课程内部提供） | 第 3.1 节“第一个工程建立”：Vivado 工程、PS 配置、导出 XSA、Vitis 工程、调试与串口输出 |
| MYIR，*EdgeBoard AI 计算盒及计算卡硬件说明文档* V1.0（课程内部提供） | 第 3.2 节引导模式与 JTAG 模式选择；第 4.2 节中的调试串口与 JTAG 接口 |
| MYIR，原理图 `MYS-ZU5EV-32E4D-EDGE` V13（课程内部提供） | RUN 灯电路（D46、Q2、MIO42）；UART0 的连接 |
| AMD，*Zynq UltraScale+ Device Technical Reference Manual*（UG1085） | PS 的结构、MIO 与 EMIO、GPIO 控制器、启动模式 |
| AMD，*Zynq UltraScale+ MPSoC Processing System LogiCORE IP Product Guide*（PG201） | PS IP 各配置页的含义 |
| AMD，*Virtual Input/Output LogiCORE IP Product Guide*（PG159） | VIO 核的探针与刷新 |

以上 AMD 文档可在 docs.amd.com 以文档编号检索。
