# S1-04 4×4 脉动阵列矩阵乘法：以 cocotb（Python）验证

## 实验目的

脉动阵列（systolic array）是 TPU 及大多数 AI 加速器的计算核心。S4 的加速器设计以及 S6 以后自行实现的加速器，均以脉动阵列为基础。本实验将 S1-03 的 MAC 扩展为 4×4 阵列，初步建立以下硬件设计思维：数据在阵列中流动，每个单元在每个时钟周期仅与相邻单元交换数据。

本实验的 testbench 改用 **cocotb** 编写：以 Python 编写测试，参考答案直接由 NumPy 的 `A @ B` 计算。自本实验起，验证工作主要以 Python 完成。

## 文件说明

| 文件 | 编写者 | 作用 |
|---|---|---|
| `pe.v` | **实验者** | 处理单元：MAC 加两个传递寄存器 |
| `systolic4x4.v` | **实验者** | 以 generate 语句实例化 16 个 PE 并完成连线 |
| `test_systolic.py` | 已给出 | 三个 cocotb 测试：单位矩阵、20 组随机矩阵、连续两次矩阵乘法 |
| `Makefile` | 已给出 | cocotb 的标准构建脚本 |

## 原理：输出驻留脉动阵列

```
           b 列0  b 列1  b 列2  b 列3
             ↓      ↓      ↓      ↓
a 行0 →  PE00 → PE01 → PE02 → PE03
             ↓      ↓      ↓      ↓
a 行1 →  PE10 → PE11 → PE12 → PE13
             ↓      ↓      ↓      ↓
   ...
```

- PE(i,j) 负责计算 `C[i][j]`，计算结果始终保存在该单元自身的 `acc` 中，故称为输出驻留（output stationary）。
- 矩阵 A 的第 i 行从左侧逐个元素进入阵列第 i 行，每经过一个 PE 延迟一个周期；矩阵 B 的第 j 列从上方进入阵列第 j 列，同样每经过一个 PE 延迟一个周期。
- testbench 对输入进行错位（skew）：第 i 行推迟 i 个周期开始输入，第 j 列推迟 j 个周期开始输入。由此，`A[i][k]` 与 `B[k][j]` 恰好在第 `k+i+j` 个周期同时到达 PE(i,j)。
- 一次 4×4 矩阵乘法需要 3×4−2 = 10 个周期完成全部数据的输入，此后还需等待数据传播至右下角的 PE。

**PE 的规格**（每个时钟上升沿）：

- `rst` 为 1 时：`acc`、`a_out`、`b_out` 全部清零。
- 否则：`a_out <= a_in`，`b_out <= b_in`；同时，若 `clear` 为 1，则 `acc <= 0`，否则 `acc <= acc + a_in*b_in`。

## 实验步骤

1. 安装 cocotb（建议安装在虚拟环境中）：
   ```bash
   python3 -m venv ~/venvs/hdl && source ~/venvs/hdl/bin/activate
   pip install cocotb numpy
   ```
   此外须安装 `make`（`sudo apt install build-essential`）以及 S1-01 中安装的 Icarus Verilog。
2. 手工推演一次数据流：取 A 为单位矩阵，按错位方式推演 3 个周期，确定 PE(0,0)、PE(0,1)、PE(1,1) 分别在哪个周期接收到哪些数据。此步骤是理解后续波形的基础，不应跳过。
3. 实现 `pe.v`：在 S1-03 的 MAC 基础上去掉 `in_valid`，增加两个传递寄存器。
4. 实现 `systolic4x4.v`：以二维 wire 数组表示 PE 之间的连线，以两层 `genvar` 循环实例化 16 个 PE。文件注释中给出了连线写法的提示。
5. 运行 `make`，三个测试依次执行：
   - `test_identity`：A = I，C 应等于 B。此测试最易暴露连线错误，应首先使其通过。
   - `test_random`：20 组随机矩阵，其中第一组元素全部为 −128，用于检查符号与位宽。
   - `test_clear_between_runs`：连续计算两次，检查 `clear` 的功能。
   输出 `TESTS=3 PASS=3 FAIL=0` 即为通过。
6. 未通过时运行 `make WAVES=1`，用 GTKWave 打开 `sim_build/` 下的波形文件，检查 `a_h`、`b_v` 是否每个周期分别向右、向下移动一格。
7. 阅读 `test_systolic.py` 中的 `matmul` 函数，理解错位输入的生成方式。路线页面 S1 的“自己做”一栏要求能够复述这一过程。

## 完成标准

- `make` 显示 3 个测试全部通过。
- 能够画出 4×4 阵列的数据流图，并说明每个周期各 PE 正在计算哪一项。
- 能够回答：N×N 阵列完成一次 N×N 矩阵乘法需要多少个周期？其间有多少个 MAC 处于空闲状态？此即 S4 将讨论的利用率问题。

## 与后续内容的关系

- S2：将本阵列分别综合到 FZ5D 的 XCZU5EV 与 AXU4EVB-E 的 XCZU4EV 上，观察 16 个乘法器如何映射到 DSP 单元；再逐步扩展至 8×8、16×16，观察资源占用与最高频率的变化。
- S4：输出驻留只是数据流（dataflow）的一种，此外还有权重驻留、行驻留等方式，各有其适用场合与代价。
