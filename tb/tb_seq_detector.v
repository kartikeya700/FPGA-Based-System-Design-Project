`timescale 1ns/1ps
// ---------------------------------------------------------------------
// tb_seq_detector  -  SELF-CHECKING testbench with a golden model
//
//   The golden model is written at a different level of abstraction from
//   the DUT: a shift register, a saturating counter and a comparison,
//   with no state enumeration at all. If both agree on every cycle over
//   a directed vector plus 4000 random bits, the FSM's tree, its shift
//   transitions and its output decode are almost certainly right.
//
//   Run:  iverilog -g2005 -o sim tb/tb_seq_detector.v rtl/seq_detector.v
//         vvp sim
// ---------------------------------------------------------------------
module tb_seq_detector;

    localparam [3:0] A = 4'b1000;   // keep in step with rtl/config.vh
    localparam [3:0] B = 4'b0001;

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    reg  din   = 1'b0;
    wire det;

    integer errors = 0;
    integer checks = 0;
    integer i;

    always #5 clk = ~clk;

    // ----------------- device under test ------------------------------
    seq_detector #(.SEQ_A(A), .SEQ_B(B)) dut (
        .clk(clk), .rst_n(rst_n), .tick(1'b1), .din(din),
        .detected(det), .state());

    // ----------------- golden model -----------------------------------
    //   g_win  : the last three bits received
    //   g_cnt  : bits since the last restart, saturating at 3. Four bits
    //            must arrive after reset or after a hit before any new
    //            match can be declared - that is the non-overlap rule.
    reg [2:0] g_win;
    reg [1:0] g_cnt;
    reg       g_exp;

    always @(*) g_exp = (g_cnt == 2'd3) &&
                        (({g_win, din} == A) || ({g_win, din} == B));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            g_win <= 3'd0;
            g_cnt <= 2'd0;
        end else if (g_exp) begin
            g_win <= 3'd0;              // hit: discard the matched bits
            g_cnt <= 2'd0;
        end else begin
            g_win <= {g_win[1:0], din};
            g_cnt <= (g_cnt == 2'd3) ? 2'd3 : g_cnt + 2'd1;
        end
    end

    // ----------------- comparator -------------------------------------
    // Mealy outputs are sampled AT the rising edge. Inside an
    // @(posedge clk) block the state registers still hold their pre-edge
    // values (non-blocking assignment), which is exactly the instant a
    // Mealy output is defined for. Stimulus is driven on the falling
    // edge so it is stable across the sampling edge.
    always @(posedge clk) begin
        if (rst_n) begin
            checks = checks + 1;
            if (det !== g_exp) begin
                errors = errors + 1;
                $display("MISMATCH t=%0t din=%b state=%0d dut=%b golden=%b",
                         $time, din, dut.state, det, g_exp);
            end
        end
    end

    // ----------------- stimulus ---------------------------------------
    task send(input [3:0] nibble);
        integer k;
        begin
            for (k = 3; k >= 0; k = k-1) begin
                @(negedge clk);
                din = nibble[k];
            end
        end
    endtask

    initial begin
        $dumpfile("tb_seq_detector.vcd");
        $dumpvars(0, tb_seq_detector);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // directed: both targets, back-to-back, near misses
        send(A); send(B); send(~A); send(A); send(A);
        send({A[2:0],A[3]}); send(B); send(~B);

        // deliberately unaligned: a match that starts mid-nibble. A
        // frame-based detector would miss these; a sliding one must not.
        send(4'b0000); send({2'b00, A[3:2]}); send({A[1:0], 2'b00});

        // random soak
        for (i = 0; i < 4000; i = i+1) begin
            @(negedge clk);
            din = $random;
        end

        @(negedge clk);
        if (errors == 0)
            $display("PASS  %0d cycles checked, 0 mismatches", checks);
        else
            $display("FAIL  %0d mismatches in %0d cycles", errors, checks);
        $finish;
    end
endmodule
