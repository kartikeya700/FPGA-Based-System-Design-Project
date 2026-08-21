`timescale 1ns/1ps
// ---------------------------------------------------------------------
// lock_fsm  -  Problem 2, MEALY digital lock
//
//   Straight-chain detector: any wrong bit sends the machine back to S0
//   immediately (this is what the handout specifies - it is stricter
//   than a textbook detector, which would backtrack to the longest
//   still-valid prefix).
//
//     S0 -b3-> S1 -b2-> S2 -b1-> S3 --b0/unlock=1--> back to S0
//      ^        |        |        |
//      +--------+--------+--------+   (any wrong bit, attempts++)
//
//   There is no separate UNLOCKED state: a Mealy machine asserts the
//   output on the transition itself, so adding one would waste a clock
//   and break the 4-bit framing.
//
//   MEALY: `unlock` is a function of state AND din, so it asserts on the
//   same tick the final correct bit arrives - not one tick later. That
//   is the whole point of using Mealy here.
//
//   An "attempt" is counted as failed the moment a wrong bit appears.
//   Three failed attempts -> LOCKOUT, which only rst_n can leave.
// ---------------------------------------------------------------------
module lock_fsm #(
    parameter [3:0] PASSWORD = 4'b0111   // consumed MSB first
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,
    input  wire       din,
    output reg        unlock,     // Mealy
    output wire       lockout,
    output reg  [1:0] attempts,
    output reg  [2:0] state
);
    localparam [2:0] S0      = 3'd0,
                     S1      = 3'd1,
                     S2      = 3'd2,
                     S3      = 3'd3,
                     LOCKOUT = 3'd4;

    reg [2:0] next;
    reg       bad;

    always @(*) begin
        next   = S0;
        unlock = 1'b0;
        bad    = 1'b0;
        case (state)
            S0      : if (din == PASSWORD[3]) next = S1;
                      else begin next = S0; bad = 1'b1; end
            S1      : if (din == PASSWORD[2]) next = S2;
                      else begin next = S0; bad = 1'b1; end
            S2      : if (din == PASSWORD[1]) next = S3;
                      else begin next = S0; bad = 1'b1; end
            S3      : if (din == PASSWORD[0]) begin
                          next   = S0;            // non-overlapping restart
                          unlock = 1'b1;          // <- Mealy assertion
                      end else begin
                          next = S0; bad = 1'b1;
                      end
            LOCKOUT : begin next = LOCKOUT; bad = 1'b0; end
            default : next = S0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S0;
            attempts <= 2'd0;
        end else if (tick && state != LOCKOUT) begin
            if (bad) begin
                if (attempts == 2'd2) begin
                    state    <= LOCKOUT;          // third consecutive fail
                    attempts <= 2'd3;
                end else begin
                    state    <= next;
                    attempts <= attempts + 2'd1;
                end
            end else begin
                state <= next;
                if (unlock) attempts <= 2'd0;     // success clears history
            end
        end
    end

    assign lockout = (state == LOCKOUT);
endmodule
