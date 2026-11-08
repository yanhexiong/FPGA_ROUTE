`timescale 1ns/1ps
// 被测电路（DUT）：4 位计数器
// rst 为 1 时清零；en 为 1 时每个时钟上升沿加 1，数到 15 之后回到 0。
module counter (
    input  wire       clk,
    input  wire       rst,   // 同步复位，高电平有效
    input  wire       en,    // 计数使能
    output reg  [3:0] q
);
    always @(posedge clk) begin
        if (rst)     q <= 4'd0;
        else if (en) q <= q + 4'd1;
    end
endmodule
