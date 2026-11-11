`timescale 1ns/1ps
// 脉动阵列的处理单元（PE）：一个乘加单元（MAC），外加两个向相邻 PE 传递数据的寄存器。
// 端口已经给定，实现由实验者完成。规格见同目录 README.md 的「题目」一节。
module pe (
    input  wire               clk,
    input  wire               rst,      // 同步复位，高电平有效：acc、a_out、b_out 清零
    input  wire               clear,    // 同步清零，高电平有效：只清零 acc，a_out、b_out 照常传递
    input  wire signed [7:0]  a_in,     // 来自左侧的 A 元素
    input  wire signed [7:0]  b_in,     // 来自上方的 B 元素
    output reg  signed [7:0]  a_out,    // a_in 延迟一个周期，传给右侧的 PE
    output reg  signed [7:0]  b_out,    // b_in 延迟一个周期，传给下方的 PE
    output reg  signed [31:0] acc       // 累加结果，始终保存在本 PE 中（输出驻留）
);

    // TODO：在每个时钟上升沿，按 README「功能」一节的优先级（rst > clear > 累加）更新 acc，
    //       同时更新 a_out、b_out（rst 时清零，否则分别取 a_in、b_in）。
    //       clear 有效的那个上升沿，acc 须变为 0，而不是 a_in * b_in。

endmodule
