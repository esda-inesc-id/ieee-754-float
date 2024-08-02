`timescale 1ns / 1ps

// Round to nearest, tie even (3 bits)

module round #(
               parameter DATA_W = 24,
               parameter EXP_W = 8
               )
  (
   input [EXP_W:0]      exponent_i,
   input [DATA_W+3-1:0] mantissa_i,
   input                cin,

   output [EXP_W-1:0]   exponent_o,
   output [DATA_W-1:0]  mantissa_o,
   output               round
   );

   wire [DATA_W+3:0]    mantissa_inv = {(DATA_W+3){cin}} ^ mantissa_i;

   // Round
   wire                 man_lsb    = mantissa_inv[3];
   wire                 guard_bit  = mantissa_inv[2];
   wire                 round_bit  = mantissa_inv[1];
   wire                 sticky_bit = mantissa_inv[0];

   assign round = (guard_bit & (man_lsb | round_bit | sticky_bit)) |
                  (cin & ((man_lsb & ~guard_bit & round_bit & sticky_bit) |
                          (~man_lsb & guard_bit & ~round_bit & ~sticky_bit)));

   wire [DATA_W:0]      mantissa_rnd_int = {1'b0, mantissa_inv[DATA_W+3:3]} + round;

   // Normalize
   wire                 norm = mantissa_rnd_int[DATA_W];

   wire                 exp_max = &exponent_i[EXP_W-1:1];

   wire [EXP_W:0]       exponent_norm = exp_max & exponent_i[0]? exponent_i: exponent_i + 1'b1;
   wire [DATA_W-1:0]    mantissa_norm = exp_max? 1'b0: mantissa_rnd_int[DATA_W:1];

   wire [EXP_W:0]       exponent_rnd_ = norm? exponent_norm: exponent_i;
   wire [DATA_W-1:0]    mantissa_rnd_ = norm? mantissa_norm: mantissa_rnd_int[DATA_W-1:0];

   wire [EXP_W:0]       exponent_rnd = norm? exponent_norm:
                                             exponent_i;
   wire [DATA_W-1:0]    mantissa_rnd = norm? mantissa_norm:
                                             mantissa_rnd_int[DATA_W-1:0];

   localparam EXP_MAX = {{(EXP_W-1){1'b1}}, 1'b0};

   wire [EXP_W:0]       exp_diff = EXP_MAX - exponent_rnd;

   assign exponent_o = exp_diff[EXP_W]? {EXP_W{1'b1}}:
                                        exponent_rnd[EXP_W-1:0];
   assign mantissa_o = exp_diff[EXP_W]? 1'b0:
                                        mantissa_rnd;

endmodule
