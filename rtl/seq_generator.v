`timescale 1ns/1ps
// ---------------------------------------------------------------------
// seq_generator
//   Predefined on-chip test-pattern source. Walks a constant bit vector
//   MSB-first, one bit per tick, then wraps. Lets the detector be
//   exercised on hardware with no external stimulus.
// ---------------------------------------------------------------------
module seq_generator #(
    parameter integer LEN     = 48,
    parameter [47:0]  PATTERN = 48'd0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,
    input  wire       en,
    output wire       din,
    output reg  [5:0] idx
);
    wire [47:0] pat = PATTERN;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)           idx <= 6'd0;
        else if (tick && en)  idx <= (idx == LEN-1) ? 6'd0 : idx + 6'd1;
    end

    assign din = pat[LEN-1-idx];
endmodule
