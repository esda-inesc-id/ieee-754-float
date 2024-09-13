`timescale 1ns / 1ps

`include "ieee754_defs.vh"

module ieee754_mac
  #(
    parameter DATA_W = 32,
    parameter EXP_W = 8,
    parameter GUARD_W = 0
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
`ifdef SPECIAL_CASES
   wire                 op_a_nan;
   wire                 op_a_inf;
   wire                 op_a_zero;
`endif
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
`ifdef SPECIAL_CASES
   wire                 op_b_nan;
   wire                 op_b_inf;
   wire                 op_b_zero;
`endif
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

   wire                 start_mac = done_unpack0;
   wire                 done_mac;
   wire                 mac_sign;
   wire [EXP_W+1:0]     mac_exp;
   wire [`MAN_W+`EXTRA-1:0] mac_man;
   wire                     mac_inv;
   fp_mac
     #(
       .DATA_W  (DATA_W),
       .EXP_W   (EXP_W),
       .GUARD_W (GUARD_W)
       )
   mac0
       (
        .clk         (clk),
        .rst         (rst),

        .start       (start_mac),
        .done        (done_mac),

        .op_a_sign   (op_a_sign),
        .op_a_exp    (op_a_exp),
        .op_a_man    (op_a_man),

        .op_b_sign   (op_b_sign),
        .op_b_exp    (op_b_exp),
        .op_b_man    (op_b_man),

        .res_sign    (mac_sign),
        .res_exp     (mac_exp),
        .res_man     (mac_man),
        .res_inv     (mac_inv)
        );

   wire                     start_pack = done_mac;
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

        .inv      (mac_inv),
        .nsub     (1'b0),

        .sign_i   (mac_sign),
        .exp_i    (mac_exp),
        .man_i    (mac_man),

        .data_o   (res)
        );

endmodule
