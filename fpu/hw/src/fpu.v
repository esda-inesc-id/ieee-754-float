`timescale 1ns / 1ps

module fpu #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter MAN_W         = DATA_W - EXP_W,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

   input [1:0] funct,

   input [DATA_W-1:0] op_a,
   input [DATA_W-1:0] op_b,

   output [DATA_W-1:0] res
);

   localparam EXTRA = 3;

   wire             add = ~funct[1];
   wire             mul = funct[1] & ~funct[0];
   wire             div = funct[1] & funct[0];

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

   wire                 add_valid_i = valid_i & add;
   wire                 add_valid_o;
   wire                 op_b_sign_int = op_b_sign ^ funct[0];
   wire                 add_sign;
   wire [    EXP_W-1:0] add_exp;
   wire [MAN_W+EXTRA:0] add_man;
   wire                 add_inv;
   wire                 add_nsub;
   wire                 add_special;
   wire [   DATA_W-1:0] add_res_special;
   add #(
      .DATA_W       (DATA_W),
      .EXP_W        (EXP_W),
      .SPECIAL_CASES(SPECIAL_CASES)
   ) add0 (
      .clk(clk),
      .rst(rst),

      .valid_i(add_valid_i),
      .valid_o(add_valid_o),

      .op_a_sign(op_a_sign),
      .op_a_exp (op_a_exp),
      .op_a_man (op_a_man),

      .op_a_nan(op_a_nan),
      .op_a_inf(op_a_inf),

      .op_b_sign(op_b_sign_int),
      .op_b_exp (op_b_exp),
      .op_b_man (op_b_man),

      .op_b_nan(op_b_nan),
      .op_b_inf(op_b_inf),

      .special    (add_special),
      .res_special(add_res_special),

      .res_sign(add_sign),
      .res_exp (add_exp),
      .res_man (add_man),
      .res_inv (add_inv),
      .res_nsub(add_nsub)
   );

   wire               mul_valid_i = valid_i & mul;
   wire               mul_valid_o;
   wire               mul_sign;
   wire [  EXP_W+1:0] mul_exp;
   wire [2*MAN_W-1:0] mul_man;
   wire               mul_special;
   wire [ DATA_W-1:0] mul_res_special;
   mul #(
      .DATA_W       (DATA_W),
      .EXP_W        (EXP_W),
      .SPECIAL_CASES(SPECIAL_CASES),
      .OUT_REG      (1)
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

   wire               div_valid_i = valid_i & div;
   wire               div_valid_o;
   wire               div_sign;
   wire [  EXP_W+1:0] div_exp;
   wire [MAN_W+EXTRA+1:0] div_man;
   wire               div_special;
   wire [ DATA_W-1:0] div_res_special;
   div #(
      .DATA_W       (DATA_W),
      .EXP_W        (EXP_W),
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

      .special    (div_special),
      .res_special(div_res_special),

      .res_sign(div_sign),
      .res_exp (div_exp),
      .res_man (div_man)
   );

   // add and mul have equal latency, so at most one has a result in each cycle
   wire add_sel = add_valid_o;
   wire mul_sel = mul_valid_o;

   wire special_int = add_sel ? add_special : mul_sel ? mul_special : div_special;
   wire [DATA_W-1:0] res_special_int = add_sel ? add_res_special :
      mul_sel ? mul_res_special :
      div_res_special;

   wire norm_valid_o;
   wire norm_valid_i = add_valid_o | mul_valid_o;

   wire op_sign = add_sel ? add_sign : mul_sel ? mul_sign : div_sign;

   wire [EXP_W+1:0] op_exp = add_sel ? {2'd0, add_exp} : mul_sel ? mul_exp : div_exp;

   wire [2*MAN_W-1:0] op_man = add_sel ? {add_man, {(MAN_W-EXTRA-1){1'b0}}} :
      mul_sel ? mul_man :
      {div_man, {(MAN_W-EXTRA-2){1'b0}}};

   wire op_inv = add_sel ? add_inv : 1'b0;

   wire op_nsub = add_sel ? add_nsub : 1'b1;

   wire norm_special;

   wire [DATA_W-1:0] norm_res_special;

   wire norm_sign;
   wire [EXP_W+1:0] norm_exp;
   wire [MAN_W+EXTRA-1:0] norm_man;
   wire norm_inv;
   wire norm_nsub;
   norm #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) norm0 (
      .clk(clk),
      .rst(rst),

      .valid_i(norm_valid_i),
      .valid_o(norm_valid_o),

      .sign_i(op_sign),
      .exp_i (op_exp),
      .man_i (op_man),
      .inv_i (op_inv),
      .nsub_i(op_nsub),

      .special_i    (special_int),
      .res_special_i(res_special_int),
      .special_o    (norm_special),
      .res_special_o(norm_res_special),

      .sign_o(norm_sign),
      .exp_o (norm_exp),
      .man_o (norm_man),
      .inv_o (norm_inv),
      .nsub_o(norm_nsub)
   );

   wire pack_valid_i = norm_valid_o | div_valid_o;
   pack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) pack0 (
      .clk(clk),
      .rst(rst),

      .valid_i(pack_valid_i),
      .valid_o(valid_o),

      .inv (norm_inv),
      .nsub(norm_nsub),

      .special_i    (norm_special),
      .res_special_i(norm_res_special),

      .sign_i(norm_sign),
      .exp_i (norm_exp),
      .man_i (norm_man),

      .data_o(res)
   );

endmodule
