`timescale 1ns / 1ps

// Rounds from the three bits below the mantissa (guard, round and sticky) in the
// mode rnd_mode:
//   0 to nearest, ties to even   1 toward zero   2 toward -infinity
//   3 toward +infinity           4 to nearest, ties away from zero
// Other values round to nearest, ties to even.

module round #(
   parameter DATA_W = 24,
   parameter EXP_W  = 8,
   // input exponent width: EXP_W+1, or EXP_W when it never exceeds 2**EXP_W-1 (fadd)
   parameter EXP_I_W = EXP_W + 1,
   // 1: a negative mantissa is in one's complement; only fmac needs it
   parameter INV    = 0,
   // special values, as in unpack: 0 IEEE; 1 FN and 2 FINITE have no infinities, so
   // overflow saturates to the largest finite number in every mode
   parameter SPECIAL = 0
) (
   input [ EXP_I_W-1:0] exponent_i,
   input [DATA_W+3-1:0] mantissa_i,
   input                sign,
   input [         2:0] rnd_mode,

   output [ EXP_W-1:0] exponent_o,
   output [DATA_W-1:0] mantissa_o,
   output              round
);

   // RNE (0) and the unused codes take the default branch
   localparam [2:0] RTZ = 3'd1, RDN = 3'd2, RUP = 3'd3, RMM = 3'd4;

   // With INV, a negative mantissa is in one's complement: its magnitude is the
   // inverted mantissa plus one unit of the sticky bit
   wire [DATA_W+3-1:3] mantissa_inv;
   wire                guard_bit;
   wire                round_bit;
   wire                sticky_bit;
   reg                 up;
   generate
      if (INV != 0) begin : gen_inv
         assign mantissa_inv = {DATA_W{sign}} ^ mantissa_i[DATA_W+3-1:3];
         wire [3:0] grs = {1'b0, {3{sign}} ^ mantissa_i[2:0]} + {3'd0, sign};
         assign {guard_bit, round_bit, sticky_bit} = grs[2:0];
         // carry and up are never both set: carry leaves guard, round and sticky at zero
         assign round = grs[3] | up;
      end else begin : gen_no_inv
         assign mantissa_inv = mantissa_i[DATA_W+3-1:3];
         assign round = up;
         assign {guard_bit, round_bit, sticky_bit} = mantissa_i[2:0];
      end
   endgenerate

   wire                man_lsb = mantissa_inv[3];
   wire                inexact = guard_bit | round_bit | sticky_bit;

   always @* begin
      case (rnd_mode)
         RTZ:     up = 1'b0;
         RDN:     up = sign & inexact;
         RUP:     up = ~sign & inexact;
         RMM:     up = guard_bit;
         default: up = guard_bit & (man_lsb | round_bit | sticky_bit);
      endcase
   end

   wire [  DATA_W:0] mantissa_rnd_int = {1'b0, mantissa_inv[DATA_W+3-1:3]} + round;

   // Normalize
   wire              norm = mantissa_rnd_int[DATA_W];

   wire [   EXP_W:0] exponent_norm = exponent_i + 1'b1;
   wire [DATA_W-1:0] mantissa_norm = mantissa_rnd_int[DATA_W:1];

   wire [   EXP_W:0] exponent_rnd = norm ? exponent_norm : exponent_i;
   wire [DATA_W-1:0] mantissa_rnd = norm ? mantissa_norm : mantissa_rnd_int[DATA_W-1:0];

   // Overflow gives infinity, or the largest finite number when the mode rounds
   // toward zero for the sign of the result; without infinities it saturates
   localparam [EXP_W-1:0] EXP_MAX = {{(EXP_W - 1) {1'b1}}, 1'b0};

   // a zero mantissa is never an overflow: the exponent of a zero sum can wrap
   wire             overflow;
   generate
      if (SPECIAL == 0) begin : gen_ieee
         // exponent_rnd > EXP_MAX: the top bit, or all ones below it
         assign overflow = (exponent_rnd[EXP_W] | (&exponent_rnd[EXP_W-1:0])) & (|mantissa_rnd_int);
         wire ovf_inf = (rnd_mode == RTZ) ? 1'b0 :
                          (rnd_mode == RDN) ? sign :
                          (rnd_mode == RUP) ? ~sign : 1'b1;
         assign exponent_o = ~overflow ? exponent_rnd[EXP_W-1:0] :
                             ovf_inf ? {EXP_W{1'b1}} : EXP_MAX;
         assign mantissa_o = ~overflow ? mantissa_rnd :
                             ovf_inf ? {1'b1, {(DATA_W - 1) {1'b0}}} : {DATA_W{1'b1}};
      end else begin : gen_sat
         // the largest exponent holds finite numbers; in FN its all-ones mantissa is NaN
         assign overflow = (exponent_rnd[EXP_W] |
                            ((SPECIAL == 1) & (&exponent_rnd[EXP_W-1:0]) & (&mantissa_rnd))) &
                           (|mantissa_rnd_int);
         assign exponent_o = overflow ? {EXP_W{1'b1}} : exponent_rnd[EXP_W-1:0];
         assign mantissa_o = overflow ? {{(DATA_W - 1) {1'b1}}, SPECIAL != 1} : mantissa_rnd;
      end
   endgenerate

endmodule
