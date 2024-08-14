`timescale 1ns / 1ps

`include "ieee754_defs.vh"

module ieee754_div
  #(
    parameter DATA_W = 32,
    parameter EXP_W = 8
    )
   (
    input               clk,
    input               rst,

    input               start,
    output              done,

    input [DATA_W-1:0]  op_a,
    input [DATA_W-1:0]  op_b,

    output [DATA_W-1:0] res
    );

   wire                 op_a_sign;
   wire [EXP_W-1:0]     op_a_exp;
   wire [`MAN_W-1:0]    op_a_man;
   wire                 op_a_nan;
   wire                 op_a_inf;
   wire                 op_a_zero;
   wire                 done_unpack0;
   ieee754_unpack
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   unpack0
       (
        .clk      (clk),
        .rst      (rst),
   
        .start    (start),
        .done     (done_unpack0),

        .data_i   (op_a),

`ifdef SPECIAL_CASES
        .nan      (op_a_nan),
        .infinite (op_a_inf),
        .zero     (op_a_zero),
`endif
   
        .sign     (op_a_sign),
        .exponent (op_a_exp),
        .mantissa (op_a_man)
        );

   wire                 op_b_sign;
   wire [EXP_W-1:0]     op_b_exp;
   wire [`MAN_W-1:0]    op_b_man;
   wire                 op_b_nan;
   wire                 op_b_inf;
   wire                 op_b_zero;
   wire                 done_unpack1;
   ieee754_unpack
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   unpack1
       (
        .clk      (clk),
        .rst      (rst),
   
        .start    (start),
        .done     (done_unpack1),

        .data_i   (op_b),

`ifdef SPECIAL_CASES
        .nan      (op_b_nan),
        .infinite (op_b_inf),
        .zero     (op_b_zero),
`endif
   
        .sign     (op_b_sign),
        .exponent (op_b_exp),
        .mantissa (op_b_man)
        );

   wire                 start_div = done_unpack0;
   wire                 done_div;
   wire                 div_sign;
   wire [EXP_W+1:0]     div_exp;
   wire [2*`MAN_W-1:0]  div_man;
   wire [EXP_W+1:0]     div_offset;
`ifdef SPECIAL_CASES
   wire                 div_special;
   wire [DATA_W-1:0]    div_res_special;
`endif
   fp_div
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   div0
       (
        .clk         (clk),
        .rst         (rst),

        .start       (start_div),
        .done        (done_div),

        .op_a_sign   (op_a_sign),
        .op_a_exp    (op_a_exp),
        .op_a_man    (op_a_man),

`ifdef SPECIAL_CASES
        .op_a_nan    (op_a_nan),
        .op_a_inf    (op_a_inf),
        .op_a_zero   (op_a_zero),
`endif

        .op_b_sign   (op_b_sign),
        .op_b_exp    (op_b_exp),
        .op_b_man    (op_b_man),

`ifdef SPECIAL_CASES
        .op_b_nan    (op_b_nan),
        .op_b_inf    (op_b_inf),
        .op_b_zero   (op_b_zero),

        .special     (div_special),
        .res_special (div_res_special),
`endif

        .res_sign    (div_sign),
        .res_exp     (div_exp),
        .res_man     (div_man),
        .offset      (div_offset)
        );

`ifdef SPECIAL_CASES
   wire                 special_int = div_special;
   wire [DATA_W-1:0]    res_special_int = div_res_special;
`endif

   wire                 norm_sign;
   wire [EXP_W+1:0]     norm_exp;
   wire [`MAN_W+`EXTRA-1:0] norm_man;
   wire                     norm_inv;
   norm
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   norm0
       (
        .clk      (clk),
        .rst      (rst),
   
        .start    (),
        .done     (),

        .sign_i   (div_sign),
        .exp_i    (div_exp),
        .man_i    (div_man),
        .inv_i    (1'b0),
        .offset   (div_offset),

        .sign_o   (norm_sign),
        .exp_o    (norm_exp),
        .man_o    (norm_man),
        .inv_o    (norm_inv)
        );

   wire                     start_pack = done_div;
   wire [DATA_W-1:0]        res_int;
   ieee754_pack
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   pack0
       (
        .clk      (clk),
        .rst      (rst),
   
        .start    (start_pack),
        .done     (done),

        .inv      (norm_inv),

        .sign_i   (norm_sign),
        .exp_i    (norm_exp),
        .man_i    (norm_man),

        .data_o   (res_int)
        );

   reg                      special, norm_special;
   reg [DATA_W-1:0]         res_special, norm_res_special;
   always @(posedge clk) begin
      if (rst) begin
         norm_special <= 1'b0;
         special <= 1'b0;

         norm_res_special <= {DATA_W{1'b0}};
         res_special <= {DATA_W{1'b0}};
      end else begin
         norm_special <= special_int;
         special <= norm_special;

         norm_res_special <= res_special_int;
         res_special <= norm_res_special;
      end
   end

   assign res = special? res_special: res_int;

endmodule
