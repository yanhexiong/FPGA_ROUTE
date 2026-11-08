`timescale 1ns/1ps
// 4×4 输出驻留（output-stationary）脉动阵列，计算 C = A × B（A、B 都是 4×4 的 INT8 矩阵）。
// 接口已经定好，实现由你来写：用 generate 例化 16 个 pe 并连线。规格详见 README.md。
module systolic4x4 (
    input  wire             clk,
    input  wire             rst,
    input  wire             clear,
    input  wire [4*8-1:0]   a_west,   // 第 i 行左侧的输入在 a_west[i*8 +: 8]
    input  wire [4*8-1:0]   b_north,  // 第 j 列上方的输入在 b_north[j*8 +: 8]
    output wire [16*32-1:0] c_out     // C[i][j] 在 c_out[(i*4+j)*32 +: 32]
);

    // TODO：
    // 1. 声明 PE 之间的连线：水平方向传 a，垂直方向传 b。
    //    小技巧：wire signed [7:0] a_h [0:3][0:4]; 第 i 行第 j 个 PE 的输入是 a_h[i][j]，输出是 a_h[i][j+1]。
    //    b 同理：wire signed [7:0] b_v [0:4][0:3];
    // 2. 把 a_west、b_north 接到最左一列、最上一行。
    // 3. 两层 genvar 循环例化 16 个 pe，把每个 PE 的 acc 接到 c_out 对应的位置。

endmodule
