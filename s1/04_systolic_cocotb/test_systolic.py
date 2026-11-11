"""systolic4x4 的 cocotb 验收测试：以 Python 编写 testbench，以 NumPy 计算参考答案。

运行：make（须先 pip install cocotb numpy，见 README「实验步骤」）
查看波形：make WAVES=1，波形文件位于 sim_build/ 目录，以 GTKWave 打开。

本测试所做的工作与 Verilog testbench 相同：施加输入 → 等待时钟 → 读取输出 → 与参考答案比对。
区别在于每一步都以 Python 表达：
    dut.信号名.value = 值      施加输入
    await RisingEdge(dut.clk)  等待一个时钟上升沿（await 的含义见 README「cocotb 简介」）
    dut.信号名.value           读取输出
"""
import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

N = 4


def pack(values, width):
    """将一组整数（可为负数）按补码拼接为一个长整数：第 k 个元素位于 [k*width +: width]。"""
    word = 0
    mask = (1 << width) - 1
    for k, v in enumerate(values):
        word |= (int(v) & mask) << (k * width)
    return word


def unpack_signed(word, width, count):
    """pack 的逆操作，各元素按有符号数（补码）解出。"""
    out = []
    for k in range(count):
        v = (word >> (k * width)) & ((1 << width) - 1)
        if v >> (width - 1):
            v -= 1 << width
        out.append(v)
    return out


def read_c(dut):
    """读取 c_out，解出 4×4 的结果矩阵 C。"""
    v = dut.c_out.value
    if not v.is_resolvable:
        raise AssertionError(
            "c_out 中含有 x 或 z：输出尚未被驱动，或某个 PE 未被复位。"
            "请先完成 pe.v 与 systolic4x4.v。"
        )
    word = v.to_unsigned() if hasattr(v, "to_unsigned") else int(v)
    return np.array(unpack_signed(word, 32, N * N), dtype=np.int64).reshape(N, N)


async def reset(dut):
    """启动时钟并复位：rst 保持两个上升沿，并在下降沿撤销。"""
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
    """按脉动阵列的节奏输入 A、B，返回阵列算出的 C。

    错位（skew）规则：第 i 行的 A[i][k] 在第 k+i 个周期进入阵列，
    第 j 列的 B[k][j] 在第 k+j 个周期进入阵列，二者因此在第 k+i+j 个周期同时到达 PE(i,j)。
    其余周期输入 0，0 乘任何数均为 0，不影响累加。
    输入在时钟下降沿改变，电路在上升沿采样，二者不会同时发生，不存在竞争。
    """
    dut.clear.value = 1                      # 先使 acc 清零一个周期
    await FallingEdge(dut.clk)
    dut.clear.value = 0

    total = 3 * N - 2                        # 最后一对数据在第 3N-3 个周期到达 PE(N-1, N-1)，共 3N-2 个周期
    for t in range(total + 2 * N):           # 多运行若干周期，保证数据流过整个阵列
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
            f"{name}：C[{i}][{j}] = {C[i][j]}，应为 {golden[i][j]}，共 {len(diff)} 个元素不一致\n"
            f"A=\n{A}\nB=\n{B}\n阵列输出=\n{C}\n正确答案=\n{golden}"
        )
    dut._log.info(f"{name}：通过")


@cocotb.test()
async def test_identity(dut):
    """单位矩阵：A = I 时，C 应等于 B。该测试最易暴露连线错误，应首先使其通过。"""
    await reset(dut)
    A = np.eye(N, dtype=np.int64)
    B = np.arange(1, N * N + 1, dtype=np.int64).reshape(N, N)
    C = await matmul(dut, A, B)
    check(dut, A, B, C, "单位矩阵")


@cocotb.test()
async def test_random(dut):
    """20 组随机 INT8 矩阵，其中第一组全部取 −128，检查符号与位宽。"""
    await reset(dut)
    rng = np.random.default_rng(2026)
    for trial in range(20):
        A = rng.integers(-128, 128, size=(N, N))
        B = rng.integers(-128, 128, size=(N, N))
        if trial == 0:                       # 第一组全取 −128：每个元素 = 4 × 16384 = 65536，超过 16 位
            A[:] = -128
            B[:] = -128
        C = await matmul(dut, A, B)
        check(dut, A, B, C, f"随机第 {trial} 组")


@cocotb.test()
async def test_clear_between_runs(dut):
    """连续两次矩阵乘：第二次的结果不得含有第一次的残留，用于检查 clear 的功能。"""
    await reset(dut)
    rng = np.random.default_rng(7)
    A1, B1 = rng.integers(-128, 128, size=(N, N)), rng.integers(-128, 128, size=(N, N))
    A2, B2 = rng.integers(-128, 128, size=(N, N)), rng.integers(-128, 128, size=(N, N))
    await matmul(dut, A1, B1)
    C2 = await matmul(dut, A2, B2)
    check(dut, A2, B2, C2, "第二次矩阵乘")


@cocotb.test()
async def test_clear_priority(dut):
    """clear 的优先级高于累加：clear 有效的那个上升沿，即使输入不为 0，acc 也必须变为 0。

    该测试在 clear 的那一拍使 PE(0,0) 的输入为 7 和 9。若 clear 被实现为“写入本拍的乘积”，
    PE(0,0) 的 acc 将变为 63 而不是 0。
    """
    await reset(dut)
    A = np.full((N, N), 3, dtype=np.int64)
    B = np.full((N, N), 5, dtype=np.int64)
    C = await matmul(dut, A, B)
    check(dut, A, B, C, "清零之前")             # 此时每个 acc 均为 4 × 15 = 60，不为 0

    dut.a_west.value = pack([7] * N, 8)
    dut.b_north.value = pack([9] * N, 8)
    dut.clear.value = 1
    await FallingEdge(dut.clk)               # 其间经过一个 clear = 1 的上升沿
    dut.clear.value = 0
    dut.a_west.value = 0
    dut.b_north.value = 0

    got = read_c(dut)
    assert np.array_equal(got, np.zeros((N, N), dtype=np.int64)), (
        f"clear 有效的那个上升沿之后，所有 acc 均应为 0，实际为\n{got}\n"
        "若 C[0][0] = 63，说明 clear 那一拍写入了本拍的乘积 7 × 9，而不是 0。"
    )
