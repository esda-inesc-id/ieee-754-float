`timescale 1ns / 1ps

module unpack #(
   parameter DATA_W = 32,
   parameter EXP_W  = 8,
   parameter MAN_W  = DATA_W - EXP_W,
   // special values: 0 IEEE; 1 FN (OCP FP8 E4M3): no infinities, the only NaN has every
   // exponent and fraction bit set; 2 FINITE (OCP FP4, FP6): no infinities and no NaN
   parameter SPECIAL = 0
) (
   input [DATA_W-1:0] data_i,

   output nan,
   output infinite,
   output zero,

   output             sign,
   output [EXP_W-1:0] exponent,
   output [MAN_W-1:0] mantissa
);

   localparam F_W = MAN_W - 1;

   wire [EXP_W-1:0] exp_field = data_i[DATA_W-2-:EXP_W];
   wire [  F_W-1:0] fraction = data_i[F_W-1:0];

   wire             nsub = |exp_field;
   wire             exp_ones = &exp_field;
   wire             frac_nz = |fraction;

   generate
      if (SPECIAL == 0) begin : gen_ieee
         assign nan      = exp_ones & frac_nz;
         assign infinite = exp_ones & ~frac_nz;
      end else begin : gen_no_inf
         assign nan      = (SPECIAL == 1) & exp_ones & (&fraction);
         assign infinite = 1'b0;
      end
   endgenerate
   assign zero     = ~nsub & ~frac_nz;

   assign sign     = data_i[DATA_W-1];
   // subnormals use the exponent of the smallest normal
   assign exponent = nsub ? exp_field : {{(EXP_W - 1) {1'b0}}, 1'b1};
   assign mantissa = {nsub, fraction};

endmodule
