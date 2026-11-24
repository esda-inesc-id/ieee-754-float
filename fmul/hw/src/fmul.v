`timescale 1ns / 1ps

module fmul #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter MAN_W         = DATA_W - EXP_W,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

   input [DATA_W-1:0] op_a,
   input [DATA_W-1:0] op_b,

   output [DATA_W-1:0] res
);

   localparam EXTRA = 3;

   wire             op_a_sign;
   wire [EXP_W-1:0] op_a_exp;
   wire [MAN_W-1:0] op_a_man;
   wire             op_a_nan;
   wire             op_a_inf;
   wire             op_a_zero;
   unpack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) unpack0 (
      .data_i(op_a),

      .nan     (op_a_nan),
      .infinite(op_a_inf),
      .zero    (op_a_zero),

      .sign    (op_a_sign),
      .exponent(op_a_exp),
      .mantissa(op_a_man)
   );

   wire             op_b_sign;
   wire [EXP_W-1:0] op_b_exp;
   wire [MAN_W-1:0] op_b_man;
   wire             op_b_nan;
   wire             op_b_inf;
   wire             op_b_zero;
   unpack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) unpack1 (
      .data_i(op_b),

      .nan     (op_b_nan),
      .infinite(op_b_inf),
      .zero    (op_b_zero),

      .sign    (op_b_sign),
      .exponent(op_b_exp),
      .mantissa(op_b_man)
   );

   wire               mul_valid_i = valid_i;
   wire               mul_valid_o;
   wire               mul_sign;
   wire [  EXP_W+1:0] mul_exp;
   wire [2*MAN_W-1:0] mul_man;
   wire               mul_special;
   wire [ DATA_W-1:0] mul_res_special;
   mul #(
      .DATA_W       (DATA_W),
      .EXP_W        (EXP_W),
      .SPECIAL_CASES(SPECIAL_CASES)
   ) mul0 (
      .clk(clk),
      .rst(rst),

      .valid_i(mul_valid_i),
      .valid_o(mul_valid_o),

      .op_a_sign(op_a_sign),
      .op_a_exp (op_a_exp),
      .op_a_man (op_a_man),

      .op_a_nan (op_a_nan),
      .op_a_inf (op_a_inf),
      .op_a_zero(op_a_zero),

      .op_b_sign(op_b_sign),
      .op_b_exp (op_b_exp),
      .op_b_man (op_b_man),

      .op_b_nan (op_b_nan),
      .op_b_inf (op_b_inf),
      .op_b_zero(op_b_zero),

      .special    (mul_special),
      .res_special(mul_res_special),

      .res_sign(mul_sign),
      .res_exp (mul_exp),
      .res_man (mul_man)
   );

   wire                   special_int = mul_special;
   wire [     DATA_W-1:0] res_special_int = mul_res_special;

   wire                   norm_valid_i = mul_valid_o;
   wire                   norm_valid_o;
   wire                   norm_special;
   wire [     DATA_W-1:0] norm_res_special;
   wire                   norm_sign;
   wire [      EXP_W+1:0] norm_exp;
   wire [MAN_W+EXTRA-1:0] norm_man;
   norm #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) norm0 (
      .clk(clk),
      .rst(rst),

      .valid_i(norm_valid_i),
      .valid_o(norm_valid_o),

      .sign_i(mul_sign),
      .exp_i (mul_exp),
      .man_i (mul_man),
      .inv_i (1'b0),
      .nsub_i(1'b1),

      .special_i    (special_int),
      .res_special_i(res_special_int),
      .special_o    (norm_special),
      .res_special_o(norm_res_special),

      .sign_o(norm_sign),
      .exp_o (norm_exp),
      .man_o (norm_man),
      .inv_o (),
      .nsub_o()
   );

   wire pack_valid_i = norm_valid_o;
   pack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) pack0 (
      .clk(clk),
      .rst(rst),

      .valid_i(pack_valid_i),
      .valid_o(valid_o),

      .inv (1'b0),
      .nsub(1'b1),

      .special_i    (norm_special),
      .res_special_i(norm_res_special),

      .sign_i(norm_sign),
      .exp_i (norm_exp),
      .man_i (norm_man),

      .data_o(res)
   );

endmodule
