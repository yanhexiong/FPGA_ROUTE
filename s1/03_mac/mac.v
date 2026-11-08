`timescale 1ns/1ps
// INT8 乘加单元（MAC）：acc 累加 a*b，32 位有符号。接口已经定好，实现由你来写。
// 规格详见同目录的 README.md。
module mac (
    input  wire               clk,
    input  wire               rst,       // 同步复位，高电平有效：acc 清零
    input  wire               in_valid,  // 这一拍的 a、b 有效
    input  wire               clear,     // 开始新的一轮累加
    input  wire signed [7:0]  a,
    input  wire signed [7:0]  b,
    output reg  signed [31:0] acc
);

    // TODO：在这里写你的实现。
    // 优先级：rst > (in_valid && clear) > in_valid > clear > 保持

endmodule
