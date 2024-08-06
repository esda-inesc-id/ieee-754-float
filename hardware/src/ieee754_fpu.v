`timescale 1ns / 1ps

`include "fp_defs.vh"

module ieee754_fpu
  #(
    parameter DATA_W = 32,
    parameter EXP_W = 8
    )
   (
    input               clk,
    input               rst,

    input               start,
    input [FUNCT_W-1:0] funct,
    output              done,

    input [DATA_W-1:0]  op_a,
    input [DATA_W-1:0]  op_b,

    output [DATA_W-1:0] res
    );

   localparam MAN_W = DATA_W-EXP_W;

   wire                 op_a_sign;
   wire [EXP_W-1:0]     op_a_exp;
   wire [MAN_W-1:0]     op_a_man;
   ieee754_unpack
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   unpack0
       (
        .clk    (clk),
        .rst    (rst),
   
        .start  (start),
        .data_i (op_a),
   
        .sign_o (op_a_sign),
        .exp_o  (op_a_exp),
        .man_o  (op_a_man)
        );

   wire                 op_b_sign;
   wire [EXP_W-1:0]     op_b_exp;
   wire [MAN_W-1:0]     op_b_man;
   ieee754_unpack
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   unpack1
       (
        .clk    (clk),
        .rst    (rst),
   
        .start  (start),
        .data_i (op_b),
   
        .sign_o (op_b_sign),
        .exp_o  (op_b_exp),
        .man_o  (op_b_man)
        );

   

endmodule
