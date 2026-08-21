`timescale 1ns/1ps
// ---------------------------------------------------------------------
// tb_lock_fsm  -  SELF-CHECKING testbench with a golden model
//
//   Golden model uses no state enumeration: a progress counter plus an
//   attempt counter written straight from the spec sentences.
//
//   Run:  iverilog -g2005 -o sim tb/tb_lock_fsm.v rtl/lock_fsm.v
//         vvp sim
// ---------------------------------------------------------------------
module tb_lock_fsm;

    localparam [3:0] P = 4'b0010;   // keep in step with rtl/config.vh

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    reg  din   = 1'b0;
    wire unlock, lockout;

    integer errors = 0;
    integer checks = 0;
    integer i;

    always #5 clk = ~clk;

    lock_fsm #(.PASSWORD(P)) dut (
        .clk(clk), .rst_n(rst_n), .tick(1'b1), .din(din),
        .unlock(unlock), .lockout(lockout), .attempts(), .state());

    // ----------------- golden model -----------------------------------
    reg [2:0] g_pos;      // how many correct bits so far, 0..3
    reg [2:0] g_fails;
    reg       g_locked;
    reg       g_ok, g_unlock;
    wire [3:0] pw = P;

    always @(*) begin
        g_ok     = (din == pw[3 - g_pos]);
        g_unlock = !g_locked && g_ok && (g_pos == 3);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            g_pos    <= 3'd0;
            g_fails  <= 3'd0;
            g_locked <= 1'b0;
        end else if (!g_locked) begin
            if (!g_ok) begin
                g_pos <= 3'd0;
                if (g_fails == 3'd2) g_locked <= 1'b1;
                g_fails <= g_fails + 3'd1;
            end else if (g_pos == 3) begin
                g_pos   <= 3'd0;
                g_fails <= 3'd0;
            end else begin
                g_pos <= g_pos + 3'd1;
            end
        end
    end

    // ----------------- comparator -------------------------------------
    // Mealy outputs are sampled AT the rising edge (pre-edge register
    // values), with stimulus driven on the falling edge.
    always @(posedge clk) begin
        if (rst_n) begin
            checks = checks + 1;
            if (unlock !== g_unlock) begin
                errors = errors + 1;
                $display("UNLOCK MISMATCH t=%0t dut=%b golden=%b",
                         $time, unlock, g_unlock);
            end
            if (lockout !== g_locked) begin
                errors = errors + 1;
                $display("LOCKOUT MISMATCH t=%0t dut=%b golden=%b",
                         $time, lockout, g_locked);
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
        $dumpfile("tb_lock_fsm.vcd");
        $dumpvars(0, tb_lock_fsm);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        send(P);                      // unlock
        send(~P);                     // fail 1
        send(~P);                     // fail 2
        send(P);                      // unlock again, counter cleared
        send(~P); send(~P); send(~P); // three fails -> LOCKOUT
        send(P);                      // must NOT unlock now
        send(P);

        @(negedge clk); rst_n = 1'b0;
        @(negedge clk); rst_n = 1'b1;
        send(P);                      // reset clears LOCKOUT

        for (i = 0; i < 2000; i = i+1) begin
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
