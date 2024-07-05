`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_mac #(
                parameter DATA_W = 32,
                parameter EXP_W = 8,
                parameter GUARD_W = 0
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
                                          (op_a_inf & op_b_inf)? `NAN:
                                        (op_a_zero | op_b_zero)? `NAN:
                                                                 `INF(op_b[DATA_W-1] ^ op_b[DATA_W-1]);

   wire                     start_int = start & ~special;
`else
   wire                     start_int = start;
`endif

   // Unpack
   wire                     A_sub = ~|op_a[DATA_W-2 -: EXP_W];
   wire                     B_sub = ~|op_b[DATA_W-2 -: EXP_W];

   wire                     A_sign     = op_a[DATA_W-1];
   wire [EXP_W-1:0]         A_Exponent = {op_a[DATA_W-2 -: EXP_W-1], A_sub | op_a[DATA_W-EXP_W-1]};
   wire [MAN_W-1:0]         A_Mantissa = {~A_sub, op_a[MAN_W-2:0]};

   wire                     B_sign     = op_b[DATA_W-1];
   wire [EXP_W-1:0]         B_Exponent = {op_b[DATA_W-2 -: EXP_W-1], B_sub | op_b[DATA_W-EXP_W-1]};
   wire [MAN_W-1:0]         B_Mantissa = {~B_sub, op_b[MAN_W-2:0]};

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

   // Multiplication
   wire                     mul_sign = A_sign_reg ^ B_sign_reg;
   wire [EXP_W-1:0]         mul_exp  = A_Exponent_reg + B_Exponent_reg - BIAS;
   wire [2*MAN_W-1:0]       mul_man  = A_Mantissa_reg * B_Mantissa_reg;

   // pipeline stage 2
   reg                      mul_sign_reg;
   reg [EXP_W-1:0]          mul_exp_reg;
   reg [2*MAN_W-1:0]        mul_man_reg;

   reg                      done_int2;
   always @(posedge clk) begin
      if (rst) begin
         mul_sign_reg <= 1'b0;
         mul_exp_reg  <= {EXP_W{1'b0}};
         mul_man_reg  <= {(2*MAN_W){1'b0}};

         done_int2 <= 1'b0;
      end else begin
         mul_sign_reg <= mul_sign;
         mul_exp_reg  <= mul_exp;
         mul_man_reg  <= mul_man;

         done_int2 <= done_int;
      end
   end

   localparam ACC_W = 2*MAN_W+GUARD_W;
   localparam STICKY_BITS = 2*BIAS-1;

   // Accumulation in 2's Complement
   wire [EXP_W-1:0]         A_exp_int  = mul_exp_reg;
   wire [2*MAN_W-1:0]       A_man_int_ = (mul_man_reg ^ {(2*MAN_W){mul_sign_reg}}) + mul_sign_reg;
   wire [ACC_W-1:0]         A_man_int  = {{GUARD_W{A_man_int[2*MAN_W-1]}}, A_man_int};

   wire [EXP_W-1:0]         B_exp_int = acc_exp_reg;
   wire [ACC_W-1:0]         B_man_int = acc_man_reg;

   wire                     comp = (A_exp_int >= B_exp_int)? 1'b1 : 1'b0;

   wire [EXP_W-1:0]         A_exp = comp? A_exp_int: B_exp_int;
   wire [ACC_W-1:0]         A_man = comp? A_man_int: B_man_int;

   wire [EXP_W-1:0]         B_exp = comp? B_exp_int: A_exp_int;
   wire [ACC_W-1:0]         B_man = comp? B_man_int: A_man_int;

   // pipeline stage 3
   reg [EXP_W-1:0]          A_exp_reg;
   reg [ACC_W-1:0]          A_man_reg;

   reg [EXP_W-1:0]          B_exp_reg;
   reg [ACC_W-1:0]          B_man_reg;

   reg                      done_int3;
   always @(posedge clk) begin
      if (rst) begin
         A_exp_reg <= {EXP_W{1'b0}};
         A_man_reg <= {ACC_W{1'b0}};

         B_exp_reg <= {EXP_W{1'b0}};
         B_man_reg <= {ACC_W{1'b0}};

         done_int3 <= 1'b0;
      end else begin
         A_exp_reg <= A_exp;
         A_man_reg <= A_man;

         B_exp_reg <= B_exp;
         B_man_reg <= B_man;

         done_int3 <= done_int2;
      end
   end

   // Align significants
   wire [EXP_W-1:0]         diff_exp = A_exp_reg - B_exp_reg;
   wire [ACC_W+STICKY_BITS-1:0] B_man_in = {B_man_reg, {STICKY_BITS{1'b0}}} >> diff_exp;

   // Sticky
   wire                     sticky_bit = |B_man_in[STICKY_BITS-1:0];

   // pipeline stage 4
   reg [EXP_W-1:0]          A_exp_reg2;
   reg [ACC_W-1:0]          A_man_reg2;

   reg [ACC_W-1:0]          B_man_reg2;

   reg                      done_int4;
   always @(posedge clk) begin
      if (rst) begin
         A_exp_reg2 <= {EXP_W{1'b0}};
         A_man_reg2 <= {ACC_W{1'b0}};

         B_man_reg2 <= {ACC_W{1'b0}};

         done_int4 <= 1'b0;
      end else begin
         A_exp_reg2 <= A_exp_reg;
         A_man_reg2 <= A_man_reg;

         B_man_reg2 <= {B_man_in[STICKY_BITS +: ACC_W-1], sticky_bit};

         done_int4 <= done_int3;
      end
   end

   // Accumulation
   wire [ACC_W:0]           acc_man = {A_man_reg2[ACC_W-1], A_man_reg2} + {B_man_reg2[ACC_W-1], B_man_reg2};

   // pipeline stage 5
   reg [EXP_W-1:0]          acc_exp_reg;
   reg [ACC_W:0]            acc_man_reg;

   reg                      done_int5;
   always @(posedge clk) begin
      if (rst) begin
         acc_exp_reg <= {EXP_W{1'b0}};
         acc_man_reg <= {(ACC_W+1){1'b0}};

         done_int5 <= 1'b0;
      end else begin
         acc_exp_reg <= A_exp_reg2;
         acc_man_reg <= acc_man;

         done_int5 <= done_int4;
      end
   end

   // Convert final result to sign-magnitude
   wire                     res_sign = acc_man_reg[ACC_W];
   wire [ACC_W:0]           res_inv  = (acc_man_reg ^ {(ACC_W+1){acc_man_reg[ACC_W]}}) + acc_man_reg[ACC_W];

   // Normalize
   localparam LZC_W  = $clog2(ACC_W+1);
   localparam OFFSET = GUARD_W+2; // 2 -> 1 for the carry from the accumulator and 1 for the 2's Complement

   wire [LZC_W-1:0]         lzc_int;
   clz #(
         .DATA_W(ACC_W+1)
         )
   clz0
     (
      .data_in  (res_inv),
      .data_out (lzc_int)
      );

   wire [LZC_W-1:0]         lzc = ({{(EXP_W-LZC_W){1'b0}}, lzc_int} > acc_exp_reg)? acc_exp_reg[LZC_W-1:0]: lzc_int;
   wire [LZC_W-1:0]         lzc_inv = ~lzc;

   wire [EXP_W-1:0]         exp_norm = acc_exp_reg + {{(EXP_W-LZC_W){lzc_inv[LZC_W-1]}}, lzc_inv} + OFFSET[EXP_W-1:0];
   wire [ACC_W:0]           man_norm = res_inv[ACC_W]? res_inv: res_inv << lzc;

   wire [EXP_W-1:0]         exp_adjust = res_inv[ACC_W]? acc_exp_reg: exp_norm;
   wire [MAN_W+EXTRA-1:0]   man_adjust = {man_norm[ACC_W -: MAN_W+EXTRA-1], |man_norm[ACC_W-(MAN_W-EXTRA-1):0]};

   // pipeline stage 6
   reg                      res_sign_reg;

   reg [EXP_W-1:0]          exp_adjust_reg;
   reg [MAN_W+EXTRA-1:0]    man_adjust_reg;

   reg                      done_int6;
   always @(posedge clk) begin
      if (rst) begin
         res_sign_reg <= 1'b0;

         exp_adjust_reg <= {EXP_W{1'b0}};
         man_adjust_reg <= {(MAN_W+EXTRA){1'b0}};

         done_int6 <= 1'b0;
      end else begin
         res_sign_reg <= res_sign;

         exp_adjust_reg <= exp_adjust;
         man_adjust_reg <= man_adjust;

         done_int6 <= done_int5;
      end
   end

   // Round
   wire [EXP_W-1:0]         exp_adjust_rnd;
   wire [MAN_W-1:0]         man_adjust_rnd;
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
      .mantissa_rnd (man_adjust_rnd)
      );

   // Pack
   wire [MAN_W-2:0]         Fraction = man_adjust_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]         Exponent = man_adjust_rnd[MAN_W-1]? exp_adjust_rnd: {EXP_W{1'b0}};
   wire                     Sign     = res_sign_reg;

`ifdef SPECIAL_CASES
   wire [DATA_W-1:0]        res_in  = special? res_special: {Sign, Exponent, Fraction};
   wire                     done_in = special? start: done_int3;
`else
   wire [DATA_W-1:0]        res_in  = {Sign, Exponent, Fraction};
   wire                     done_in = done_int3;
`endif

   // pipeline stage 7
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
