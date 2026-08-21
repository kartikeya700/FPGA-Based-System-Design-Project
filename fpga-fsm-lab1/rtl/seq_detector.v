`timescale 1ns/1ps
// ---------------------------------------------------------------------
// seq_detector  -  dual, NON-OVERLAPPING 4-bit sequence detector
//
// Detection model: SLIDING WINDOW WITH RESTART ON HIT.
//   Every new bit is tested against the three bits before it, so a match
//   is found wherever it occurs in the stream. When a match is declared
//   the machine restarts from empty: the matched bits are consumed and
//   the NEXT bit becomes the first bit of a fresh attempt. That is what
//   makes it non-overlapping - two reported matches can never share a
//   bit.
//
// State encoding: the state IS the run of bits seen since the last
// restart, capped at three. Fifteen states:
//
//   fill phase (a depth-3 binary tree, entered only after reset or a hit)
//
//                        S  (empty)
//                    0 /        \ 1
//                   S0            S1
//                 /    \        /    \
//              S00     S01    S10    S11
//
//   steady phase (the eight 3-bit history states)
//
//              S000 S001 S010 S011 S100 S101 S110 S111
//
//   In the steady phase the history simply shifts:  S_abc --d--> S_bcd,
//   which is a de Bruijn graph over three bits. The single exception is
//   a hit, which sends the machine back to S.
//
// Output is MEALY: it depends on the current history AND the incoming
// bit, so it asserts on the same tick the fourth bit arrives.
//
// The tree and the shift are independent of SEQ_A / SEQ_B - only the
// output comparison uses them, which is why this module is fully
// parameterised and needs no restructuring for a different ID.
// ---------------------------------------------------------------------
module seq_detector #(
    parameter [3:0] SEQ_A = 4'b1000,
    parameter [3:0] SEQ_B = 4'b0001
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,      // advance one bit
    input  wire       din,       // serial input bit
    output wire       detected,  // Mealy output
    output reg  [3:0] state
);
    localparam [3:0] S    = 4'd0,
                     S0   = 4'd1,  S1   = 4'd2,
                     S00  = 4'd3,  S01  = 4'd4,
                     S10  = 4'd5,  S11  = 4'd6,
                     S000 = 4'd7,  S001 = 4'd8,
                     S010 = 4'd9,  S011 = 4'd10,
                     S100 = 4'd11, S101 = 4'd12,
                     S110 = 4'd13, S111 = 4'd14;

    // Steady states are numbered S000 + history, so the history decodes
    // straight out of the state value.
    wire       at_steady = (state >= S000);
    wire [2:0] hist      = state[2:0] - S000[2:0];
    wire [3:0] window    = {hist, din};

    // --- Mealy output -------------------------------------------------
    assign detected = at_steady &&
                      ((window == SEQ_A) || (window == SEQ_B));

    // --- next-state logic ---------------------------------------------
    reg [3:0] next;

    always @(*) begin
        case (state)
            // fill phase: walk down the tree
            S   : next = din ? S1   : S0;
            S0  : next = din ? S01  : S00;
            S1  : next = din ? S11  : S10;
            S00 : next = din ? S001 : S000;
            S01 : next = din ? S011 : S010;
            S10 : next = din ? S101 : S100;
            S11 : next = din ? S111 : S110;
            // steady phase: restart on a hit, otherwise shift the history
            default: next = detected ? S
                                     : (S000 + {1'b0, hist[1:0], din});
        endcase
    end

    // --- state register -----------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      state <= S;
        else if (tick)   state <= next;
    end
endmodule
