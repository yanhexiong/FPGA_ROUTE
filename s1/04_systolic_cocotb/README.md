# S1-04 4×4 脉动阵列做矩阵乘，用 cocotb（Python）验证

## 为什么做这个

脉动阵列（systolic array）是 TPU 和大多数 AI 加速器的计算核心，S4 设计加速器、S6 以后自己写的加速器都以它为基础。
这个实验把 S1-03 的 MAC 复制成 4×4 个，第一次体会“数据在阵列里流动，每个单元每拍只和邻居打交道”的硬件思维。

testbench 换成 **cocotb**：用 Python 写测试，参考答案直接用 NumPy 的 `A @ B` 算。从这里开始，验证工作基本都在 Python 里完成。

## 文件

| 文件 | 谁写 | 作用 |
|---|---|---|
| `pe.v` | **你** | 处理单元：MAC 加两个传递寄存器 |
| `systolic4x4.v` | **你** | 用 generate 例化 16 个 PE 并连线 |
| `test_systolic.py` | 已给出 | 三个 cocotb 测试：单位矩阵、20 组随机矩阵、连续两次矩阵乘 |
| `Makefile` | 已给出 | cocotb 标准写法 |

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

- 每个 PE(i,j) 负责算 `C[i][j]`，结果一直留在它自己的 `acc` 里，所以叫“输出驻留”。
- A 的第 i 行从左边逐个进入第 i 行，每过一个 PE 延迟一拍；B 的第 j 列从上边进入第 j 列，同样每过一个 PE 延迟一拍。
- testbench 会把输入错开喂（skew）：第 i 行晚 i 拍开始，第 j 列晚 j 拍开始。这样 `A[i][k]` 和 `B[k][j]` 正好在第 `k+i+j` 拍同时到达 PE(i,j)。
- 4×4 矩阵乘需要 3×4−2 = 10 拍把数据送完，再等数据流到右下角。

**PE 的规格**（每个上升沿）：
- `rst`：`acc`、`a_out`、`b_out` 全部清零。
- 否则：`a_out <= a_in`，`b_out <= b_in`。同时，`clear` 为 1 时 `acc <= 0`，否则 `acc <= acc + a_in*b_in`。

## 步骤

1. 装 cocotb（建议放在虚拟环境里）：
   ```bash
   python3 -m venv ~/venvs/hdl && source ~/venvs/hdl/bin/activate
   pip install cocotb numpy
   ```
   还要有 `make`（`sudo apt install build-essential`）和 S1-01 装好的 Icarus。
2. 在纸上手推一次：A 取单位矩阵，跟着 skew 走 3 拍，看 PE(0,0)、PE(0,1)、PE(1,1) 各自在哪一拍拿到哪个数。这一步决定你能不能看懂后面的波形，别跳过。
3. 写 `pe.v`：基本就是 S1-03 的 MAC，去掉 `in_valid`，加上两个传递寄存器。
4. 写 `systolic4x4.v`：用二维 wire 数组表示 PE 之间的连线，两层 `genvar` 循环例化 16 个 PE。注释里给了连线的写法提示。
5. 运行 `make`。三个测试按顺序跑：
   - `test_identity`：A = I，C 应该等于 B，最容易发现连线错误。先让它通过。
   - `test_random`：20 组随机矩阵，第一组全是 −128，用来检查符号和位宽。
   - `test_clear_between_runs`：连续算两次，检查 `clear`。
   最后看到 `TESTS=3 PASS=3 FAIL=0` 就算通过。
6. 没通过时运行 `make WAVES=1`，用 GTKWave 打开 `sim_build/` 下的波形，看 `a_h`、`b_v` 是不是每拍往右、往下移一格。
7. 读一遍 `test_systolic.py` 里的 `matmul` 函数，弄懂 skew 是怎么生成的。S1 的“自己做”一栏里，这一项要求能复述。

## 做完的标志

- `make` 显示 3 个测试全部 PASS。
- 能画出 4×4 阵列的数据流，说清第几拍哪个 PE 在算哪一项。
- 能回答：N×N 阵列算一次 N×N 矩阵乘需要多少拍？阵列里有多少个 MAC 是空闲的？这就是 S4 要讲的“利用率”问题。

## 和后面的关系

- S2：把这个阵列综合到 FZ5D 的 XCZU5EV 和 AXU4EVB-E 的 XCZU4EV 上，看 16 个乘法器怎么映射到 DSP，再逐步加大到 8×8、16×16，看资源和频率怎么变。
- S4：输出驻留只是数据流的一种，还有权重驻留、行驻留，各有各的取舍。
