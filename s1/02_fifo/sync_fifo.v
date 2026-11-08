`timescale 1ns/1ps
// 同步 FIFO，读写两端都用 valid/ready 握手。接口已经定好，实现由你来写。
// 规格详见同目录的 README.md。
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16              // 必须是 2 的幂
) (
    input  wire             clk,
    input  wire             rst,      // 同步复位，高电平有效；复位后 FIFO 为空

    // 写入端：上游 → FIFO。s_valid && s_ready 的那个上升沿，s_data 被写入
    input  wire             s_valid,
    output wire             s_ready,  // 没满时为 1
    input  wire [WIDTH-1:0] s_data,

    // 读出端：FIFO → 下游。m_valid && m_ready 的那个上升沿，队头被取走
    output wire             m_valid,  // 非空时为 1
    input  wire             m_ready,
    output wire [WIDTH-1:0] m_data    // 非空时始终等于队头数据
);

    // TODO：在这里写你的实现。
    // 提示：一块存储阵列 + 写指针 + 读指针 + 一个计数器（或多一位的指针）。

endmodule
