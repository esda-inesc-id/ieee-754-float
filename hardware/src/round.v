`timescale 1ns / 1ps

// Round to nearest, tie even (3 bits)

module round #(
               parameter DATA_W = 24,
               parameter EXP_W = 8
               )
  (
   input [EXP_W:0]      exponent,
   input [DATA_W+3-1:0] mantissa,
   input                cin,

   output [EXP_W-1:0]   exponent_rnd,
   output [DATA_W-1:0]  mantissa_rnd,
   output               round
   );

   wire [DATA_W-1:0]    mantissa_inv = {DATA_W{cin}} ^ mantissa[DATA_W+3-1 -: DATA_W];

   // Round
   wire                 man_lsb    = mantissa_inv[3];
   wire                 guard_bit  = mantissa_inv[2];
   wire                 round_bit  = mantissa_inv[1];
   wire                 sticky_bit = mantissa_inv[0];

   assign round = (guard_bit & (man_lsb | round_bit | sticky_bit)) |
                  (cin & ((man_lsb & ~guard_bit & round_bit & sticky_bit) |
                          (~man_lsb & guard_bit & ~round_bit & ~sticky_bit)));

   wire [DATA_W:0]      mantissa_rnd_int = {1'b0, mantissa_inv} + round;

   // Normalize
   wire                 norm = mantissa_rnd_int[DATA_W];

   wire                 exp_max = &exponent[EXP_W-1:1];

   wire [EXP_W-1:0]     exponent_norm = exp_max & exponent[0]? exponent[EXP_W-1:0]: exponent[EXP_W-1:0] + 1'b1;
   wire [DATA_W-1:0]    mantissa_norm = exp_max? 1'b0: mantissa_rnd_int[DATA_W:1];

   wire [EXP_W-1:0]     exponent_rnd_ = norm? exponent_norm: exponent;
   wire [DATA_W-1:0]    mantissa_rnd_ = norm? mantissa_norm: mantissa_rnd_int[DATA_W-1:0];

   assign exponent_rnd = exponent[EXP_W]? {EXP_W{1'b1}}:
                                    norm? exponent_norm:
                                          exponent[EXP_W-1:0];
   assign mantissa_rnd = exponent[EXP_W]? 1'b0:
                                    norm? mantissa_norm:
                                          mantissa_rnd_int[DATA_W-1:0];

endmodule
