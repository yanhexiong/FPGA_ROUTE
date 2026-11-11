// led_flow 的验收 testbench。不得修改。写好 led_flow.v 后运行 make，输出 PASS 即通过。
// 为缩短仿真时间，这里取 DIV = 8。检查分四段：复位、自由运行、暂停与恢复、运行中复位。
// 每一段都在指定的时钟周期上检查 led 的取值，因此移位的时刻必须与 README 的规格完全一致。
`timescale 1ns/1ps
module tb_led_flow;
    localparam DIV = 8;

    reg        clk   = 0;
    reg        rst   = 1;
    reg        pause = 0;
    wire [3:0] led;

    led_flow #(.DIV(DIV)) dut (.clk(clk), .rst(rst), .pause(pause), .led(led));

    always #5 clk = ~clk;

    integer errors = 0;
    integer s, i;
    reg [3:0]      exp, hold;
    integer        seg = 0;       // 当前检查段的编号，出错时一并打印

    function [3:0] rotl(input [3:0] v);
        rotl = {v[2:0], v[3]};
    endfunction

    // 等 n 个上升沿，再延后 1 ns（避开上升沿那一刻，读到更新后的稳定值）
    task tick(input integer n);
        begin repeat (n) @(posedge clk); #1; end
    endtask

    task check(input [3:0] want);
        begin
            if (led !== want) begin
                $display("FAIL t=%0d ns 第 %0d 段: led=%b，应为 %b", $time, seg, led, want);
                if (^led === 1'bx) $display("      led 是 x 或 z：寄存器没有被复位或赋值");
                errors = errors + 1;
                if (errors >= 10) begin
                    $display("错误已有 10 处，提前结束。先看第一处：对照 README 示例时序，数一数 led 应在第几个周期变化。");
                    $finish;
                end
            end
        end
    endtask

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_led_flow);

        // ---- 第 1 段：复位 ----
        seg = 1;
        tick(3);
        check(4'b0001);
        rst = 0;                              // 之后的第 1 个上升沿记为第 1 个周期

        // ---- 第 2 段：自由运行 12 步，每步恰好 DIV 个周期 ----
        seg = 2;
        exp = 4'b0001;
        for (s = 0; s < 12; s = s + 1) begin
            tick(DIV - 1); check(exp);        // 移位之前的最后一个周期：保持不变
            tick(1);       exp = rotl(exp); check(exp);   // 第 DIV 个周期：左移一位
        end

        // ---- 第 3 段：暂停 4*DIV 个周期，led 保持；松开后下一次计时到达时恢复移位 ----
        seg = 3;
        pause = 1;
        hold  = exp;
        for (i = 0; i < 4 * DIV; i = i + 1) begin
            tick(1); check(hold);
        end
        pause = 0;
        seg = 3;
        tick(DIV - 1); check(hold);
        tick(1);       exp = rotl(hold); check(exp);
        for (s = 0; s < 4; s = s + 1) begin
            tick(DIV - 1); check(exp);
            tick(1);       exp = rotl(exp); check(exp);
        end

        // ---- 第 4 段：两次移位之间复位一个周期，led 回到 0001，计时也从头开始 ----
        seg = 4;
        tick(3);
        rst = 1; tick(1); rst = 0;
        check(4'b0001);
        exp = 4'b0001;
        tick(DIV - 1); check(exp);
        tick(1);       exp = rotl(exp); check(exp);

        if (errors == 0) $display("PASS：复位、移位时刻、暂停与恢复、运行中复位都正确");
        else             $display("共 %0d 处错误", errors);
        $finish;
    end
endmodule
