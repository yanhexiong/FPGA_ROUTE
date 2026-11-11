`timescale 1ns/1ps
// 4×4 输出驻留（output-stationary）脉动阵列，计算 C = A × B（A、B 均为 4×4 的 INT8 矩阵）。
// 端口已经给定，实现由实验者完成：以 generate 例化 16 个 pe 并连线。规格见同目录 README.md 的「题目」一节。
module systolic4x4 (
    input  wire             clk,
    input  wire             rst,
    input  wire             clear,
    input  wire [4*8-1:0]   a_west,   // 第 i 行左侧的输入位于 a_west[i*8 +: 8]
    input  wire [4*8-1:0]   b_north,  // 第 j 列上方的输入位于 b_north[j*8 +: 8]
    output wire [16*32-1:0] c_out     // C[i][j] 位于 c_out[(i*4+j)*32 +: 32]
);

    // TODO：
    // 1. 声明 PE 之间的连线，水平方向传递 a，垂直方向传递 b：
    //        wire signed [7:0] a_h [0:3][0:4];   // 第 i 行第 j 个 PE 的 a 输入为 a_h[i][j]，a 输出为 a_h[i][j+1]
    //        wire signed [7:0] b_v [0:4][0:3];   // 第 i 行第 j 个 PE 的 b 输入为 b_v[i][j]，b 输出为 b_v[i+1][j]
    // 2. 将 a_west 接到最左一列（a_h[i][0]），将 b_north 接到最上一行（b_v[0][j]）。
    // 3. 以两层 genvar 循环例化 16 个 pe，并将每个 PE 的 acc 接到 c_out 的对应位置。
    //    generate 循环的变量须声明为 genvar，每个 begin 须带标签，例如 begin : g_row。

endmodule
