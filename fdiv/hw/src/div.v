`timescale 1ns / 1ps

module div #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter MAN_W         = DATA_W - EXP_W,
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

   output reg              special,
   output reg [DATA_W-1:0] res_special,

   output reg               res_sign,
   output reg [  EXP_W+1:0] res_exp,
   output reg [2*MAN_W-1:0] res_man
);

   localparam EXTRA = 3;

   localparam F_W = MAN_W - 1;
   localparam BIAS = 2 ** (EXP_W - 1) - 1;
   localparam [DATA_W-1:0] NAN = {1'b0, {EXP_W{1'b1}}, 1'b1, {(F_W - 1) {1'b0}}};

   // Special cases
   wire special_int = SPECIAL_CASES & (op_a_nan | op_a_inf | op_b_nan | op_b_inf | op_b_zero);
   wire special_sign = op_a_sign ^ op_b_sign;
   wire special_nan = op_a_nan | op_b_nan | (op_a_inf & op_b_inf) | (op_a_zero & op_b_zero);
   wire [DATA_W-1:0] res_special_int = special_nan ? NAN :
      op_b_inf ? {special_sign, {(DATA_W-1){1'b0}}} :
      {special_sign, {EXP_W{1'b1}}, {F_W{1'b0}}};

   // Normalize the significands, so that subnormal operands keep full precision
   localparam LZ_W = $clog2(MAN_W + 1);

   wire [LZ_W-1:0] A_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_a (
      .data_in (op_a_man),
      .symbol  (1'b0),
      .data_out(A_lz)
   );

   wire [LZ_W-1:0] B_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (op_b_man),
      .symbol  (1'b0),
      .data_out(B_lz)
   );

   wire [ MAN_W-1:0] A_Mantissa_norm = op_a_man << A_lz;
   wire [ MAN_W-1:0] B_Mantissa_norm = op_b_man << B_lz;

   // pipeline stage 1
   reg  [  LZ_W-1:0] A_lz_reg;
   reg  [  LZ_W-1:0] B_lz_reg;

   reg               A_sign_reg;
   reg  [ EXP_W-1:0] A_Exponent_reg;

   reg               B_sign_reg;
   reg  [ EXP_W-1:0] B_Exponent_reg;

   reg               special_reg;
   reg  [DATA_W-1:0] res_special_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_lz_reg        <= {LZ_W{1'b0}};
         B_lz_reg        <= {LZ_W{1'b0}};

         A_sign_reg      <= 1'b0;
         A_Exponent_reg  <= {EXP_W{1'b0}};

         B_sign_reg      <= 1'b0;
         B_Exponent_reg  <= {EXP_W{1'b0}};

         special_reg     <= 1'b0;
         res_special_reg <= {DATA_W{1'b0}};
      end else begin
         A_lz_reg        <= A_lz;
         B_lz_reg        <= B_lz;

         A_sign_reg      <= op_a_sign;
         A_Exponent_reg  <= op_a_exp;

         B_sign_reg      <= op_b_sign;
         B_Exponent_reg  <= op_b_exp;

         special_reg     <= special_int;
         res_special_reg <= res_special_int;
      end
   end

   // Division
   wire Temp_sign = A_sign_reg ^ B_sign_reg;
   wire [EXP_W+1:0] A_lz_ext = {{(EXP_W + 2 - LZ_W) {1'b0}}, A_lz_reg};
   wire [EXP_W+1:0] B_lz_ext = {{(EXP_W + 2 - LZ_W) {1'b0}}, B_lz_reg};
   wire [EXP_W+1:0] Temp_Exponent = {2'd0, A_Exponent_reg} - {2'd0, B_Exponent_reg} + BIAS -
      A_lz_ext + B_lz_ext;
   wire [2*MAN_W+EXTRA-1:0] Temp_Mantissa;  // = (A << (MAN_W+EXTRA)) / B
   wire [2*MAN_W+EXTRA-1:0] remainder;
   wire div_en = ~valid_i & ~rst;
   wire div_done_;
   div_subshift #(
      .DATA_W(2 * MAN_W + EXTRA)
   ) div_subshift (
      .clk(clk),

      .en  (div_en),
      .sign(1'b0),
      .done(div_done_),

      .dividend ({A_Mantissa_norm, {(MAN_W + EXTRA) {1'b0}}}),
      .divisor  ({{(MAN_W + EXTRA) {1'b0}}, B_Mantissa_norm}),
      .quotient (Temp_Mantissa),
      .remainder(remainder)
   );

   reg  div_start;
   wire div_done = div_done_ & div_start;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         div_start <= 1'b0;
      end else if (valid_i) begin
         div_start <= 1'b1;
      end
   end

   reg div_done_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         div_done_reg <= 1'b1;
      end else begin
         div_done_reg <= div_done;
      end
   end

   assign valid_o = div_done & ~div_done_reg;

   // pipeline stage 2
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res_sign    <= 1'b0;
         res_exp     <= {(EXP_W + 2) {1'b0}};
         res_man     <= {(2 * MAN_W) {1'b0}};

         special     <= 1'b0;
         res_special <= {DATA_W{1'b0}};
      end else begin
         res_sign <= Temp_sign;
         res_exp <= Temp_Exponent;
         res_man <= {
            1'b0,
            Temp_Mantissa[MAN_W+EXTRA:1],
            Temp_Mantissa[0] | |remainder,
            {(MAN_W - EXTRA - 2) {1'b0}}
         };

         special <= special_reg;
         res_special <= res_special_reg;
      end
   end

endmodule
