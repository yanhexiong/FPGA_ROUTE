// testbench：没有端口的模块，只在仿真器里运行，不会变成电路。
// 它做四件事：产生时钟 → 给输入 → 和参考答案比对 → 导出波形。
`timescale 1ns/1ps
module tb_counter;
    reg        clk = 0;
    reg        rst = 1;
    reg        en  = 0;
    wire [3:0] q;
    reg  [3:0] golden;          // 参考答案，相当于 Python 里算出的期望值
    integer    i;
    integer    errors = 0;

    // 1. 实例化被测电路
    counter dut (.clk(clk), .rst(rst), .en(en), .q(q));

    // 2. 产生时钟：每 5 ns 翻转一次，周期 10 ns（100 MHz）
    always #5 clk = ~clk;

    initial begin
        // 3. 波形输出到 wave.vcd，用 GTKWave 打开
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_counter);

        // 4. 复位一拍，然后打开使能
        @(posedge clk); #1;
        rst = 0;
        en  = 1;
        golden = 0;

        // 5. 跑 20 个周期，每个周期检查一次
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk); #1;           // 等上升沿，稍后 1 ns 再看输出
            golden = golden + 1;          // 4 位寄存器自动回绕：15 + 1 = 0
            if (q !== golden) begin       // !== 连 x、z 也会比较，比 != 严格
                $display("FAIL t=%0d ns: q=%0d, 期望 %0d", $time, q, golden);
                errors = errors + 1;
            end
        end

        // 6. 停住使能，计数应保持不变
        en = 0;
        repeat (3) @(posedge clk);
        #1;
        if (q !== golden) begin
            $display("FAIL: en=0 时计数器不该变化，q=%0d, 期望 %0d", q, golden);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS：计数、回绕、保持都正确");
        else             $display("共 %0d 处错误", errors);
        $finish;
    end
endmodule
