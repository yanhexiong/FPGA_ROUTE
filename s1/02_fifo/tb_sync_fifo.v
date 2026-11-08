// sync_fifo 的验收 testbench。不用改它，写好 sync_fifo.v 后运行 make，打印 PASS 即通过。
// 检查分四段：复位 → 写满 → 读空 → 随机读写 3000 拍。
// 每一拍都和一个“参考模型”（软件队列）比对：数据顺序、s_ready、m_valid 都必须完全一致。
`timescale 1ns/1ps
module tb_sync_fifo;
    localparam WIDTH = 8;
    localparam DEPTH = 16;
    localparam MAXN  = 8192;          // 参考模型最多记录这么多个数据

    reg              clk = 0;
    reg              rst = 1;
    reg              s_valid = 0;
    reg  [WIDTH-1:0] s_data  = 0;
    reg              m_ready = 0;
    wire             s_ready, m_valid;
    wire [WIDTH-1:0] m_data;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst),
        .s_valid(s_valid), .s_ready(s_ready), .s_data(s_data),
        .m_valid(m_valid), .m_ready(m_ready), .m_data(m_data)
    );

    always #5 clk = ~clk;

    // ---------------- 参考模型：一个软件队列 ----------------
    reg [WIDTH-1:0] model [0:MAXN-1];
    integer wr_n = 0;                 // 累计写入个数
    integer rd_n = 0;                 // 累计读出个数
    integer errors = 0;
    reg     checking = 0;             // 复位结束后才开始逐拍检查

    // 在每个上升沿采样握手。testbench 的输入都在上升沿之后 1 ns 才改变，
    // 所以这里读到的是上升沿之前的稳定值，和电路看到的一样。
    always @(posedge clk) begin
        if (checking) begin
            // 1. 状态信号必须和模型一致
            if (s_ready !== (wr_n - rd_n < DEPTH)) begin
                $display("FAIL t=%0d ns: s_ready=%b，但 FIFO 里有 %0d 个数据（深度 %0d）",
                         $time, s_ready, wr_n - rd_n, DEPTH);
                errors = errors + 1;
            end
            if (m_valid !== (wr_n - rd_n > 0)) begin
                $display("FAIL t=%0d ns: m_valid=%b，但 FIFO 里有 %0d 个数据",
                         $time, m_valid, wr_n - rd_n);
                errors = errors + 1;
            end
            // 2. 读出握手：数据必须是最早写入、还没被读走的那个
            if (m_valid === 1'b1 && m_ready && wr_n > rd_n) begin
                if (m_data !== model[rd_n % MAXN]) begin
                    $display("FAIL t=%0d ns: 第 %0d 个读出数据是 %0d，应该是 %0d",
                             $time, rd_n, m_data, model[rd_n % MAXN]);
                    errors = errors + 1;
                end
                rd_n = rd_n + 1;
            end
            // 3. 写入握手：记进模型
            if (s_valid && s_ready === 1'b1) begin
                model[wr_n % MAXN] = s_data;
                wr_n = wr_n + 1;
            end
            if (errors > 20) begin
                $display("错误超过 20 处，提前结束。打开 wave.vcd 从第一处错误开始看。");
                $finish;
            end
        end
    end

    integer i;
    integer pushes;
    integer seed = 2026;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_sync_fifo);

        // ---------------- 第 1 段：复位 ----------------
        repeat (3) @(posedge clk);
        #1 rst = 0;
        if (s_ready !== 1'b1 || m_valid !== 1'b0) begin
            $display("FAIL 复位后应为空：s_ready=%b（应为 1），m_valid=%b（应为 0）", s_ready, m_valid);
            $display("如果显示 z 或 x，说明输出还没有驱动，先把 sync_fifo.v 写完。");
            $finish;
        end
        checking = 1;

        // ---------------- 第 2 段：只写不读，直到写满 ----------------
        m_ready = 0;
        s_valid = 1;
        pushes  = 0;
        for (i = 0; i < DEPTH + 4; i = i + 1) begin
            s_data = i + 100;
            @(posedge clk);
            #1;
        end
        s_valid = 0;
        if (wr_n != DEPTH) begin
            $display("FAIL 连续写 %0d 拍后应该正好写进 %0d 个（写满），实际写进 %0d 个", DEPTH + 4, DEPTH, wr_n);
            errors = errors + 1;
        end

        // ---------------- 第 3 段：只读不写，直到读空 ----------------
        m_ready = 1;
        repeat (DEPTH + 4) @(posedge clk);
        #1 m_ready = 0;
        if (rd_n != DEPTH) begin
            $display("FAIL 读空阶段应该正好读出 %0d 个，实际读出 %0d 个", DEPTH, rd_n);
            errors = errors + 1;
        end

        // ---------------- 第 4 段：随机读写 3000 拍 ----------------
        // 上下游都随机地“有时忙”，覆盖同时读写、满时读、空时写等情况
        for (i = 0; i < 3000; i = i + 1) begin
            s_valid = ($random(seed) & 3) != 0;     // 约 75% 的拍有数据要写
            s_data  = $random(seed);
            // 前 1500 拍下游约一半时间忙，FIFO 会经常写满；后 1500 拍下游约 75% 时间可收
            m_ready = (i < 1500) ? ($random(seed) & 1) : (($random(seed) & 3) != 0);
            @(posedge clk);
            #1;
        end

        // 收尾：读空剩下的数据
        s_valid = 0;
        m_ready = 1;
        repeat (DEPTH + 4) @(posedge clk);
        #1;
        if (wr_n != rd_n) begin
            $display("FAIL 结束时写入 %0d 个、读出 %0d 个，有数据丢失或多出", wr_n, rd_n);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS：共写入并按顺序读出 %0d 个数据，满、空、同时读写都正确", wr_n);
        else             $display("共 %0d 处错误", errors);
        $finish;
    end
endmodule
