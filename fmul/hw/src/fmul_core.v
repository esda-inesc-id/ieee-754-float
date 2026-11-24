`timescale 1ns / 1ps

module fmul_core #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter MAN_W         = DATA_W - EXP_W,
   parameter SPECIAL_CASES = 1,
   parameter OUT_REG       = 0,
   // 1 normalizes a subnormal operand, so the product needs at most a 1-bit left shift
   parameter PRENORM       = 0
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

   output              special,
   output [DATA_W-1:0] res_special,

   output               res_sign,
   output [  EXP_W+1:0] res_exp,
   output [2*MAN_W-1:0] res_man
);

   localparam F_W = MAN_W - 1;
   localparam BIAS = 2 ** (EXP_W - 1) - 1;
   localparam [DATA_W-1:0] NAN = {1'b0, {EXP_W{1'b1}}, 1'b1, {(F_W - 1) {1'b0}}};

   // Special cases
   wire             special_int = SPECIAL_CASES & (op_a_nan | op_a_inf | op_b_nan | op_b_inf);
   wire             nan_int = op_a_nan | op_b_nan | op_a_zero | op_b_zero;

   // Pre-normalization: X is the subnormal operand, if any; when both are subnormal the
   // product underflows to zero, so normalizing one is enough
   localparam LZ_W = $clog2(MAN_W + 1);

   wire             swap = ~op_b_man[MAN_W-1];
   wire [MAN_W-1:0] X_man = swap ? op_b_man : op_a_man;
   wire [MAN_W-1:0] Y_man = swap ? op_a_man : op_b_man;

   wire [ LZ_W-1:0] X_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_x (
      .data_in (X_man),
      .symbol  (1'b0),
      .data_out(X_lz)
   );

   wire [MAN_W-1:0] A_man_in = PRENORM ? X_man << X_lz : op_a_man;
   wire [MAN_W-1:0] B_man_in = PRENORM ? Y_man : op_b_man;
   wire [ LZ_W-1:0] lz_in = PRENORM ? X_lz : {LZ_W{1'b0}};

   // Sign and exponent of the product
   wire             sign = op_a_sign ^ op_b_sign;
   wire [EXP_W+1:0] exponent = {2'd0, op_a_exp} + {2'd0, op_b_exp} - BIAS -
      {{(EXP_W + 2 - LZ_W) {1'b0}}, lz_in};

   // pipeline stage 1: operands ready for the multiplier
   reg              sign_d1;
   reg  [EXP_W+1:0] exp_d1;
   reg  [MAN_W-1:0] A_Mantissa_reg;
   reg  [MAN_W-1:0] B_Mantissa_reg;
   reg              special_d1;
   reg              nan_d1;
   reg              valid_d1;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         sign_d1        <= 1'b0;
         exp_d1         <= {(EXP_W + 2) {1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};
         B_Mantissa_reg <= {MAN_W{1'b0}};
         special_d1     <= 1'b0;
         nan_d1         <= 1'b0;
         valid_d1       <= 1'b0;
      end else begin
         sign_d1        <= sign;
         exp_d1         <= exponent;
         A_Mantissa_reg <= A_man_in;
         B_Mantissa_reg <= B_man_in;
         special_d1     <= special_int;
         nan_d1         <= nan_int;
         valid_d1       <= valid_i;
      end
   end

   // Multiplication
   wire [2*MAN_W-1:0] man = A_Mantissa_reg * B_Mantissa_reg;

   // pipeline stage 2
   reg                sign_d2;
   reg  [  EXP_W+1:0] exp_d2;
   reg                special_d2;
   reg                nan_d2;
   reg                valid_d2;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         sign_d2    <= 1'b0;
         exp_d2     <= {(EXP_W + 2) {1'b0}};
         special_d2 <= 1'b0;
         nan_d2     <= 1'b0;
         valid_d2   <= 1'b0;
      end else begin
         sign_d2    <= sign_d1;
         exp_d2     <= exp_d1;
         special_d2 <= special_d1;
         nan_d2     <= nan_d1;
         valid_d2   <= valid_d1;
      end
   end

   // The product registers have no reset, so they can be placed in the DSP blocks
   reg [2*MAN_W-1:0] man_d2;
   always @(posedge clk) begin
      man_d2 <= man;
   end

   wire res_nan;

   generate
      if (OUT_REG != 0) begin : gen_out_reg
         reg             sign_d3;
         reg [EXP_W+1:0] exp_d3;
         reg             special_d3;
         reg             nan_d3;
         reg             valid_d3;
         always @(posedge clk, posedge rst) begin
            if (rst) begin
               sign_d3    <= 1'b0;
               exp_d3     <= {(EXP_W + 2) {1'b0}};
               special_d3 <= 1'b0;
               nan_d3     <= 1'b0;
               valid_d3   <= 1'b0;
            end else begin
               sign_d3    <= sign_d2;
               exp_d3     <= exp_d2;
               special_d3 <= special_d2;
               nan_d3     <= nan_d2;
               valid_d3   <= valid_d2;
            end
         end

         reg [2*MAN_W-1:0] man_d3;
         always @(posedge clk) begin
            man_d3 <= man_d2;
         end

         assign res_sign = sign_d3;
         assign res_exp  = exp_d3;
         assign res_man  = man_d3;
         assign special  = special_d3;
         assign res_nan  = nan_d3;
         assign valid_o  = valid_d3;
      end else begin : gen_no_out_reg
         assign res_sign = sign_d2;
         assign res_exp  = exp_d2;
         assign res_man  = man_d2;
         assign special  = special_d2;
         assign res_nan  = nan_d2;
         assign valid_o  = valid_d2;
      end
   endgenerate

   assign res_special = res_nan ? NAN : {res_sign, {EXP_W{1'b1}}, {F_W{1'b0}}};

endmodule
