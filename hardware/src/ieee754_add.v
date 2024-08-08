`timescale 1ns / 1ps

module ieee754_add
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

   localparam MAN_W = DATA_W-EXP_W;
   localparam EXTRA = 3;

   wire                 op_a_sign;
   wire [EXP_W-1:0]     op_a_exp;
   wire [MAN_W-1:0]     op_a_man;
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
   wire [MAN_W-1:0]     op_b_man;
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

   wire                 start_add;
   wire                 done_add;
   wire                 add_sign;
   wire [EXP_W-1:0]     add_exp;
   wire [MAN_W+EXTRA:0] add_man;
   wire                 add_inv;
   wire [EXP_W-1:0]     add_offset;
`ifdef SPECIAL_CASES
   wire                 add_special;
   wire [DATA_W-1:0]    add_res_special;
`endif
   assign start_add = done_unpack0;
   fp_add
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   add0
       (
        .clk         (clk),
        .rst         (rst),

        .start       (start_add),
        .done        (done_add),

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

        .special     (add_special),
        .res_special (add_res_special),
`endif

        .res_sign    (add_sign),
        .res_exp     (add_exp),
        .res_man     (add_man),
        .res_inv     (add_inv),
        .offset      (add_offset)
        );

`ifdef SPECIAL_CASES
   wire                 special_int = add_special;
   wire [DATA_W-1:0]    res_special_int = add_res_special;
`endif

   wire                 start_norm;
   wire                 done_norm;
   wire                 norm_sign;
   wire [EXP_W+1:0]     norm_exp;
   wire [MAN_W+EXTRA-1:0] norm_man;
   wire                   norm_inv;
   assign start_norm = done_add;
   norm
     #(
       .DATA_W (DATA_W),
       .EXP_W  (EXP_W)
       )
   norm0
       (
        .clk      (clk),
        .rst      (rst),
   
        .start    (start_norm),
        .done     (done_norm),

        .sign_i   (add_sign),
        .exp_i    ({2'd0, add_exp}),
        .man_i    ({add_man, {(MAN_W-EXTRA-1){1'b0}}}),
        .inv_i    (add_inv),
        .offset   ({2'd0, add_offset}),

        .sign_o   (norm_sign),
        .exp_o    (norm_exp),
        .man_o    (norm_man),
        .inv_o    (norm_inv)
        );

   wire                start_pack;
   wire [DATA_W-1:0]   res_int;
   assign start_pack = done_norm;
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

   reg                 special, norm_special;
   reg [DATA_W-1:0]    res_special, norm_res_special;
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
