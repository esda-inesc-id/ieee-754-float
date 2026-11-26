`timescale 1ns / 1ps

module fdiv #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

   // rounding mode, sampled with valid_i; see round.v for the encoding
   input [2:0] rnd_mode,

   input [DATA_W-1:0] op_a,
   input [DATA_W-1:0] op_b,

   output [DATA_W-1:0] res
);

   // mantissa width, including the hidden bit
   localparam MAN_W = DATA_W - EXP_W;
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

   wire               div_valid_i = valid_i;
   wire               div_valid_o;
   wire               div_sign;
   wire [  EXP_W+1:0] div_exp;
   wire [MAN_W+EXTRA:0] div_man;
   wire [      2:0] div_res_special;
   fdiv_core #(
      .EXP_W        (EXP_W),
      .MAN_W        (DATA_W - EXP_W),
      .SPECIAL_CASES(SPECIAL_CASES)
   ) div0 (
      .clk(clk),
      .rst(rst),

      .valid_i(div_valid_i),
      .valid_o(div_valid_o),

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
      .res_special(div_res_special),

      .res_sign(div_sign),
      .res_exp (div_exp),
      .res_man (div_man)
   );
   wire [          2:0] res_special_int = div_res_special;

   wire [          2:0] norm_res_special;

   wire                   norm_sign;
   wire [        EXP_W:0] norm_exp;
   wire [MAN_W+EXTRA-1:0] norm_man;
   wire                   norm_valid_o;
   norm #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W),
      .IN_W  (MAN_W + EXTRA + 1),
      .LZC_W (2)
   ) norm0 (
      .clk(clk),
      .rst(rst),

      .valid_i(div_valid_o),
      .valid_o(norm_valid_o),

      .sign_i(div_sign),
      .exp_i (div_exp),
      .man_i (div_man),
      .res_special_i(res_special_int),
      .res_special_o(norm_res_special),

      .sign_o(norm_sign),
      .exp_o (norm_exp),
      .man_o (norm_man)
   );

   wire pack_valid_i = norm_valid_o;
   // Rounding mode, captured with valid_i for the whole division
   reg [2:0] rnd_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         rnd_reg <= 3'd0;
      end else if (valid_i) begin
         rnd_reg <= rnd_mode;
      end
   end

   pack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) pack0 (
      .clk(clk),
      .rst(rst),

      .valid_i(pack_valid_i),
      .valid_o(valid_o),
      .rnd_mode(rnd_reg),
      .res_special_i(norm_res_special),

      .sign_i(norm_sign),
      .exp_i (norm_exp),
      .man_i (norm_man),

      .data_o(res)
   );

endmodule
