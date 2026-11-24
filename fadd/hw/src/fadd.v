`timescale 1ns / 1ps

module fadd #(
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

   wire                 add_valid_i = valid_i;
   wire                 add_valid_o;
   wire                 add_sign;
   wire [    EXP_W-1:0] add_exp;
   wire [MAN_W+EXTRA:0] add_man;
   wire [        2:0] add_res_special;
   fadd_core #(
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
      .op_a_zero(op_a_zero),

      .op_b_sign(op_b_sign),
      .op_b_exp (op_b_exp),
      .op_b_man (op_b_man),

      .op_b_nan(op_b_nan),
      .op_b_inf(op_b_inf),
      .op_b_zero(op_b_zero),
      .res_special(add_res_special),

      .res_sign(add_sign),
      .res_exp (add_exp),
      .res_man (add_man)
   );
   wire [          2:0] res_special_int = add_res_special;

   wire                   norm_valid_i = add_valid_o;
   wire                   norm_valid_o;
   wire [          2:0] norm_res_special;
   wire                   norm_sign;
   wire [      EXP_W-1:0] norm_exp;
   wire [MAN_W+EXTRA-1:0] norm_man;
   norm #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W),
      .IN_W  (MAN_W + EXTRA + 1),
      .RSHIFT(0)
   ) norm0 (
      .clk(clk),
      .rst(rst),

      .valid_i(norm_valid_i),
      .valid_o(norm_valid_o),

      .sign_i(add_sign),
      .exp_i (add_exp),
      .man_i (add_man),
      .res_special_i(res_special_int),
      .res_special_o(norm_res_special),

      .sign_o(norm_sign),
      .exp_o (norm_exp),
      .man_o (norm_man)
   );

   wire pack_valid_i = norm_valid_o;
   // Rounding mode, delayed to the pack input (add and norm)
   localparam RND_DLY = 4;
   reg [3*RND_DLY-1:0] rnd_pipe;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         rnd_pipe <= {(3 * RND_DLY) {1'b0}};
      end else begin
         rnd_pipe <= {rnd_pipe[3*RND_DLY-4:0], rnd_mode};
      end
   end
   wire [2:0] pack_rnd_mode = rnd_pipe[3*RND_DLY-1-:3];

   pack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W),
      .EXP_I_W(EXP_W)
   ) pack0 (
      .clk(clk),
      .rst(rst),

      .valid_i(pack_valid_i),
      .valid_o(valid_o),
      .rnd_mode(pack_rnd_mode),
      .res_special_i(norm_res_special),

      .sign_i(norm_sign),
      .exp_i (norm_exp),
      .man_i (norm_man),

      .data_o(res)
   );

endmodule
