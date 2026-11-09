`timescale 1ns/1ps
// 变异体 M1：复位优先级低于使能
// 错误写法：先判断 en，再判断 rst。en=1 时拉高 rst 不起作用，q 照样加 1。
// 原 testbench 为什么发现不了：开头复位那一拍 en=0，复位照常生效。
// 规格要求：rst 优先，无论 en 是什么，rst=1 的下一拍 q 都是 0。
// 本文件是 make check 用的错误样本，本来就该是错的，不要修改。这道题只改 tb_counter.v。
module counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    output reg  [3:0] q
);
    always @(posedge clk) begin
        if (en)       q <= q + 4'd1;
        else if (rst) q <= 4'd0;
    end
endmodule
