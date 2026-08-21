`timescale 1ns/1ps
// ---------------------------------------------------------------------
// clk_divider
//   Produces TWO things from the fast board clock:
//     tick      - a single-cycle enable pulse in the ORIGINAL clock
//                 domain. All logic runs on `clk` and advances only when
//                 tick is high. This is the correct way to "slow down" a
//                 design: no derived clock, no clock-domain crossing, no
//                 extra constraints, and timing analysis still works.
//     slow_clk  - a toggling signal used ONLY to drive an LED so a human
//                 can see the beat. It is never used as a clock.
// ---------------------------------------------------------------------
module clk_divider #(
    parameter integer DIV = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick,
    output reg  slow_clk
);
    reg [31:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt      <= 32'd0;
            tick     <= 1'b0;
            slow_clk <= 1'b0;
        end else if (cnt == DIV-1) begin
            cnt      <= 32'd0;
            tick     <= 1'b1;
            slow_clk <= ~slow_clk;
        end else begin
            cnt      <= cnt + 32'd1;
            tick     <= 1'b0;
        end
    end
endmodule
