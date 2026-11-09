`timescale 1ns/1ps
// 同步 FIFO，读写两端均采用 valid/ready 握手。接口已经给定，由实验者完成实现。
// 规格见同目录的 README.md。
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16              // 须为 2 的幂
) (
    input  wire             clk,
    input  wire             rst,      // 同步复位，高电平有效；复位后 FIFO 为空

    // 写入端（上游 → FIFO）：上升沿处 s_valid && s_ready 成立时，s_data 写入队尾
    input  wire             s_valid,
    output wire             s_ready,  // FIFO 未满时为 1
    input  wire [WIDTH-1:0] s_data,

    // 读出端（FIFO → 下游）：上升沿处 m_valid && m_ready 成立时，队头数据被读出
    output wire             m_valid,  // FIFO 非空时为 1
    input  wire             m_ready,
    output wire [WIDTH-1:0] m_data    // FIFO 非空时始终等于队头数据（首字直通）
);

    // TODO：在此处完成实现。
    // 提示：存储阵列、写指针、读指针，以及计数器或扩展一位的指针（见 README「空满状态的判定」）。

endmodule
