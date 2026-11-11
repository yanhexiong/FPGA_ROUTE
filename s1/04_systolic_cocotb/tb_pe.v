// pe 的单独验收 testbench：逐行重放 README「示例时序」中单个 pe 的 7 个周期。
// 运行：make pe
// 每个周期：在时钟下降沿施加输入，上升沿之后核对 acc、a_out、b_out。
// 先通过本测试，再去写 systolic4x4.v：这样阵列测试失败时，可以排除 pe 本身的问题。
`timescale 1ns/1ps
module tb_pe;
    reg                clk = 0;
    reg                rst = 0;
    reg                clear = 0;
    reg  signed [7:0]  a_in = 0;
    reg  signed [7:0]  b_in = 0;
    wire signed [7:0]  a_out;
    wire signed [7:0]  b_out;
    wire signed [31:0] acc;

    pe dut (.clk(clk), .rst(rst), .clear(clear), .a_in(a_in), .b_in(b_in),
            .a_out(a_out), .b_out(b_out), .acc(acc));

    always #5 clk = ~clk;

    integer cycle  = 0;
    integer errors = 0;

    // 一次调用即表中的一行：前四个参数是该周期的输入，后三个是上升沿之后应有的输出。
    task step(
        input              r,
        input              c,
        input signed [7:0] a,
        input signed [7:0] b,
        input signed [31:0] exp_acc,
        input signed [7:0]  exp_a_out,
        input signed [7:0]  exp_b_out
    );
        if (errors == 0) begin               // 一旦出错就不再继续：后面的错误多半是它的连锁结果
            @(negedge clk);
            rst = r; clear = c; a_in = a; b_in = b;
            @(posedge clk);
            #1;
            if (acc !== exp_acc) begin
                $display("FAIL 周期 %0d：acc 应为 %0d，实际为 %0d", cycle, exp_acc, acc);
                errors = errors + 1;
            end
            if (a_out !== exp_a_out) begin
                $display("FAIL 周期 %0d：a_out 应为 %0d，实际为 %0d", cycle, exp_a_out, a_out);
                errors = errors + 1;
            end
            if (b_out !== exp_b_out) begin
                $display("FAIL 周期 %0d：b_out 应为 %0d，实际为 %0d", cycle, exp_b_out, b_out);
                errors = errors + 1;
            end
            if (errors == 0) cycle = cycle + 1;
        end
    endtask

    initial begin
        $dumpfile("wave_pe.vcd");
        $dumpvars(0, tb_pe);

        //   rst clear  a_in   b_in   acc    a_out  b_out
        step( 1,  0,      9,     9,      0,     0,     0);   // 周期 0：复位，忽略输入
        step( 0,  0,      2,     3,      6,     2,     3);   // 周期 1：累加 0 + 2×3
        step( 0,  0,     -1,     4,      2,    -1,     4);   // 周期 2：累加 6 + (−1)×4
        step( 0,  1,      5,     5,      0,     5,     5);   // 周期 3：clear 优先，acc 为 0；a_out、b_out 照常传递
        step( 0,  0,      1,     1,      1,     1,     1);   // 周期 4：累加 0 + 1×1
        step( 0,  0,   -128,  -128,  16385,  -128,  -128);   // 周期 5：累加 1 + 16384
        step( 1,  0,      7,     7,      0,     0,     0);   // 周期 6：复位优先

        if (errors == 0)
            $display("PASS：pe 的 %0d 个周期与示例时序一致", cycle);
        else begin
            $display("FAIL：周期 %0d 与示例时序不一致（只显示第一个出错的周期，请先修正它）", cycle);
            if (^acc === 1'bx)
                $display("acc 是 x 或 z，说明还没有驱动它，先把 pe.v 写完。");
        end
        $finish(0);                      // 参数 0：结束时不打印 $finish 的提示行
    end
endmodule
