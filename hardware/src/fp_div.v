`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_div #(
                parameter DATA_W = 32,
                parameter EXP_W = 8
                )
   (
    input                   clk,
    input                   rst,

    input                   start,
    output reg              done,

    input [DATA_W-1:0]      op_a,
    input [DATA_W-1:0]      op_b,

    output                  overflow,
    output                  underflow,
    output                  exception,

    output reg [DATA_W-1:0] res
    );

   localparam MAN_W = DATA_W-EXP_W;
   localparam BIAS = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;

   // Special cases
`ifdef SPECIAL_CASES
   wire                     op_a_nan, op_a_inf, op_a_zero, op_a_sub;
   fp_special #(
                .DATA_W(DATA_W),
                .EXP_W(EXP_W)
                )
   special_op_a
     (
      .data_in    (op_a),

      .nan        (op_a_nan),
      .infinite   (op_a_inf),
      .zero       (op_a_zero),
      .sub_normal (op_a_sub)
      );

   wire                     op_b_nan, op_b_inf, op_b_zero, op_b_sub;
   fp_special #(
                .DATA_W(DATA_W),
                .EXP_W(EXP_W)
                )
   special_op_b
     (
      .data_in    (op_b),

      .nan        (op_b_nan),
      .infinite   (op_b_inf),
      .zero       (op_b_zero),
      .sub_normal (op_b_sub)
      );

   wire                     special = op_a_nan | op_a_inf | op_b_nan | op_b_inf | op_b_zero;
   wire [DATA_W-1:0]        res_special = (op_a_nan | op_b_nan)? `NAN:
                                                       op_b_inf? (op_a_inf? `NAN: {DATA_W{1'b0}}):
                                         (op_a_inf & op_b_zero)? `NAN:
                                        (op_a_zero & op_b_zero)? `NAN:
                                                                 `INF(op_a[DATA_W-1] ^ op_b[DATA_W-1]);

   wire                     start_int = start & ~special;
`else
   wire                     start_int = start;
`endif

   // Unpack
   wire                     A_nsub = |op_a[DATA_W-2 -: EXP_W];
   wire                     B_nsub = |op_b[DATA_W-2 -: EXP_W];

   wire                     A_sub = ~A_nsub;
   wire                     B_sub = ~B_nsub;

   wire                     A_sign     = op_a[DATA_W-1];
   wire [EXP_W-1:0]         A_Exponent = {op_a[DATA_W-2 -: EXP_W-1], A_sub | op_a[DATA_W-EXP_W-1]};
   wire [MAN_W-1:0]         A_Mantissa = {A_nsub, op_a[MAN_W-2:0]};

   wire                     B_sign     = op_b[DATA_W-1];
   wire [EXP_W-1:0]         B_Exponent = {op_b[DATA_W-2 -: EXP_W-1], B_sub | op_b[DATA_W-EXP_W-1]};
   wire [MAN_W-1:0]         B_Mantissa = {B_nsub, op_b[MAN_W-2:0]};

   // pipeline stage 1
   reg                      A_sign_reg;
   reg [EXP_W-1:0]          A_Exponent_reg;
   reg [MAN_W-1:0]          A_Mantissa_reg;

   reg                      B_sign_reg;
   reg [EXP_W-1:0]          B_Exponent_reg;
   reg [MAN_W-1:0]          B_Mantissa_reg;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};

         B_sign_reg <= 1'b0;
         B_Exponent_reg <= {EXP_W{1'b0}};
         B_Mantissa_reg <= {MAN_W{1'b0}};
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         B_sign_reg <= B_sign;
         B_Exponent_reg <= B_Exponent;
         B_Mantissa_reg <= B_Mantissa;
      end
   end

   // Division
   wire                     Temp_sign = A_sign_reg ^ B_sign_reg;
   wire [EXP_W:0]           Temp_Exponent = {1'b0, A_Exponent_reg} - {1'b0, B_Exponent_reg} + BIAS;
   wire [2*MAN_W-1:0]       Temp_Mantissa; // = A_Mantissa_reg / B_Mantissa_reg;
   wire                     div_en = ~start_int & ~rst;
   wire                     div_done;
   div_subshift # (
                   .DATA_W(2*MAN_W)
                   )
   div_subshift (
                 .clk       (clk),

                 .en        (div_en),
                 .sign      (1'b0),
                 .done      (div_done),

                 .dividend  ({A_Mantissa, {MAN_W{1'b0}}}),
                 .divisor   ({{MAN_W{1'b0}}, B_Mantissa}),
                 .quotient  (Temp_Mantissa),
                 .remainder ()
                 );

   reg                      div_done_reg;
   wire                     done_int = div_done & ~div_done_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         div_done_reg <= 1'b1;
      end else begin
         div_done_reg <= div_done;
      end
   end

   // pipeline stage 2
   reg                      Temp_sign_reg;
   reg [EXP_W:0]            Temp_Exponent_reg;
   reg [2*MAN_W-1:0]        Temp_Mantissa_reg;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg <= 1'b0;
         Temp_Exponent_reg <= {(EXP_W+1){1'b0}};
         Temp_Mantissa_reg <= {(2*MAN_W){1'b0}};
      end else begin
         Temp_sign_reg <= Temp_sign;
         Temp_Exponent_reg <= Temp_Exponent;
         Temp_Mantissa_reg <= Temp_Mantissa;
      end
   end

   // Normalize
   localparam LSC_W = $clog2(2*MAN_W+1);
   localparam OFFSET = 24; // 24 -> 23 for the left shift and 1 for the 2's Complement

   wire [LSC_W-1:0]         lzc_int;
   clz #(
         .DATA_W(2*MAN_W)
         )
   clz0
     (
      .data_in  (Temp_Mantissa_reg),
      .data_out (lzc_int)
      );

   wire [LSC_W-1:0]         lzc = ({{(EXP_W+1-LSC_W){1'b0}}, lzc_int} > Temp_Exponent_reg)? Temp_Exponent_reg[LSC_W-1:0]: lzc_int;
   wire [LSC_W:0]           lzc_inv = ~{1'b0, lzc};

   wire [EXP_W:0]           exp_norm = Temp_Exponent_reg + {{(EXP_W-LSC_W){lzc_inv[LSC_W]}}, lzc_inv} + OFFSET;
   wire [2*MAN_W-1:0]       man_norm = Temp_Mantissa_reg << lzc;

   wire [EXP_W:0]           exp_adjust = exp_norm;
   wire [MAN_W+EXTRA-1:0]   man_adjust = {man_norm[2*MAN_W-1 -: MAN_W+EXTRA-1], |man_norm[MAN_W-EXTRA:0]};

   // pipeline stage 3
   reg                      Temp_sign_reg2;

   reg [EXP_W:0]            exp_adjust_reg;
   reg [MAN_W+EXTRA-1:0]    man_adjust_reg;
   always @(posedge clk) begin
      if (rst) begin
         Temp_sign_reg2 <= 1'b0;

         exp_adjust_reg <= {(EXP_W+1){1'b0}};
         man_adjust_reg <= {(MAN_W+EXTRA){1'b0}};
      end else begin
         Temp_sign_reg2 <= Temp_sign_reg;

         exp_adjust_reg <= exp_adjust;
         man_adjust_reg <= man_adjust;
      end
   end

   // Round
   wire [EXP_W-1:0]         exp_adjust_rnd;
   wire [MAN_W-1:0]         man_adjust_rnd;
   wire                     round;
   round #(
           .DATA_W (MAN_W),
           .EXP_W  (EXP_W)
           )
   round0
     (
      .exponent     (exp_adjust_reg),
      .mantissa     (man_adjust_reg),
      .cin          (1'b0),

      .exponent_rnd (exp_adjust_rnd),
      .mantissa_rnd (man_adjust_rnd),
      .round        (round)
      );

   wire                     nzero = |man_adjust_reg[MAN_W+EXTRA-1:3] | round;

   // Pack
   wire [MAN_W-2:0]         Fraction = man_adjust_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]         Exponent = man_adjust_rnd[MAN_W-1]? exp_adjust_rnd: {EXP_W{1'b0}};
   wire                     Sign     = nzero & Temp_sign_reg2;

`ifdef SPECIAL_CASES
   wire [DATA_W-1:0]        res_in  = special? res_special: {Sign, Exponent, Fraction};
   wire                     done_in = special? start: done_int;
`else
   wire [DATA_W-1:0]        res_in  = {Sign, Exponent, Fraction};
   wire                     done_in = done_int;
`endif

   // pipeline stage 4
   always @(posedge clk) begin
      if (rst) begin
         res <= {DATA_W{1'b0}};
         done <= 1'b0;
      end else begin
         res <= res_in;
         done <= done_in;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
