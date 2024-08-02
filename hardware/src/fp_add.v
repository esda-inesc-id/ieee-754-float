`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_add #(
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

   wire                     special = op_a_nan | op_a_inf | op_b_nan | op_b_inf;
   wire [DATA_W-1:0]        res_special = (op_a_nan | op_b_nan)? `NAN:
                                          (op_a_inf & op_b_inf)? ((op_a[DATA_W-1] ^ op_b[DATA_W-1])? `NAN:
                                                                                                     `INF(op_a[DATA_W-1])):
                                                       op_b_inf? `INF(op_b[DATA_W-1]):
                                                                 `INF(op_a[DATA_W-1]);

   wire                     start_int = start & ~special;
`else
   wire                     start_int = start;
`endif

   // Unpack
   wire                     A_nsub = |op_a[DATA_W-2 -: EXP_W];
   wire                     B_nsub = |op_b[DATA_W-2 -: EXP_W];

   wire                     A_sub = ~A_nsub;
   wire                     B_sub = ~B_nsub;

   wire [EXP_W-1:0]         A_exp = {op_a[DATA_W-2 -: EXP_W-1], A_sub | op_a[DATA_W-EXP_W-1]};
   wire [EXP_W-1:0]         B_exp = {op_b[DATA_W-2 -: EXP_W-1], B_sub | op_b[DATA_W-EXP_W-1]};

   wire [MAN_W-1:0]         A_man = {A_nsub, op_a[MAN_W-2:0]};
   wire [MAN_W-1:0]         B_man = {B_nsub, op_b[MAN_W-2:0]};

   wire                     comp = (A_exp >= B_exp)? 1'b1 : 1'b0;

   wire                     A_sign     = comp? op_a[DATA_W-1]: op_b[DATA_W-1];
   wire [EXP_W-1:0]         A_Exponent = comp? A_exp: B_exp;
   wire [MAN_W-1:0]         A_Mantissa = comp? A_man: B_man;

   wire                     B_sign     = comp? op_b[DATA_W-1]: op_a[DATA_W-1];
   wire [EXP_W-1:0]         B_Exponent = comp? B_exp: A_exp;
   wire [MAN_W-1:0]         B_Mantissa = comp? B_man: A_man;

   // pipeline stage 1
   reg                      A_sign_reg;
   reg [EXP_W-1:0]          A_Exponent_reg;
   reg [MAN_W-1:0]          A_Mantissa_reg;

   reg                      B_sign_reg;
   reg [EXP_W-1:0]          B_Exponent_reg;
   reg [MAN_W-1:0]          B_Mantissa_reg;

   reg                      done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};

         B_sign_reg <= 1'b0;
         B_Exponent_reg <= {EXP_W{1'b0}};
         B_Mantissa_reg <= {MAN_W{1'b0}};

         done_int <= 1'b0;
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         B_sign_reg <= B_sign;
         B_Exponent_reg <= B_Exponent;
         B_Mantissa_reg <= B_Mantissa;

         done_int <= start_int;
      end
   end

   localparam STICKY_BITS = MAN_W+2;

   // Align significants
   wire [EXP_W-1:0]         diff_Exponent = A_Exponent_reg - B_Exponent_reg;
   wire [EXP_W-1:0]         rshift = (diff_Exponent > STICKY_BITS)? STICKY_BITS: diff_Exponent;
   wire [MAN_W+STICKY_BITS-1:0] B_Mantissa_in = {B_Mantissa_reg, {STICKY_BITS{1'b0}}} >> rshift;

   // Sticky
   wire                     sticky_bit = |B_Mantissa_in[STICKY_BITS-3:0];

   // Invert OpA if subtraction
   wire                     subtract = A_sign_reg ^ B_sign_reg;
   wire [MAN_W+EXTRA-1:0]   A_Mantissa_inv = {(MAN_W+EXTRA){subtract}} ^ {A_Mantissa_reg, {EXTRA{1'b0}}};

   // pipeline stage 2
   reg                      A_sign_reg2;
   reg [EXP_W-1:0]          A_Exponent_reg2;
   reg [MAN_W+EXTRA-1:0]    A_Mantissa_reg2;

   reg [MAN_W+EXTRA-1:0]    B_Mantissa_reg2;

   reg                      subtract_reg;

   reg                      done_int2;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg2 <= 1'b0;
         A_Exponent_reg2 <= {EXP_W{1'b0}};
         A_Mantissa_reg2 <= {(MAN_W+EXTRA){1'b0}};

         B_Mantissa_reg2 <= {(MAN_W+EXTRA){1'b0}};

         subtract_reg <= 1'b0;

         done_int2 <= 1'b0;
      end else begin
         A_sign_reg2 <= A_sign_reg;
         A_Exponent_reg2 <= A_Exponent_reg;
         A_Mantissa_reg2 <= A_Mantissa_inv;

         B_Mantissa_reg2 <= {B_Mantissa_in[STICKY_BITS-2 +: MAN_W+EXTRA-1], sticky_bit};

         subtract_reg <= subtract;

         done_int2 <= done_int;
      end
   end

   // Addition
   wire [MAN_W+EXTRA:0]     Temp = {subtract_reg, A_Mantissa_reg2} + {1'b0, B_Mantissa_reg2} + {{(MAN_W+EXTRA){1'b0}}, subtract_reg};

   // pipeline stage 3
   reg                      A_sign_reg3;
   reg [EXP_W-1:0]          A_Exponent_reg3;

   reg [MAN_W+EXTRA:0]      Temp_reg;

   reg                      subtract_reg2;

   reg                      done_int3;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg3 <= 1'b0;
         A_Exponent_reg3 <= {EXP_W{1'b0}};

         Temp_reg <= {(MAN_W+EXTRA+1){1'b0}};

         subtract_reg2 <= 1'b0;

         done_int3 <= 1'b0;
      end else begin
         A_sign_reg3 <= A_sign_reg2;
         A_Exponent_reg3 <= A_Exponent_reg2;

         Temp_reg <= Temp;

         subtract_reg2 <= subtract_reg;

         done_int3 <= done_int2;
      end
   end

   // Compute result sign
   wire                     res_sign = subtract_reg2? ~A_sign_reg3 ^ Temp_reg[MAN_W+EXTRA]: A_sign_reg3;
   wire                     res_inv  = subtract_reg2 & Temp_reg[MAN_W+EXTRA];

   // Normalize
   localparam LSC_W  = $clog2(MAN_W+EXTRA+2);
   localparam OFFSET = 2; // 2 -> 1 for the carry from the adder and 1 for the 2's Complement

   wire [LSC_W-1:0]         lsc_int;
   cls #(
         .DATA_W(MAN_W+EXTRA+1)
         )
   cls0
     (
      .data_in  (Temp_reg),
      .symbol   (res_inv),
      .data_out (lsc_int)
      );

   wire [LSC_W-1:0]         lsc = ({{(EXP_W-LSC_W){1'b0}}, lsc_int} > A_Exponent_reg3)? A_Exponent_reg3[LSC_W-1:0]: lsc_int;
   wire [LSC_W:0]           lsc_inv = ~{1'b0, lsc};

   wire [EXP_W:0]           exp_norm = {1'b0, A_Exponent_reg3} + {{(EXP_W-LSC_W){lsc_inv[LSC_W]}}, lsc_inv} + OFFSET;
   wire [MAN_W+EXTRA:0]     man_norm = Temp_reg << lsc;

   wire [EXP_W:0]           exp_adjust = exp_norm;
   wire [MAN_W+EXTRA-1:0]   man_adjust = {man_norm[MAN_W+EXTRA:2], |man_norm[1:0]};

   // pipeline stage 4
   reg                      res_sign_reg;

   reg                      res_inv_reg;

   reg [EXP_W:0]            exp_adjust_reg;
   reg [MAN_W+EXTRA-1:0]    man_adjust_reg;

   reg                      done_int4;
   always @(posedge clk) begin
      if (rst) begin
         res_sign_reg <= 1'b0;

         res_inv_reg <= 1'b0;

         exp_adjust_reg <= {(EXP_W+1){1'b0}};
         man_adjust_reg <= {(MAN_W+EXTRA){1'b0}};

         done_int4 <= 1'b0;
      end else begin
         res_sign_reg <= res_sign;

         res_inv_reg <= res_inv;

         exp_adjust_reg <= exp_adjust;
         man_adjust_reg <= man_adjust;

         done_int4 <= done_int3;
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
      .exponent_i (exp_adjust_reg),
      .mantissa_i (man_adjust_reg),
      .cin        (res_inv_reg),

      .exponent_o (exp_adjust_rnd),
      .mantissa_o (man_adjust_rnd),
      .round      (round)
      );

   wire                     nzero = |man_adjust_reg[MAN_W+EXTRA-1:3] | round;

   // Pack
   wire [MAN_W-2:0]         Fraction = man_adjust_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]         Exponent = man_adjust_rnd[MAN_W-1]? exp_adjust_rnd: {EXP_W{1'b0}};
   wire                     Sign     = nzero & res_sign_reg;

`ifdef SPECIAL_CASES
   wire [DATA_W-1:0]        res_in  = special? res_special: {Sign, Exponent, Fraction};
   wire                     done_in = special? start: done_int4;
`else
   wire [DATA_W-1:0]        res_in  = {Sign, Exponent, Fraction};
   wire                     done_in = done_int4;
`endif

   // pipeline stage 5
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
