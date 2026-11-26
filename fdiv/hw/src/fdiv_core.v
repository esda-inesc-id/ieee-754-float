`timescale 1ns / 1ps

module fdiv_core #(
   parameter EXP_W         = 8,
   parameter MAN_W         = 24,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

   input             op_a_sign,
   input [EXP_W-1:0] op_a_exp,
   input [MAN_W-1:0] op_a_man,

   input op_a_nan,
   input op_a_inf,
   input op_a_zero,

   input             op_b_sign,
   input [EXP_W-1:0] op_b_exp,
   input [MAN_W-1:0] op_b_man,

   input op_b_nan,
   input op_b_inf,
   input op_b_zero,

   // The results are valid with valid_o and stay until the next valid_i
   // special result code {kind, sign}, as in pack
   output [       2:0] res_special,

   output             res_sign,
   output [EXP_W+1:0] res_exp,
   // quotient bits from weight 1 down to 2**-(MAN_W+2), then the sticky bit; norm
   // reads the top bit as weight 2, so res_exp is one less than the quotient exponent
   output [MAN_W+3:0] res_man
);

   localparam EXTRA = 3;

   localparam BIAS = 2 ** (EXP_W - 1) - 1;

   // Special cases
   wire special_int = SPECIAL_CASES & (op_a_nan | op_a_inf | op_b_nan | op_b_inf | op_b_zero);
   wire special_sign = op_a_sign ^ op_b_sign;
   wire special_nan = op_a_nan | op_b_nan | (op_a_inf & op_b_inf) | (op_a_zero & op_b_zero);
   // a NaN, a zero for a zero dividend or a finite number over infinity, or an infinity
   wire [2:0] res_special_int = {
      special_int ? (special_nan ? 2'b01 : op_b_inf ? 2'b11 : 2'b10) : op_a_zero ? 2'b11 : 2'b00,
      special_sign
   };

   // Normalize the significands, so that subnormal operands keep full precision
   localparam LZ_W = $clog2(MAN_W + 1);

   wire [LZ_W-1:0] A_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_a (
      .data_in (op_a_man),
      .data_out(A_lz)
   );

   wire [LZ_W-1:0] B_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (op_b_man),
      .data_out(B_lz)
   );

   wire [ MAN_W-1:0] A_Mantissa_norm = op_a_man << A_lz;
   wire [ MAN_W-1:0] B_Mantissa_norm = op_b_man << B_lz;

   // Exponent of the quotient
   wire [EXP_W+1:0] exponent = {2'd0, op_a_exp} - {2'd0, op_b_exp} + (BIAS - 1) - A_lz + B_lz;

   // Sign, exponent and special cases, captured with valid_i
   reg  [ EXP_W+1:0] exp_reg;
   reg               sign_reg;
   reg  [       2:0] res_special_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         exp_reg         <= {(EXP_W + 2) {1'b0}};
         sign_reg        <= 1'b0;
         res_special_reg <= 3'd0;
      end else if (valid_i) begin
         exp_reg         <= exponent;
         sign_reg        <= op_a_sign ^ op_b_sign;
         res_special_reg <= res_special_int;
      end
   end

   // Restoring division of the normalized significands, one quotient bit per cycle.
   // The partial remainder stays below twice the divisor. A marker bit, loaded below the
   // quotient, reaches the top of quo after Q_W steps and ends the division.
   localparam Q_W = MAN_W + EXTRA;

   reg  [  MAN_W:0] rem;
   reg  [MAN_W-1:0] dvs;
   reg  [    Q_W:0] quo;
   reg              last;

   wire             busy = ~quo[Q_W];
   wire [MAN_W+1:0] diff = {1'b0, rem} - {2'd0, dvs};
   wire             ge = ~diff[MAN_W+1];

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         rem  <= {(MAN_W + 1) {1'b0}};
         dvs  <= {MAN_W{1'b0}};
         quo  <= {1'b1, {Q_W{1'b0}}};
         last <= 1'b0;
      end else if (valid_i) begin
         rem  <= {1'b0, A_Mantissa_norm};
         dvs  <= B_Mantissa_norm;
         quo  <= {{Q_W{1'b0}}, 1'b1};
         last <= 1'b0;
      end else begin
         if (busy) begin
            rem <= {ge ? diff[MAN_W-1:0] : rem[MAN_W-1:0], 1'b0};
            quo <= {quo[Q_W-1:0], ge};
         end
         last <= busy & quo[Q_W-1];
      end
   end

   // a new valid_i abandons the division
   assign valid_o     = last & ~valid_i;
   assign res_sign    = sign_reg;
   assign res_exp     = exp_reg;
   assign res_man     = {quo[Q_W-1:0], |rem};
   assign res_special = res_special_reg;

endmodule
