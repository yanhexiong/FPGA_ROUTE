`timescale 1ns/1ps
// 流水灯。接口已经给定，由实验者完成实现。规格见同目录的 README.md。
module led_flow #(
    parameter DIV = 25_000_000    // 每 DIV 个时钟周期移动一位；时钟为 100 MHz 时，约每秒移动 4 位
) (
    input  wire       clk,
    input  wire       rst,        // 同步复位，高电平有效
    input  wire       pause,      // 暂停，高电平有效；与 clk 异步，须先经两级寄存器同步
    output reg  [3:0] led         // 独热码，复位后为 4'b0001
);

    // TODO：在此处完成实现。

endmodule
