# S1-05 第一个上板实验：PS 最小系统与 PL 流水灯

## 实验目的

完整走通一次 Zynq UltraScale+ MPSoC 的开发流程，并建立 PS（Processing System，处理系统，即 ARM 处理器及其外设）与 PL（Programmable Logic，可编程逻辑，即 FPGA 部分）的基本概念：

1. **仿真**：以 testbench 验证 PL 侧的流水灯 RTL（无需开发板）；
2. **PS 最小系统**：在 Vivado 中配置 PS（DDR、串口、GPIO），导出 XSA，在 Vitis 中运行裸机程序并经串口输出；
3. **PS 控制外设**：用 PS 的 GPIO 驱动板上的 RUN 指示灯；
4. **PL 上板**：将流水灯下载到 PL，经 JTAG 以 VIO 观察其输出；
5. **对照（选做）**：若有 AXU4EVB-E，在其上复用同一份 RTL，比较两块开发板的差异。没有该板不影响本实验的完成。

本实验以 EdgeBoard FZ5D 为必备开发板，第 1 至 4 步只需要这一块板。FZ5D 的 PL 侧**没有**用户 LED 与用户按键，无法按常见的“PL 驱动 LED”方式完成实验，因此第 3、4 步分别以 PS 侧的 RUN 灯与 JTAG 调试核（VIO）替代。这一差异本身是本实验要体会的内容之一：不同开发板可供使用的外设不同，实验方案须依据硬件资料确定。

## 背景知识

### Zynq UltraScale+ MPSoC 的架构：PS 与 PL

Zynq UltraScale+ MPSoC 并非单纯的 FPGA，而是在同一颗芯片内集成了两大部分：

- **PS（Processing System，处理系统）**：硬核处理器子系统，包含 4 核 ARM Cortex-A53 应用处理器、2 核 Cortex-R5 实时处理器，以及硬化的内存控制器（DDR4）与外设控制器（UART、GPIO、QSPI、SD/eMMC、USB、以太网等）。即使 PL 内部没有任何电路，PS 仍可作为一颗完整的嵌入式处理器独立运行 C 程序。
- **PL（Programmable Logic，可编程逻辑）**：传统意义上的 FPGA 可编程逻辑阵列，包含查找表（LUT）、触发器（FF）、DSP48 乘加单元与片上存储（BRAM、URAM）等资源。`led_flow` 等 Verilog 模块综合后即配置在 PL 中。

二者在引脚资源与芯片内部互连上各自有明确的分工：

| 比较项 | PS | PL |
|---|---|---|
| 运行内容 | 裸机 C 程序或嵌入式 Linux（如 Vitis 工程） | 硬件描述语言（Verilog / HLS）综合生成的数字电路 |
| 外部引脚 | 固定连接到 **MIO（Multiplexed I/O，复用 I/O）**，引脚位置由芯片封装决定，不写 `.xdc` | 通用 I/O 引脚（如扩展接口 J15），须由 `.xdc` 约束文件指定引脚号与电平标准 |
| 跨界连接 | 向 PL 提供时钟（如 `pl_clk0`）、复位信号，以及高性能 **AXI** 总线（S2 及以后使用） | 也可借 **EMIO** 将 PS 外设信号引出至 PL 引脚 |

### Vivado 工程、XSA、约束文件与 VIO

1. **为什么 PS 需要 Vivado 配置与 XSA。** PS 虽是硬核，但芯片上电复位后并不了解开发板外围电路的硬件参数：DDR4 的颗粒型号与容量、输入参考时钟频率、UART0 分配在哪些 MIO 引脚上。这些板级参数须在 Vivado 的 Block Design 中配置，并随工程导出为 **XSA（Xilinx Support Archive，硬件支持归档文件）**。XSA 包含两类内容：
   - **PS 硬件配置信息**：供 Vitis 据此生成平台初始化代码（`psu_init` 与 FSBL，在运行用户 `main()` 之前完成时钟、MIO 与 DDR4 训练）以及头文件 `xparameters.h`（记录外设基地址与设备编号宏）；
   - **PL 比特流（Bitstream，`.bit`）**：PL 逻辑的配置数据。
2. **从 RTL 到比特流的主要步骤。** 在 Vivado 中点击生成比特流，工具会依次完成三个阶段（加上此前的仿真与随后的下载，共五个步骤）：
   - **综合（Synthesis）**：将 Verilog 描述翻译为逻辑门与器件原语（LUT、FF 等）构成的网表；
   - **实现（Implementation）**：包括**布局（Place）**与**布线（Route）**，将网表中的每个单元分配到芯片具体的物理位置并连通可编程互连线，同时检查全部路径是否满足时钟周期约束（即报告中的最差负裕量 **WNS ≥ 0**）；
   - **生成比特流（Generate Bitstream）**：将布局布线结果编码为二进制配置数据（`.bit`），下载到 PL 配置存储器后电路即开始工作。
3. **约束文件 `.xdc` 的作用，以及本实验 FZ5D 为何不需要 `.xdc`。** 当设计中存在连接到芯片外部物理引脚的顶层端口时，必须在 `.xdc` 约束文件中指定每根信号的引脚编号（`PACKAGE_PIN`）与电平标准（`IOSTANDARD`），否则生成比特流时会因引脚未分配而报错（`UCIO-1`、`NSTD-1`）。在 FZ5D 的本实验中，`led_flow` 的全部端口仅在芯片内部连接到 PS 的 `pl_clk0` 与 VIO 核，没有任何信号引出到外部 PL 引脚；而 `pl_clk0` 的时钟周期约束由 PS IP 自动生成，因此无需手动编写 `.xdc`。选做的 AXU4EVB-E 将 `led[3:0]` 与 `pause` 引出到板载物理引脚，则必须编写 `.xdc`。
4. **VIO（Virtual Input/Output）调试核的原理。** VIO 是在 PL 中开辟的一组可经 JTAG 读写的虚拟寄存器：输入探针（`probe_in`）按时钟采样 PL 内部信号并传回计算机上的 Hardware Manager 显示，输出探针（`probe_out`）则接收计算机写入的值并直接驱动 PL 信号。导出生成的 `.ltx` 探针描述文件记录了各探针的名称、位宽与地址，使 Hardware Manager 能将二进制位映射为指示灯与开关。**VIO 核与被测模块共用 `pl_clk0`；若 PS 尚未初始化，`pl_clk0` 无时钟输出，Hardware Manager 将无法检测到 `hw_vio_1`。**

### 流水灯电路的设计原理（第一步 `led_flow.v`）

**1. 独热码（One-Hot）与循环左移。** 独热码指 N 位二进制数在任意时刻有且仅有一位为 1，其余各位为 0。4 位独热码共有四种合法取值：`4'b0001 → 4'b0010 → 4'b0100 → 4'b1000 → 4'b0001`。

Verilog 的逻辑左移运算符 `<< 1` 会在最低位补 0 并丢弃最高位（`4'b1000 << 1` 得到 `4'b0000`，所有灯熄灭之后便无法恢复）。循环左移须使用位拼接运算符 `{...}` 将最高位 `led[3]` 移回最低位：

```verilog
led <= {led[2:0], led[3]};
```

可代入检验：`led = 4'b0001` 时，`led[2:0] = 3'b001`、`led[3] = 1'b0`，拼接结果为 `4'b0010`；`led = 4'b1000` 时，拼接结果为 `4'b0001`。

**2. 计数器分频与单周期移位使能。** 系统时钟 `clk` 为 100 MHz（周期 10 ns），人眼无法分辨每秒数千万次的变化，须通过分频使 `led` 每隔 `DIV` 个时钟周期才移动一次。

在 FPGA 设计中，**不应当**用计数器翻转产生一个低频信号 `slow_clk`，再将其写入 `always @(posedge slow_clk)`。由普通逻辑产生的时钟信号不经过芯片专用的全局时钟缓冲器（BUFG），布线延迟大且时钟偏斜（clock skew）不可控，会破坏工具的静态时序分析。工程上的标准做法是**全模块共用同一个系统时钟 `clk`**，增设一个计数器 `cnt` 从 `0` 循环计数至 `DIV - 1`：

- 计数器须能表示 `0` 至 `DIV - 1` 共 `DIV` 个数值，所需位宽为 `W = $clog2(DIV)`（例如 `DIV = 4` 时 `W = 2`，计数器为 `reg [1:0] cnt`，范围 `0..3`；`DIV = 25_000_000` 时 `W = 25`；`DIV = 100_000_000` 时 `W = 27`）。
- 当 `cnt == DIV - 1` 时，下一个上升沿使 `cnt` 归零，同时触发 `led` 移位（即产生单周期的移位条件）；其余上升沿 `cnt` 加 1，`led` 保持不变。

注意比较条件是 `cnt == DIV - 1` 而非 `cnt == DIV`：从 0 数到 `DIV - 1` 恰好经过 `DIV` 个时钟周期。若误写为 `cnt == DIV`，周期数将变成 `DIV + 1`。

**3. 异步输入、亚稳态（Metastability）与两级寄存器同步。** 触发器正常采样要求输入信号在时钟上升沿前后的建立时间（setup time）与保持时间（hold time）窗口内保持稳定。然而机械按键或 VIO 输出等外部信号与 `clk` 没有固定相位关系（称为异步信号），可能在时钟上升沿恰好发生跳变，违背建立或保持时间。此时第一级触发器的输出可能进入既非高电平也非低电平的中间状态（或产生振荡），称为**亚稳态（metastability）**。若直接将该不稳定的信号送往后续多个组合逻辑分支，不同路径可能把它判定为不同的逻辑值，导致状态错乱。

工程上的标准处理方法为**两级触发器同步器（two-flip-flop synchronizer）**：

```verilog
reg pause_sync1, pause_sync2;
always @(posedge clk) begin
    pause_sync1 <= pause;
    pause_sync2 <= pause_sync1;
end
```

第一级触发器 `pause_sync1` 即使发生亚稳态，也会在接下来的一个完整时钟周期内以极高概率恢复并稳定到 0 或 1；随后第二个时钟上升沿再由 `pause_sync2` 安全采样，提供给控制逻辑使用。代价是信号被延迟了两个时钟周期，且后续组合逻辑**必须使用 `pause_sync2`**，不得直接引用 `pause` 或 `pause_sync1`。

### PS 侧 GPIO 与 Vitis 裸机编程基础（第三步 `ps_led.c`）

**1. MIO 分组与引脚编号。** Zynq UltraScale+ MPSoC 的 PS 共有 78 个 MIO 引脚（MIO0–MIO77），按编号分为三个 Bank：

- Bank 0：MIO0–MIO25（Vivado 中对应 **GPIO 0 MIO**）；
- Bank 1：MIO26–MIO51（对应 **GPIO 1 MIO**）；
- Bank 2：MIO52–MIO77（对应 **GPIO 2 MIO**）。

FZ5D 的 RUN 指示灯 D46 接在 **MIO43**（球号 `K19`，网络名 `SYS_STATUS_LED`；注意 MIO42 为风扇控制 `FAN_CTRL`），属于 Bank 1，这正是第二步在 Vivado 中勾选 *GPIO 0 MIO* 与 *GPIO 1 MIO* 的原因。在 Xilinx 的 `xgpiops` 驱动中，MIO 引脚的软件引脚号直接等于 MIO 编号，因此 `ps_led.c` 定义 `#define RUN_LED_PIN 43`（只有引向 PL 侧的 EMIO 引脚才从 78 起算）。

**2. 为什么 GPIO 输出需要“设方向”和“使能输出”两步。** PS 的每个 GPIO 引脚内部同时包含输入缓冲器、输出数据锁存器与三态输出驱动门。芯片上电复位后，所有引脚默认处于高阻输入态，以防止在软件配置之前与外部电路发生电平冲突。因此将其配置为输出时，须依次完成两步：先将方向（Direction）设为输出（`1` 为输出，`0` 为输入），再开启输出使能（Output Enable，`1` 允许驱动外部引脚，`0` 保持高阻三态），此后写入的数据电平才会驱动三极管 Q2 与 RUN 灯。

**3. Vitis 裸机程序（Standalone）与 BSP 的结构。** 裸机程序不运行操作系统，硬件初始化完成后直接进入 C 语言的 `main()` 函数。Vitis 根据导入的 XSA 自动生成 **BSP（Board Support Package，板级支持包）**，其中与 `ps_led.c` 直接相关的头文件包括：

- `xparameters.h`：由 Vivado 导出的硬件配置自动生成，定义各外设的设备编号与基地址宏，例如 PS GPIO 控制器的设备号 `XPAR_XGPIOPS_0_DEVICE_ID`；
- `xgpiops.h`：PS GPIO 驱动库头文件，提供 `XGpioPs` 结构体（驱动程序实例）、`XGpioPs_Config` 配置结构体以及以下常用 API；
- `xil_printf.h` 与 `sleep.h`：`xil_printf` 是 Xilinx 提供的轻量级串口格式化输出函数（占用内存远小于标准 `printf`，不支持 `%f` 浮点格式）；`usleep(us)` 提供微秒级阻塞延时，本实验取 `HALF_PERIOD_US = 500000`（0.5 s），使状态每 0.5 s 翻转一次，形成 1 Hz 闪烁。
- 类型别名：`u32` 为 32 位无符号整数（对应标准 C 的 `uint32_t`），`s32` 为 32 位有符号整数（`int32_t`），均由 BSP 的 `xil_types.h` 定义。

**4. `xgpiops` 驱动的调用流程。** `ps_led.c` 按如下顺序调用五个库函数（详细原型亦可在 Vitis 的 `xgpiops.h` 与 `xgpiops_polled_example.c` 中查阅）：

| 步骤 | 函数原型 | 作用与返回值检查 |
|---|---|---|
| 1 | `XGpioPs_Config *XGpioPs_LookupConfig(u16 DeviceId)` | 根据 `XPAR_XGPIOPS_0_DEVICE_ID` 查找硬件配置表。若返回 `NULL`，说明 XSA 中未启用 GPIO 或设备号错误 |
| 2 | `s32 XGpioPs_CfgInitialize(XGpioPs *InstancePtr, XGpioPs_Config *ConfigPtr, u32 EffectiveAddr)` | 用配置指针 `cfg` 与基地址 `cfg->BaseAddr` 初始化驱动实例 `&gpio`。成功时返回 `XST_SUCCESS` |
| 3 | `void XGpioPs_SetDirectionPin(const XGpioPs *InstancePtr, u32 Pin, u32 Direction)` | 设置单个引脚方向：`Pin` 为 `RUN_LED_PIN`，`Direction` 取 `1` 表示输出 |
| 4 | `void XGpioPs_SetOutputEnablePin(const XGpioPs *InstancePtr, u32 Pin, u32 OpEnable)` | 使能单个引脚输出：`OpEnable` 取 `1` |
| 5 | `void XGpioPs_WritePin(const XGpioPs *InstancePtr, u32 Pin, u32 Data)` | 向引脚写入输出电平 `Data`（`0` 或 `1`） |

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
| PS 侧 DDR | DDR4，64 位，8 GB（另有 4 GB 版本） | 8 GB 参数已在 FZ5D 上实机验证；配置前仍须确认手中板卡的容量 |
| 调试串口 | J13（Micro-USB，CP2102N 桥接）→ PS UART0：MIO26 为 RX，MIO27 为 TX | 115200 波特，8 位数据，无校验，1 位停止，无流控 |
| RUN 指示灯 | D46（红绿双色灯：红色 `POWER` 常亮，绿色 `RUN` 经 NPN 三极管 Q2 由 PS 的 **MIO43** 驱动） | **唯一可由程序控制的用户 LED**（高电平有效，已实机验证）；闪烁时红绿叠加表现为纯红 ↔ 黄绿/橙色交替。注意：旧版笔记误作 MIO42，实际 MIO42 为风扇控制 `FAN_CTRL` |
| 状态灯 D3 | D3（`PS_DONE`，绿色） | 配置完成后常亮绿光，不受用户程序控制，勿与 D46 混淆 |
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

**14 针接口的下载器。** 许多下载器（例如 ALINX 开发板配套的）为标准 Xilinx 14 针接口，2.0 mm 间距，2×7 排列，不能直接插到 J1（2.54 mm，6 针）。须经 2.0 mm 14 针转 2.54 mm 的转接板，或使用下载器附带的单根引线，按下表连接。14 针接口的常见定义如下，**以下载器的说明与接口上的标注为准**：

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

| 端口 | 方向 | 位宽 | 类型 | 说明 |
|---|---|---|---|---|
| `clk` | 输入 | 1 | — | 时钟，上升沿有效 |
| `rst` | 输入 | 1 | — | 同步复位，高电平有效 |
| `pause` | 输入 | 1 | — | 暂停，高电平有效。该信号与 `clk` 异步（实际使用时来自按键或 VIO），须先经两级寄存器同步，再用于控制 |
| `led` | 输出 | 4 | 无符号，`reg` | 寄存器输出，任一时刻只有一位为 1（独热码） |

| 参数 | 默认值 | 说明 |
|---|---|---|
| `DIV` | 25 000 000 | 分频系数：每 `DIV` 个时钟周期出现一个**移位时刻**。时钟为 100 MHz 时，`led` 约每秒移位 4 次 |

**行为规定。**

1. **复位。** `rst` 为同步复位、高电平有效，具有最高优先级。在 `rst = 1` 的时钟上升沿，`led` 置为 `4'b0001`，分频计数器 `cnt` 清零。同步寄存器 `pause_sync1`、`pause_sync2` 是否随 `rst` 清零不作要求（若一并复位为 `1'b0`，可避免仿真初期出现不确定态 `x`）。
2. **计数与移位时刻。** 复位撤销后，计数器 `cnt` 从 0 开始循环计数，周期为 `DIV` 个时钟周期：每个上升沿处，若 `cnt == DIV - 1`，则下一个上升沿后 `cnt` 回到 0；否则 `cnt` 加 1。复位撤销后的第 `DIV`、`2·DIV`、`3·DIV`、… 个上升沿（即采样到 `cnt == DIV - 1` 的上升沿）为移位时刻。
3. **移位。** 在移位时刻，若同步后的信号 `pause_sync2` 为 0，则 `led` 循环左移一位（`0001 → 0010 → 0100 → 1000 → 0001`）；若 `pause_sync2` 为 1，则 `led` 保持不变。其余时钟上升沿 `led` 保持不变。
4. **暂停不影响计数。** `pause` 有效期间，计数器照常循环计数，`pause_sync2` 只决定移位时刻是否移位。因此 `pause` 撤销后，下一次移位出现在下一个移位时刻，而不是撤销之后再等待 `DIV` 个周期。
5. **同步延迟。** 两级同步器使 `pause` 的变化滞后两个时钟周期：输入改变后的第 1 个上升沿更新 `pause_sync1`，第 2 个上升沿更新 `pause_sync2`，第 3 个上升沿控制逻辑方能采样到更新后的 `pause_sync2`。因此 `pause` 的变化须至少领先目标移位时刻 3 个上升沿，才能对该次移位生效。

**示例时序（`DIV = 4`，`pause` 始终为 0）。** 表中的“上升沿序号”将 `rst = 0` 之后的第一个上升沿记为 1；`cnt` 与 `led` 均列出该上升沿**之后**（即更新后）的取值：

| 上升沿序号 | 复位时（0） | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| 上升沿前是否满足 `cnt == DIV−1` | — | 否（`cnt=0`） | 否（`cnt=1`） | 否（`cnt=2`） | **是（`cnt=3`）** | 否（`cnt=0`） | 否（`cnt=1`） | 否（`cnt=2`） | **是（`cnt=3`）** | 否（`cnt=0`） |
| 上升沿后的 `cnt` | `0` | `1` | `2` | `3` | `0` | `1` | `2` | `3` | `0` | `1` |
| 上升沿后的 `led` | `0001` | `0001` | `0001` | `0001` | **`0010`** | `0010` | `0010` | `0010` | **`0100`** | `0100` |

### 代码框架

`led_flow.v` 中已给出模块与端口声明，推荐按如下结构完成（时序逻辑均写在 `always @(posedge clk)` 块中，一律使用非阻塞赋值 `<=`）：

```verilog
    localparam CNT_W = $clog2(DIV);

    reg [CNT_W-1:0] cnt;
    reg             pause_sync1;
    reg             pause_sync2;

    // 1. 两级寄存器同步异步输入 pause
    always @(posedge clk) begin
        // TODO：将 pause 依次打入 pause_sync1、pause_sync2
    end

    // 2. 计数器分频与流水灯移位
    always @(posedge clk) begin
        if (rst) begin
            // TODO：复位 cnt 与 led
        end else if (cnt == DIV - 1) begin
            // TODO：计数器归零；若 !pause_sync2，led 循环左移 {led[2:0], led[3]}
        end else begin
            // TODO：计数器加 1
        end
    end
```

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
   | GPIO 0 MIO、GPIO 1 MIO | 勾选（MIO43 属于 GPIO 1 组，即 MIO26–51） |

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

串口终端应当输出（先由 FSBL 打印引导信息，随后运行应用程序）：

```
Zynq MP First Stage Boot Loader
Release 2023.1   ...
PMU-FW is not running, certain applications may not be supported.
Hello World
Successfully ran Hello World application
```

其中 `PMU-FW is not running` 为 Vitis 裸机单应用调试（默认仅运行 FSBL、不额外加载电源管理固件 PMUFW）的正常提示，不影响本实验及后续裸机阶段的串口、GPIO 与 PL 调试。至此 PS、8 GB DDR4、串口与 JTAG 均已验证。

## 第三步：用 PS 的 GPIO 驱动 RUN 灯

目标：让 RUN 灯（D46，PS 的 **MIO43**）以 1 Hz 闪烁，并每 0.5 s 通过串口输出一行计数。

1. 以 `ps_led.c` 作为框架：将 `hello_world` 工程中 `helloworld.c` 的内容替换为 `ps_led.c` 的内容。
2. 先阅读「背景知识」中「PS 侧 GPIO 与 Vitis 裸机编程基础」一节，再对照 BSP 中的 `xgpiops_polled_example` 理解调用顺序，完成 `ps_led.c` 中三处 `TODO`：
   - **`TODO 1`（查找配置并初始化）**：调用 `XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID)` 获取 `cfg`，检查是否为 `NULL`；随后调用 `XGpioPs_CfgInitialize(&gpio, cfg, cfg->BaseAddr)`，检查返回值是否为 `XST_SUCCESS`。初始化失败时可 `return XST_FAILURE;`。
   - **`TODO 2`（配置方向与输出使能）**：依次调用 `XGpioPs_SetDirectionPin(&gpio, RUN_LED_PIN, 1)` 与 `XGpioPs_SetOutputEnablePin(&gpio, RUN_LED_PIN, 1)`，将 MIO43 设为输出并使能驱动。
   - **`TODO 3`（循环翻转与串口打印）**：在 `while (1)` 中调用 `XGpioPs_WritePin(&gpio, RUN_LED_PIN, level)` 输出电平，用 `xil_printf` 打印当前计数 `n` 与 `level`（注意换行符写 `\r\n`），调用 `usleep(HALF_PERIOD_US)` 延时 0.5 s，随后将 `level` 取反（`level = !level;` 或 `level ^= 1;`）并使 `n` 加 1。

   若不熟悉 Xilinx BSP 驱动的 C 样板写法，可按如下参考实现补全 `main()` 主体（该部分属于外设初始化样板代码）：

   ```c
   cfg = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);
   if (cfg == NULL) {
       xil_printf("ERROR: XGpioPs_LookupConfig failed\r\n");
       return XST_FAILURE;
   }
   status = XGpioPs_CfgInitialize(&gpio, cfg, cfg->BaseAddr);
   if (status != XST_SUCCESS) {
       xil_printf("ERROR: XGpioPs_CfgInitialize failed\r\n");
       return XST_FAILURE;
   }

   XGpioPs_SetDirectionPin(&gpio, RUN_LED_PIN, 1);
   XGpioPs_SetOutputEnablePin(&gpio, RUN_LED_PIN, 1);

   while (1) {
       XGpioPs_WritePin(&gpio, RUN_LED_PIN, level);
       xil_printf("n = %u, level = %u\r\n", n, level);
       usleep(HALF_PERIOD_US);
       level = !level;
       n++;
   }
   ```

3. 保存文件并执行 **Build Project**，再运行程序，观察串口输出与板上的双色灯 D46。

**说明。**

- PS 的 GPIO 引脚号与 MIO 号一致：MIO43 对应引脚号 `43`。
- 实测与原理图（D46、Q2、`SYS_STATUS_LED`）均已确认：Q2 为 NPN 三极管（高电平有效）；D46 为红绿双色灯，红色 `POWER` 常亮，因此绿灯随 `level` 闪烁时表现为**纯红 ↔ 黄绿/橙色**交替，不要误看旁边单独常亮的 `D3`（`PS_DONE`）绿灯。

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

## 选做：对照实验（AXU4EVB-E）

本部分需要 AXU4EVB-E 开发板。没有该板可以跳过，不影响本实验及后续阶段的完成。

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
- 能够说明：
  - PS 与 PL 各自的作用，为何 FZ5D 的流水灯不需要 `.xdc`；
  - XSA 中包含哪些内容，PS 配置为什么是板级的；
  - 从 RTL 到比特流的五个步骤（综合、实现、生成比特流等）各自的作用。

以下为选做（需 AXU4EVB-E）：

- AXU4EVB-E 上板载 LED 流水，按键可使其暂停；
- 差异表填写完整。

## 常见问题

- **Vivado 中点击 *Tools → Launch Vitis* 报错 `Vitis IDE launch failed`。** 安装时若仅勾选 *Vivado* 而未选 *Vitis*，安装目录下只有 `Vivado` 与 `Vitis_HLS`，缺少 Vitis IDE，见 [`setup/vivado.md`](../../setup/vivado.md) 通过 *Add Design Tools or Devices* 补装 *Vitis Unified Software Platform*；若已安装仍报错，可从开始菜单或终端单独启动 Vitis 后再导入 XSA。
- **串口终端没有任何输出。** 依次检查：J13 是否接入（而不是 J1）；终端的端口号与波特率（115200）；`UART 0` 是否勾选在 MIO26..27；SW1 是否为 JTAG 模式。
- **Vitis 运行时报 DDR 初始化或训练失败。** DDR 参数与板卡容量不符。对照 8 GB 与 4 GB 版本重新核对 *DDR Configuration*。
- **Hardware Manager 无法识别开发板。** JTAG 驱动未安装，或 USB 设备未直通至虚拟机，见 [`setup/vivado.md`](../../setup/vivado.md) 的「常见问题」；也检查 JTAG 排线与 J1 的引脚是否一一对应，VREF 是否接 3.3 V。
- **Hardware Manager 中看不到 `hw_vio_1`。** 依次检查：是否已用 Vitis 运行程序（PS 未初始化时 PL 没有时钟）；*Run Configurations* 中是否勾选 *Program FPGA*；*Probes file* 是否指向最新生成的 `.ltx`；导出 XSA 时是否选择了 *Include bitstream*。
- **RUN 灯一直常亮或不闪烁。** 依次排查：1）确认没有把常亮的独立绿灯 `D3`（`PS_DONE`）当成 `D46`（红绿双色灯，闪烁时为纯红 ↔ 黄绿/橙色）；2）确认串口已在打印 `n = ..., level = ...`（否则可能是未保存 `helloworld.c` 或未重新 Build）；3）确认 `RUN_LED_PIN` 为 **`43`**（MIO43）而非 `42`（MIO42 为风扇控制 `FAN_CTRL`，写 42 会使 MIO43 保持内部上拉而常亮）；4）确认 Vivado 中已勾选 `GPIO 1 MIO` 并重新导出 XSA / 更新 Platform。
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
| MYIR，原理图 `MYS-ZU5EV-32E4D-EDGE` V13 与 `FZ5_BALL.csv`（课程内部提供） | RUN 灯电路（D46、Q2、MIO43/K19）；UART0 的连接 |
| MYIR，*MYS-ZU5EV Linux 系统开发指南*（课程内部提供） | 第 6.1–6.2 节设备树 `led_sys` 与 `PS_MIO43` GPIO 编号示例 |
| AMD，*Zynq UltraScale+ Device Technical Reference Manual*（UG1085） | PS 的结构、MIO 与 EMIO、GPIO 控制器、启动模式 |
| AMD，*Zynq UltraScale+ MPSoC Processing System LogiCORE IP Product Guide*（PG201） | PS IP 各配置页的含义 |
| AMD，*Virtual Input/Output LogiCORE IP Product Guide*（PG159） | VIO 核的探针与刷新 |

以上 AMD 文档可在 docs.amd.com 以文档编号检索。
