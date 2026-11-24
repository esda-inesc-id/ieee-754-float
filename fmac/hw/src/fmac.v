`timescale 1ns / 1ps

module fmac #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter SPECIAL_CASES = 1,
   parameter LGUARD_W      = 0,
   parameter RGUARD_W      = 0
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

   // rounding mode, sampled with the last product of a stream; see round.v for the encoding
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

   wire                   mac_valid_i = valid_i;
   wire                   mac_valid_o;
   wire                   mac_sign;
   wire [      EXP_W+1:0] mac_exp;
   wire [MAN_W+EXTRA-1:0] mac_man;
   wire                   mac_inv;
   wire                   mac_special;
   wire [     DATA_W-1:0] mac_res_special;
   fmac_core #(
      .DATA_W       (DATA_W),
      .EXP_W        (EXP_W),
      .SPECIAL_CASES(SPECIAL_CASES),
      .LGUARD_W     (LGUARD_W),
      .RGUARD_W     (RGUARD_W)
   ) mac0 (
      .clk(clk),
      .rst(rst),

      .valid_i(mac_valid_i),
      .valid_o(mac_valid_o),

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

      .special    (mac_special),
      .res_special(mac_res_special),

      .res_sign(mac_sign),
      .res_exp (mac_exp),
      .res_man (mac_man),
      .res_inv (mac_inv)
   );

   wire pack_valid_i = mac_valid_o;
   // Rounding mode, delayed to the pack input (mac, from the last product)
   localparam RND_DLY = 7;
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
      .EXP_W (EXP_W)
   ) pack0 (
      .clk(clk),
      .rst(rst),

      .valid_i(pack_valid_i),
      .valid_o(valid_o),

      .inv (mac_inv),
      .nsub(1'b0),
      .rnd_mode(pack_rnd_mode),

      .special_i    (mac_special),
      .res_special_i(mac_res_special),

      .sign_i(mac_sign),
      .exp_i (mac_exp),
      .man_i (mac_man),

      .data_o(res)
   );

endmodule
