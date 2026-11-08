// mac 的验收 testbench。先运行 python3 gen_vectors.py 生成 vectors.hex（make 会自动做）。
// 每一拍从 vectors.hex 读一行：给 DUT 输入，上升沿之后把 acc 和 Python 算出的答案比对。
`timescale 1ns/1ps
module tb_mac;
    localparam N = 2000;               // 必须和 gen_vectors.py 里的 N 一致

    reg               clk = 0;
    reg               rst = 1;
    reg               in_valid = 0;
    reg               clear = 0;
    reg  signed [7:0] a = 0;
    reg  signed [7:0] b = 0;
    wire signed [31:0] acc;

    mac dut (.clk(clk), .rst(rst), .in_valid(in_valid), .clear(clear), .a(a), .b(b), .acc(acc));

    always #5 clk = ~clk;

    reg  [51:0]        vec [0:N-1];
    reg  signed [31:0] expected;
    integer i;
    integer errors = 0;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_mac);
        $readmemh("vectors.hex", vec);
        if (^vec[N-1] === 1'bx) begin
            $display("没读到完整的 vectors.hex，先运行 python3 gen_vectors.py");
            $finish;
        end

        // 复位两拍，检查 acc 被清零
        repeat (2) @(posedge clk);
        #1 rst = 0;
        if (acc !== 0) begin
            $display("FAIL 复位后 acc 应为 0，实际是 %0d", acc);
            if (^acc === 1'bx) $display("acc 是 x 或 z，说明还没有驱动它，先把 mac.v 写完。");
            $finish;
        end

        for (i = 0; i < N; i = i + 1) begin
            // 上升沿后 1 ns 给这一拍的输入
            clear    = vec[i][49];
            in_valid = vec[i][48];
            a        = vec[i][47:40];
            b        = vec[i][39:32];
            expected = vec[i][31:0];
            @(posedge clk);
            #1;
            if (acc !== expected) begin
                $display("FAIL 第 %0d 拍: valid=%b clear=%b a=%0d b=%0d → acc=%0d，应为 %0d",
                         i, in_valid, clear, a, b, acc, expected);
                errors = errors + 1;
                if (errors >= 10) begin
                    $display("错误已有 10 处，提前结束。先看第一处：多半是符号扩展或者优先级问题。");
                    $finish;
                end
            end
        end

        if (errors == 0) $display("PASS：%0d 拍全部和 Python 参考答案一致", N);
        else             $display("共 %0d 处错误", errors);
        $finish;
    end
endmodule
