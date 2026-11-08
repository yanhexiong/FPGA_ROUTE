"""systolic4x4 的 cocotb 验收测试：用 Python 写 testbench，NumPy 算参考答案。

运行：make（需要先 pip install cocotb numpy）
看波形：make WAVES=1，波形文件在 sim_build/ 目录下，用 GTKWave 打开。

testbench 做的事和前面 Verilog 版的一样：给输入 → 等时钟 → 读输出 → 和参考答案比对。
区别是这里每一步都是 Python：
    dut.信号名.value = 值      给输入
    await RisingEdge(dut.clk)  等一个时钟上升沿（await 的用法和 asyncio 一样）
    dut.信号名.value           读输出
"""
import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

N = 4


def pack(values, width):
    """把一组整数（可以是负数）按补码拼成一个长整数：第 k 个放在 [k*width +: width]。"""
    word = 0
    mask = (1 << width) - 1
    for k, v in enumerate(values):
        word |= (int(v) & mask) << (k * width)
    return word


def unpack_signed(word, width, count):
    """pack 的逆操作，按有符号数解出来。"""
    out = []
    for k in range(count):
        v = (word >> (k * width)) & ((1 << width) - 1)
        if v >> (width - 1):
            v -= 1 << width
        out.append(v)
    return out


def read_c(dut):
    v = dut.c_out.value
    if not v.is_resolvable:
        raise AssertionError("c_out 里有 x 或 z：还没有驱动输出，或者某个 PE 没复位。先把 pe.v 和 systolic4x4.v 写完。")
    word = v.to_unsigned() if hasattr(v, "to_unsigned") else int(v)
    return np.array(unpack_signed(word, 32, N * N), dtype=np.int64).reshape(N, N)


async def reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rst.value = 1
    dut.clear.value = 0
    dut.a_west.value = 0
    dut.b_north.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst.value = 0


async def matmul(dut, A, B):
    """把 A、B 按脉动阵列的节奏喂进去，返回阵列算出的 C。

    节奏（skew）：第 i 行的 A[i][k] 在第 k+i 拍进入，第 j 列的 B[k][j] 在第 k+j 拍进入。
    这样 A[i][k] 和 B[k][j] 会在第 k+i+j 拍同时到达 PE(i,j)。其余时间喂 0，0 乘任何数都不影响累加。
    输入都在时钟下降沿改变，电路在上升沿采样，不会有竞争。
    """
    dut.clear.value = 1                      # 先清零一拍
    await FallingEdge(dut.clk)
    dut.clear.value = 0

    total = 3 * N - 2                        # 最后一对数据在第 3N-3 拍进入
    for t in range(total + 2 * N):           # 多跑几拍，让数据流过整个阵列
        a_col = [A[i][t - i] if 0 <= t - i < N else 0 for i in range(N)]
        b_row = [B[t - j][j] if 0 <= t - j < N else 0 for j in range(N)]
        dut.a_west.value = pack(a_col, 8)
        dut.b_north.value = pack(b_row, 8)
        await FallingEdge(dut.clk)
    dut.a_west.value = 0
    dut.b_north.value = 0
    return read_c(dut)


def check(dut, A, B, C, name):
    golden = A.astype(np.int64) @ B.astype(np.int64)
    if not np.array_equal(C, golden):
        diff = np.argwhere(C != golden)
        i, j = diff[0]
        raise AssertionError(
            f"{name}：C[{i}][{j}] = {C[i][j]}，应为 {golden[i][j]}，共 {len(diff)} 个元素不对\n"
            f"A=\n{A}\nB=\n{B}\n阵列输出=\n{C}\n正确答案=\n{golden}"
        )
    dut._log.info(f"{name}：通过")


@cocotb.test()
async def test_identity(dut):
    """单位矩阵：A = I 时 C 应该等于 B。最容易定位连线错误，先过这个。"""
    await reset(dut)
    A = np.eye(N, dtype=np.int64)
    B = np.arange(1, N * N + 1, dtype=np.int64).reshape(N, N)
    C = await matmul(dut, A, B)
    check(dut, A, B, C, "单位矩阵")


@cocotb.test()
async def test_random(dut):
    """20 组随机 INT8 矩阵，包含 -128、127 这些边界值。"""
    await reset(dut)
    rng = np.random.default_rng(2026)
    for trial in range(20):
        A = rng.integers(-128, 128, size=(N, N))
        B = rng.integers(-128, 128, size=(N, N))
        if trial == 0:                       # 第一组全取最大绝对值，检查符号和位宽
            A[:] = -128
            B[:] = -128
        C = await matmul(dut, A, B)
        check(dut, A, B, C, f"随机第 {trial} 组")


@cocotb.test()
async def test_clear_between_runs(dut):
    """连续两次矩阵乘：第二次的结果不能带着第一次的残留，用来检查 clear。"""
    await reset(dut)
    rng = np.random.default_rng(7)
    A1, B1 = rng.integers(-128, 128, size=(N, N)), rng.integers(-128, 128, size=(N, N))
    A2, B2 = rng.integers(-128, 128, size=(N, N)), rng.integers(-128, 128, size=(N, N))
    await matmul(dut, A1, B1)
    C2 = await matmul(dut, A2, B2)
    check(dut, A2, B2, C2, "第二次矩阵乘")
