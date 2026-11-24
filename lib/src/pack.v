`timescale 1ns / 1ps

module pack #(
   parameter DATA_W = 32,
   parameter EXP_W  = 8,
   parameter MAN_W  = DATA_W - EXP_W,
   // input exponent width, as in round
   parameter EXP_I_W = EXP_W + 1,
   // 1: a negative mantissa is in one's complement; only fmac needs it
   parameter INV    = 0
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

   input               sign_i,
   input [EXP_I_W-1:0] exp_i,
   input [MAN_W+3-1:0] man_i,

   output reg [DATA_W-1:0] data_o
);

   localparam F_W = MAN_W - 1;

   // Round
   wire [EXP_W-1:0] exp_rnd;
   wire [MAN_W-1:0] man_rnd;
   wire             round;
   round #(
      .DATA_W(MAN_W),
      .EXP_W (EXP_W),
      .EXP_I_W(EXP_I_W),
      .INV   (INV)
   ) round0 (
      .exponent_i(exp_i),
      .mantissa_i(man_i),
      .sign      (sign_i),
      .rnd_mode  (rnd_mode),

      .exponent_o(exp_rnd),
      .mantissa_o(man_rnd),
      .round     (round)
   );

   wire              nzero = |man_i | round;

   // Pack: the computed result, or the special result of kind 1 (the canonical NaN),
   // 2 (an infinity) or 3 (a zero)
   wire [1:0] kind = res_special_i[2:1];
   wire       normal = (kind == 2'd0);

   // A zero from the datapath is an exact cancellation: +0, or -0 when rounding toward
   // -infinity. Zero operands come as special zero codes, with their sign.
   wire       sign = ~normal ? res_special_i[0] & (kind != 2'd1) :
                     nzero ? sign_i : (rnd_mode == 3'd2);
   wire [EXP_W-1:0] exponent = ~normal ? {EXP_W{kind != 2'd3}} :
                               man_rnd[MAN_W-1] ? exp_rnd : {EXP_W{1'b0}};
   wire [F_W-1:0] fraction = normal ? man_rnd[F_W-1:0] : {kind == 2'd1, {(F_W - 1) {1'b0}}};

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         data_o  <= {DATA_W{1'b0}};
         valid_o <= 1'b0;
      end else begin
         data_o  <= {sign, exponent, fraction};
         valid_o <= valid_i;
      end
   end

endmodule
