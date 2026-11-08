`timescale 1ns/1ps
// 脉动阵列的处理单元（PE）：一个 MAC，再加两个寄存器把数据传给邻居。
// 接口已经定好，实现由你来写。规格详见 README.md。
module pe (
    input  wire               clk,
    input  wire               rst,      // 同步复位：acc 和两个传递寄存器清零
    input  wire               clear,    // 同步清零 acc（开始新的一次矩阵乘）
    input  wire signed [7:0]  a_in,     // 从左边来的 A 元素
    input  wire signed [7:0]  b_in,     // 从上边来的 B 元素
    output reg  signed [7:0]  a_out,    // 打一拍后传给右边的 PE
    output reg  signed [7:0]  b_out,    // 打一拍后传给下边的 PE
    output reg  signed [31:0] acc       // 输出驻留：结果一直留在这个 PE 里
);

    // TODO：每个上升沿 acc += a_in * b_in；a_out <= a_in；b_out <= b_in。
    // 想一想 clear 那一拍 acc 应该变成 0 还是 a_in*b_in，然后和 README 的规格对照。

endmodule
