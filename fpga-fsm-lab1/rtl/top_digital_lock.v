`timescale 1ns/1ps
`include "config.vh"
// ---------------------------------------------------------------------
// top_digital_lock  -  Problem 2 top level
//   LED0 : serial bit leaving the PISO test-password generator
//   LED1 : unlock (held one slow tick so it is visible)
//   LED2 : lockout
//   LED3 : divided clock heartbeat
//   SW0  : enable the password generator
//   SW1  : 0 = feed the correct password, 1 = feed a wrong one
//          (hold SW1 high for three attempts to demo the lockout)
//   BTN0 : system reset, and the only way out of LOCKOUT
// ---------------------------------------------------------------------
module top_digital_lock (
    input  wire       clk,
    input  wire       btn_rst,
    input  wire       sw_en,
    input  wire       sw_wrong,
    output wire [3:0] led
);
    wire rst_n = ~btn_rst;

    localparam integer DIV  = `CLK_HZ / (2*`TICK_HZ);
    localparam [3:0]   PWD  = `PASSWORD;
    localparam [3:0]   WPWD = ~`PASSWORD;      // guaranteed wrong

    wire tick, slow_clk, sout, empty, unlock, lockout;
    reg  unlock_q;

    clk_divider #(.DIV(DIV)) u_div (
        .clk(clk), .rst_n(rst_n), .tick(tick), .slow_clk(slow_clk));

    wire       load     = tick & empty & sw_en;
    wire [3:0] test_pwd = sw_wrong ? WPWD : PWD;

    piso #(.W(4)) u_piso (
        .clk(clk), .rst_n(rst_n), .tick(tick), .load(load),
        .d(test_pwd), .sout(sout), .empty(empty));

    // FSM only advances on ticks where a real bit is present
    wire fsm_tick = tick & ~empty & sw_en;

    lock_fsm #(.PASSWORD(PWD)) u_lock (
        .clk(clk), .rst_n(rst_n), .tick(fsm_tick), .din(sout),
        .unlock(unlock), .lockout(lockout), .attempts(), .state());

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          unlock_q <= 1'b0;
        else if (fsm_tick)   unlock_q <= unlock;
    end

    assign led = {slow_clk, lockout, unlock_q, sout};
endmodule
