`timescale 1ns/1ps
// 变异体 M2：复位只生效一次
// 错误写法：只有第一次复位有效，之后再拉高 rst 都被忽略。
// 原 testbench 为什么发现不了：它只在开头复位一次。
// 规格要求：任何时候拉高 rst，下一拍 q 都是 0。
// 本文件是 make check 用的错误样本，本来就该是错的，不要修改。这道题只改 tb_counter.v。
module counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    output reg  [3:0] q
);
    reg used = 1'b0;   // 记录是否已经复位过（仅用于仿真）
    always @(posedge clk) begin
        if (rst && !used) begin
            q    <= 4'd0;
            used <= 1'b1;
        end
        else if (en) q <= q + 4'd1;
    end
endmodule
