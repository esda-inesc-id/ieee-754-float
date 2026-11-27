`timescale 1ns / 1ps

module pack #(
   parameter DATA_W = 32,
   parameter EXP_W  = 8,
   parameter MAN_W  = DATA_W - EXP_W,
   // 1: the input is normalized first, in a pipeline stage of its own (norm.v), for
   // the cores that leave it unnormalized (fadd, fmul, fdiv); 0: the input is normalized
   // (ffma, fmac)
   parameter NORM   = 0,
   // NORM=1: norm's mantissa input width (top bit of weight 2), right shift to a
   // subnormal, and leading-sign count width; see norm.v
   parameter IN_W   = 2 * MAN_W,
   parameter RSHIFT = 1,
   parameter LZC_W  = IN_W,
   // NORM=0: input exponent width, as in round
   parameter EXP_I_W = EXP_W + 1,
   // 1: a negative mantissa is in one's complement; only fmac needs it
   parameter INV    = 0,
   // special values, as in unpack
   parameter SPECIAL = 0
) (
   input clk,
   input rst,

   input      valid_i,
   output reg valid_o,

   // rounding mode, as in round
   input [2:0] rnd_mode,

   // special result code {kind, sign}; kind 0: the computed result, 1: the canonical
   // NaN, 2: an infinity, 3: a zero, with the sign
   input [       2:0] res_special_i,

   input sign_i,
   // NORM=1: EXP_W+2 bits, signed, or EXP_W unsigned with RSHIFT=0, as in norm
   input [(NORM != 0 ? (RSHIFT != 0 ? EXP_W + 2 : EXP_W) : EXP_I_W)-1:0] exp_i,
   input [(NORM != 0 ? IN_W : MAN_W + 3)-1:0] man_i,

   output reg [DATA_W-1:0] data_o
);

   localparam F_W = MAN_W - 1;
   // exponent width at the rounder
   localparam R_EXP_W = NORM != 0 ? (RSHIFT != 0 ? EXP_W + 1 : EXP_W) : EXP_I_W;

   // Normalize (NORM=1), with the rounding mode and the special code alongside
   wire               r_valid;
   wire [        2:0] r_rnd_mode;
   wire [        2:0] r_special;
   wire               r_sign;
   wire [R_EXP_W-1:0] r_exp;
   wire [MAN_W+3-1:0] r_man;
   generate
      if (NORM != 0) begin : gen_norm
         norm #(
            .DATA_W(DATA_W),
            .EXP_W (EXP_W),
            .MAN_W (MAN_W),
            .IN_W  (IN_W),
            .RSHIFT(RSHIFT),
            .LZC_W (LZC_W)
         ) norm0 (
            .clk(clk),
            .rst(rst),

            .valid_i(valid_i),
            .valid_o(r_valid),

            .sign_i       (sign_i),
            .exp_i        (exp_i),
            .man_i        (man_i),
            .res_special_i(res_special_i),
            .res_special_o(r_special),

            .sign_o(r_sign),
            .exp_o (r_exp),
            .man_o (r_man)
         );
         reg [2:0] rnd_mode_reg;
         always @(posedge clk, posedge rst) begin
            if (rst) begin
               rnd_mode_reg <= 3'd0;
            end else begin
               rnd_mode_reg <= rnd_mode;
            end
         end
         assign r_rnd_mode = rnd_mode_reg;
      end else begin : gen_no_norm
         assign r_valid    = valid_i;
         assign r_rnd_mode = rnd_mode;
         assign r_special  = res_special_i;
         assign r_sign     = sign_i;
         assign r_exp      = exp_i;
         assign r_man      = man_i;
      end
   endgenerate

   // Round
   wire [EXP_W-1:0] exp_rnd;
   wire [MAN_W-1:0] man_rnd;
   wire             round;
   round #(
      .DATA_W(MAN_W),
      .EXP_W (EXP_W),
      .EXP_I_W(R_EXP_W),
      .INV   (INV),
      .SPECIAL(SPECIAL)
   ) round0 (
      .exponent_i(r_exp),
      .mantissa_i(r_man),
      .sign      (r_sign),
      .rnd_mode  (r_rnd_mode),

      .exponent_o(exp_rnd),
      .mantissa_o(man_rnd),
      .round     (round)
   );

   wire              nzero = |r_man | round;

   // Pack: the computed result, or the special result of kind 1 (the canonical NaN),
   // 2 (an infinity) or 3 (a zero)
   wire [1:0] kind = r_special[2:1];
   wire       normal = (kind == 2'd0);

   // A zero from the datapath is an exact cancellation: +0, or -0 when rounding toward
   // -infinity. Zero operands come as special zero codes, with their sign.
   wire       sign = ~normal ? r_special[0] & (kind != 2'd1) :
                     nzero ? r_sign : (r_rnd_mode == 3'd2);
   // Without infinities (FN, FINITE) an infinity is the largest finite number; the NaN
   // of FN has every bit set but the sign, and FINITE, without NaN, gives the largest
   // positive number, the same bits
   wire [EXP_W-1:0] exponent = ~normal ? {EXP_W{kind != 2'd3}} :
                               man_rnd[MAN_W-1] ? exp_rnd : {EXP_W{1'b0}};
   wire [F_W-1:0] fraction;
   generate
      if (SPECIAL == 0) begin : gen_ieee
         assign fraction = normal ? man_rnd[F_W-1:0] : {kind == 2'd1, {(F_W - 1) {1'b0}}};
      end else begin : gen_no_inf
         assign fraction = normal ? man_rnd[F_W-1:0] :
                           (kind == 2'd3) ? {F_W{1'b0}} :
                           {{(F_W - 1) {1'b1}}, (SPECIAL != 1) | (kind == 2'd1)};
      end
   endgenerate

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         data_o  <= {DATA_W{1'b0}};
         valid_o <= 1'b0;
      end else begin
         data_o  <= {sign, exponent, fraction};
         valid_o <= r_valid;
      end
   end

endmodule
