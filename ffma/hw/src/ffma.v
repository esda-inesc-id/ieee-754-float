`timescale 1ns / 1ps

module ffma #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

   // rounding mode, sampled with the operands; see round.v for the encoding
   input [2:0] rnd_mode,

   // res = op_a * op_b + op_c, rounded once
   input [DATA_W-1:0] op_a,
   input [DATA_W-1:0] op_b,
   input [DATA_W-1:0] op_c,

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

   wire             op_c_sign;
   wire [EXP_W-1:0] op_c_exp;
   wire [MAN_W-1:0] op_c_man;
   wire             op_c_nan;
   wire             op_c_inf;
   wire             op_c_zero;
   unpack #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) unpack2 (
      .data_i(op_c),

      .nan     (op_c_nan),
      .infinite(op_c_inf),
      .zero    (op_c_zero),

      .sign    (op_c_sign),
      .exponent(op_c_exp),
      .mantissa(op_c_man)
   );

   wire                   fma_valid_i = valid_i;
   wire                   fma_valid_o;
   wire                   fma_sign;
   wire [        EXP_W:0] fma_exp;
   wire [MAN_W+EXTRA-1:0] fma_man;
   wire [          2:0] fma_res_special;
   ffma_core #(
      .DATA_W       (DATA_W),
      .EXP_W        (EXP_W),
      .SPECIAL_CASES(SPECIAL_CASES)
   ) fma0 (
      .clk(clk),
      .rst(rst),

      .valid_i(fma_valid_i),
      .valid_o(fma_valid_o),

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

      .op_c_sign(op_c_sign),
      .op_c_exp (op_c_exp),
      .op_c_man (op_c_man),
      .op_c_nan (op_c_nan),
      .op_c_inf (op_c_inf),
      .op_c_zero(op_c_zero),
      .res_special(fma_res_special),

      .res_sign(fma_sign),
      .res_exp (fma_exp),
      .res_man (fma_man)
   );

   wire pack_valid_i = fma_valid_o;
   // Rounding mode, delayed to the pack input
   localparam RND_DLY = 5;
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
      .INV   (1)
   ) pack0 (
      .clk(clk),
      .rst(rst),

      .valid_i(pack_valid_i),
      .valid_o(valid_o),
      .rnd_mode(pack_rnd_mode),
      .res_special_i(fma_res_special),

      .sign_i(fma_sign),
      .exp_i (fma_exp),
      .man_i (fma_man),

      .data_o(res)
   );

endmodule
