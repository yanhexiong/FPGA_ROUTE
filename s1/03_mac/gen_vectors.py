"""生成 MAC 的测试向量和参考答案（golden），写到 vectors.hex，供 tb_mac.v 读取。

每一行是一拍的输入和这一拍之后 acc 应有的值，打包成 13 位十六进制：
    bit 49     clear
    bit 48     in_valid
    bit 47:40  a（8 位补码）
    bit 39:32  b（8 位补码）
    bit 31:0   期望的 acc（32 位补码）

这就是“Python 当参考模型”的做法：软件里算出正确答案，硬件仿真逐拍比对。
后面 S6 逐层比对 ResNet 的输出，用的是同一套思路，只是规模更大。
"""
import random

N = 2000          # 必须和 tb_mac.v 里的 N 一致
SEED = 2026


def wrap32(x: int) -> int:
    """模拟 32 位有符号寄存器的回绕：超出范围就像硬件一样溢出。"""
    return (x + 2**31) % 2**32 - 2**31


def rand_int8(rng: random.Random) -> int:
    # 两成的概率取边界值，专门检查符号位处理
    if rng.random() < 0.2:
        return rng.choice([-128, -127, -1, 0, 1, 127])
    return rng.randint(-128, 127)


def main() -> None:
    rng = random.Random(SEED)
    acc = 0
    lines = []
    for i in range(N):
        if i < 50:                      # 开头 50 拍：连续累加，不清零，不停顿
            valid, clear = 1, int(i == 0)
        else:
            valid = int(rng.random() < 0.8)
            clear = int(rng.random() < 0.05)
        a, b = rand_int8(rng), rand_int8(rng)

        # 参考模型：和 README 里的规格逐条对应
        if valid and clear:
            acc = a * b
        elif valid:
            acc = acc + a * b
        elif clear:
            acc = 0
        acc = wrap32(acc)

        word = (clear << 49) | (valid << 48) | ((a & 0xFF) << 40) | ((b & 0xFF) << 32) | (acc & 0xFFFFFFFF)
        lines.append(f"{word:013x}")

    with open("vectors.hex", "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"已生成 vectors.hex：{N} 拍，最后的 acc = {acc}")


if __name__ == "__main__":
    main()
