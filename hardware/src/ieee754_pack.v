`timescale 1ns / 1ps

module ieee754_pack
  #(
    parameter DATA_W = 32,
    parameter EXP_W = 8
    )
   (
    input                     clk,
    input                     rst,

    input                     start,
    output reg                done,

    input                     inv,
    input                     nsub,

    input                     sign_i,
    input [EXP_W+1:0]         exp_i,
    input [`MAN_W+`EXTRA-1:0] man_i,

    output reg [DATA_W-1:0]   data_o
    );

   // Round
   wire [EXP_W-1:0]           exp_rnd;
   wire [`MAN_W-1:0]          man_rnd;
   wire                       round;
   round
     #(
       .DATA_W (`MAN_W),
       .EXP_W  (EXP_W)
       )
   round0
     (
      .exponent_i (exp_i),
      .mantissa_i (man_i),
      .inv        (inv),

      .exponent_o (exp_rnd),
      .mantissa_o (man_rnd),
      .round      (round)
      );

   wire                       nzero = |man_i[`MAN_W+`EXTRA-1:3] | round;

   // Pack
   wire [`F_W-1:0]            fraction = man_rnd[`F_W-1:0];
   wire [EXP_W-1:0]           exponent = man_rnd[`MAN_W-1]? exp_rnd: {EXP_W{1'b0}};
   wire                       sign     = (nzero | nsub) & sign_i;

   wire [DATA_W-1:0]          data_o_int = {sign, exponent, fraction};

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         data_o <= {DATA_W{1'b0}};
         done <= 1'b0;
      end else begin
         data_o <= data_o_int;
         done <= start;
      end
   end

endmodule
