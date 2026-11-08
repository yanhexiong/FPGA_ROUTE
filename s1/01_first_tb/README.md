# S1-01 第一个 testbench：装好仿真工具，跑通一次「写电路 → 仿真 → 看波形」

## 这一步在干什么

硬件出了错很难在板子上查原因，所以每个电路都要先在电脑上仿真，确认没问题再上板。仿真需要三样东西：

| 东西 | 作用 | 软件里的类比 |
|---|---|---|
| 被测电路（DUT），这里是 `counter.v` | 你要验证的设计 | 被测函数 |
| testbench，这里是 `tb_counter.v` | 产生时钟、给输入、和参考答案比对、导出波形 | pytest 测试文件 |
| 仿真器 Icarus Verilog + 波形查看器 GTKWave | 运行 testbench；把每个信号随时间的变化画出来 | Python 解释器 + 调试器 |

testbench 本身也是 Verilog，但它没有输入输出端口，只在仿真器里运行，不会变成电路。所以里面可以用 `#5` 延时、`$display` 打印这些只有仿真才支持的语法。

## 步骤

1. 安装工具（Ubuntu），装完后运行 `iverilog -V`，能看到版本号即可：
   ```bash
   sudo apt install iverilog gtkwave
   ```
2. 进入本目录，运行仿真：
   ```bash
   make            # 等价于下面两条
   # iverilog -g2012 -Wall -o sim counter.v tb_counter.v   编译
   # vvp sim                                                运行
   ```
   终端应该打印 `PASS：计数、回绕、保持都正确`。
3. 打开波形：`make wave`（或 `gtkwave wave.vcd`）。
   - 左上 SST 面板里展开 `tb_counter`，点 `dut`。
   - 左下会列出 `clk`、`rst`、`en`、`q[3:0]`，全选后点 **Append**。
   - 点放大镜图标「Zoom Fit」看全部波形。
   - 右键 `q` → Data Format → Decimal，用十进制显示。
4. 对照波形读懂 testbench：找到复位结束的那一拍、q 从 15 回到 0 的那一拍、en 变成 0 后 q 保持不动的那一段。
5. 故意改错：把 `counter.v` 里的 `q + 4'd1` 改成 `q + 4'd2`，再运行 `make`。testbench 会打印一串 FAIL 和出错时间，到波形里找到那个时刻。改回来。

## 做完的标志

- `make` 打印 PASS，GTKWave 里能看到计数波形。
- 能说清 testbench 里六段代码各自做什么：实例化、时钟、导出波形、复位、逐拍比对、检查保持。
- 自己动手加一项检查：计数到一半时把 `rst` 拉高一拍，检查 q 回到 0，并让参考答案 `golden` 跟着清零。这一步自己写，不要交给 AI。

## 常见问题

- `iverilog: command not found`：没装好，或者装在了另一台机器上。
- 波形里信号是红色的 `x`：寄存器还没被复位赋值，属于正常现象。复位之后还是 `x`，说明复位逻辑写错了。
- 为什么检查前要等 `#1`？上升沿那一刻寄存器正在更新，稍等一下再读，才能读到更新后的稳定值。后面所有 testbench 都按「上升沿后等一会儿再采样」的规矩来。
