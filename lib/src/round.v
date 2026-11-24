`timescale 1ns / 1ps

// Rounds from the three bits below the mantissa (guard, round and sticky) in the
// mode rnd_mode:
//   0 to nearest, ties to even   1 toward zero   2 toward -infinity
//   3 toward +infinity           4 to nearest, ties away from zero
// Other values round to nearest, ties to even.

module round #(
   parameter DATA_W = 24,
   parameter EXP_W  = 8
) (
   input [   EXP_W+1:0] exponent_i,
   input [DATA_W+3-1:0] mantissa_i,
   input                inv,
   input                sign,
   input [         2:0] rnd_mode,

   output [ EXP_W-1:0] exponent_o,
   output [DATA_W-1:0] mantissa_o,
   output              round
);

   localparam [2:0] RNE = 3'd0, RTZ = 3'd1, RDN = 3'd2, RUP = 3'd3, RMM = 3'd4;

   // With inv, the mantissa is in one's complement: the magnitude is the inverted
   // mantissa plus one unit of the sticky bit
   wire [DATA_W+3-1:0] mantissa_inv = {(DATA_W + 3) {inv}} ^ mantissa_i;
   wire [         3:0] grs = {1'b0, mantissa_inv[2:0]} + {3'd0, inv};

   wire                carry = grs[3];
   wire                man_lsb = mantissa_inv[3];
   wire                guard_bit = grs[2];
   wire                round_bit = grs[1];
   wire                sticky_bit = grs[0];
   wire                inexact = guard_bit | round_bit | sticky_bit;

   reg                 up;
   always @* begin
      case (rnd_mode)
         RTZ:     up = 1'b0;
         RDN:     up = sign & inexact;
         RUP:     up = ~sign & inexact;
         RMM:     up = guard_bit;
         default: up = guard_bit & (man_lsb | round_bit | sticky_bit);
      endcase
   end

   // carry and up are never both set: carry leaves guard, round and sticky at zero
   assign round = carry | up;

   wire [  DATA_W:0] mantissa_rnd_int = {1'b0, mantissa_inv[DATA_W+3-1:3]} + round;

   // Normalize
   wire              norm = mantissa_rnd_int[DATA_W];

   wire [ EXP_W+1:0] exponent_norm = exponent_i + 1'b1;
   wire [DATA_W-1:0] mantissa_norm = mantissa_rnd_int[DATA_W:1];

   wire [ EXP_W+1:0] exponent_rnd = norm ? exponent_norm : exponent_i;
   wire [DATA_W-1:0] mantissa_rnd = norm ? mantissa_norm : mantissa_rnd_int[DATA_W-1:0];

   // Overflow gives infinity, or the largest finite number when the mode rounds
   // toward zero for the sign of the result
   localparam [EXP_W-1:0] EXP_MAX = {{(EXP_W - 1) {1'b1}}, 1'b0};

   wire [EXP_W+1:0] exp_diff = {2'd0, EXP_MAX} - exponent_rnd;
   // a zero mantissa is never an overflow: the exponent of a zero sum can wrap
   wire             overflow = exp_diff[EXP_W+1] & (|mantissa_rnd_int);
   wire             ovf_inf = (rnd_mode == RTZ) ? 1'b0 :
                              (rnd_mode == RDN) ? sign :
                              (rnd_mode == RUP) ? ~sign : 1'b1;

   assign exponent_o = ~overflow ? exponent_rnd[EXP_W-1:0] :
                       ovf_inf ? {EXP_W{1'b1}} : EXP_MAX;
   assign mantissa_o = ~overflow ? mantissa_rnd :
                       ovf_inf ? {1'b1, {(DATA_W - 1) {1'b0}}} : {DATA_W{1'b1}};

endmodule
