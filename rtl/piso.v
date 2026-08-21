`timescale 1ns/1ps
// ---------------------------------------------------------------------
// piso  -  Parallel-In Serial-Out shift register
//   Loads a W-bit test password in parallel, then shifts it out one bit
//   per tick, MSB first. `empty` goes high when all W bits have gone.
// ---------------------------------------------------------------------
module piso #(
    parameter integer W = 4
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         tick,
    input  wire         load,
    input  wire [W-1:0] d,
    output wire         sout,
    output wire         empty
);
    reg [W-1:0] sr;
    reg [2:0]   cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sr  <= {W{1'b0}};
            cnt <= 3'd0;
        end else if (load) begin
            sr  <= d;
            cnt <= W[2:0];
        end else if (tick && cnt != 3'd0) begin
            sr  <= {sr[W-2:0], 1'b0};
            cnt <= cnt - 3'd1;
        end
    end

    assign sout  = sr[W-1];
    assign empty = (cnt == 3'd0);
endmodule
