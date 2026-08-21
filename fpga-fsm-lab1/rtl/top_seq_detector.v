`timescale 1ns/1ps
`include "config.vh"
// ---------------------------------------------------------------------
// top_seq_detector  -  Problem 1 top level
//   LED0 : serial test bit currently applied to the detector
//   LED1 : detector output, held for one slow tick so it is visible
//   LED2 : divided clock heartbeat
// ---------------------------------------------------------------------
module top_seq_detector (
    input  wire       clk,
    input  wire       btn_rst,   // active-high push button
    input  wire       sw_en,     // 1 = run generator
    output wire [2:0] led
);
    wire rst_n = ~btn_rst;

    localparam integer DIV = `CLK_HZ / (2*`TICK_HZ);
    localparam [3:0]   A   = `SEQ_A;
    localparam [3:0]   B   = `SEQ_B;

    // 12 nibbles of stimulus: both targets, near misses, back-to-back
    localparam [47:0] TEST_VEC = { A,               // hit  (SEQ_A)
                                   B,               // hit  (SEQ_B)
                                   ~A,              // miss
                                   A,               // hit
                                   A,               // hit, back-to-back
                                   {A[2:0],A[3]},   // rotated: near miss
                                   B,               // hit
                                   ~B,              // miss
                                   A,               // hit
                                   B,               // hit
                                   ~A,              // miss
                                   B };             // hit

    wire tick, slow_clk, din, det;
    reg  det_q;

    clk_divider #(.DIV(DIV)) u_div (
        .clk(clk), .rst_n(rst_n), .tick(tick), .slow_clk(slow_clk));

    seq_generator #(.LEN(48), .PATTERN(TEST_VEC)) u_gen (
        .clk(clk), .rst_n(rst_n), .tick(tick), .en(sw_en),
        .din(din), .idx());

    seq_detector #(.SEQ_A(A), .SEQ_B(B)) u_det (
        .clk(clk), .rst_n(rst_n), .tick(tick), .din(din),
        .detected(det), .state());

    // Mealy pulse is combinational; latch it for one slow tick for the LED
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     det_q <= 1'b0;
        else if (tick)  det_q <= det;
    end

    assign led = {slow_clk, det_q, din};
endmodule
