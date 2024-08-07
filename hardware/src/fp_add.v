`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_add #(
                parameter DATA_W = 32,
                parameter EXP_W = 8
                )
   (
    input                      clk,
    input                      rst,

    input                      start,
    output reg                 done,

    input                      op_a_sign,
    input [EXP_W-1:0]          op_a_exp,
    input [MAN_W-1:0]          op_a_man,

`ifdef SPECIAL_CASES
    input                      op_a_nan,
    input                      op_a_inf,
    input                      op_a_zero,
`endif

    input                      op_b_sign,
    input [EXP_W-1:0]          op_b_exp,
    input [MAN_W-1:0]          op_b_man,

`ifdef SPECIAL_CASES
    input                      op_b_nan,
    input                      op_b_inf,
    input                      op_b_zero,

    output reg                 special,
    output reg [DATA_W-1:0]    res_special,
`endif

    output                     res_sign,
    output reg [EXP_W-1:0]     res_exp,
    output reg [MAN_W+EXTRA:0] res_man,
    output                     res_inv
    );

   localparam MAN_W = DATA_W-EXP_W;
   localparam BIAS = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;

   // Special cases
`ifdef SPECIAL_CASES
   wire                        special_int = op_a_nan | op_a_inf | op_b_nan | op_b_inf;
   wire [DATA_W-1:0]           res_special_int = (op_a_nan | op_b_nan)? `NAN:
                                                 (op_a_inf & op_b_inf)? ((op_a_sign ^ op_b_sign)? `NAN:
                                                                                                  `INF(op_a_sign)):
                                                              op_b_inf? `INF(op_b_sign):
                                                                        `INF(op_a_sign);
`endif

   wire                        comp = (op_a_exp >= op_b_exp)? 1'b1 : 1'b0;

   wire                        A_sign     = comp? op_a_sign: op_b_sign;
   wire [EXP_W-1:0]            A_Exponent = comp? op_a_exp: op_b_exp;
   wire [MAN_W-1:0]            A_Mantissa = comp? op_a_man: op_b_man;

   wire                        B_sign     = comp? op_b_sign: op_a_sign;
   wire [EXP_W-1:0]            B_Exponent = comp? op_b_exp: op_a_exp;
   wire [MAN_W-1:0]            B_Mantissa = comp? op_b_man: op_a_man;

   // pipeline stage 1
   reg                         A_sign_reg;
   reg [EXP_W-1:0]             A_Exponent_reg;
   reg [MAN_W-1:0]             A_Mantissa_reg;

   reg                         B_sign_reg;
   reg [EXP_W-1:0]             B_Exponent_reg;
   reg [MAN_W-1:0]             B_Mantissa_reg;

`ifdef SPECIAL_CASES
   reg                         special_reg;
   reg [DATA_W-1:0]            res_special_reg;
`endif

   reg                         done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};

         B_sign_reg <= 1'b0;
         B_Exponent_reg <= {EXP_W{1'b0}};
         B_Mantissa_reg <= {MAN_W{1'b0}};

`ifdef SPECIAL_CASES
         special_reg <= 1'b0;
         res_special_reg <= {DATA_W{1'b0}};
`endif

         done_int <= 1'b0;
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         B_sign_reg <= B_sign;
         B_Exponent_reg <= B_Exponent;
         B_Mantissa_reg <= B_Mantissa;

`ifdef SPECIAL_CASES
         special_reg <= special_int;
         res_special_reg <= res_special_int;
`endif

         done_int <= start;
      end
   end

   localparam STICKY_BITS = MAN_W+2;

   // Align significants
   wire [EXP_W-1:0]            diff_Exponent = A_Exponent_reg - B_Exponent_reg;
   wire [EXP_W-1:0]            rshift = (diff_Exponent > STICKY_BITS)? STICKY_BITS: diff_Exponent;
   wire [MAN_W+STICKY_BITS-1:0] B_Mantissa_in = {B_Mantissa_reg, {STICKY_BITS{1'b0}}} >> rshift;

   // Sticky
   wire                        sticky_bit = |B_Mantissa_in[STICKY_BITS-3:0];

   // Invert OpA if subtraction
   wire                        subtract = A_sign_reg ^ B_sign_reg;
   wire [MAN_W+EXTRA-1:0]      A_Mantissa_inv = {(MAN_W+EXTRA){subtract}} ^ {A_Mantissa_reg, {EXTRA{1'b0}}};

   // pipeline stage 2
   reg                         A_sign_reg2;
   reg [EXP_W-1:0]             A_Exponent_reg2;
   reg [MAN_W+EXTRA-1:0]       A_Mantissa_reg2;

   reg [MAN_W+EXTRA-1:0]       B_Mantissa_reg2;

   reg                         subtract_reg;

`ifdef SPECIAL_CASES
   reg                         special_reg2;
   reg [DATA_W-1:0]            res_special_reg2;
`endif

   reg                         done_int2;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg2 <= 1'b0;
         A_Exponent_reg2 <= {EXP_W{1'b0}};
         A_Mantissa_reg2 <= {(MAN_W+EXTRA){1'b0}};

         B_Mantissa_reg2 <= {(MAN_W+EXTRA){1'b0}};

         subtract_reg <= 1'b0;

`ifdef SPECIAL_CASES
         special_reg2 <= 1'b0;
         res_special_reg2 <= {DATA_W{1'b0}};
`endif

         done_int2 <= 1'b0;
      end else begin
         A_sign_reg2 <= A_sign_reg;
         A_Exponent_reg2 <= A_Exponent_reg;
         A_Mantissa_reg2 <= A_Mantissa_inv;

         B_Mantissa_reg2 <= {B_Mantissa_in[STICKY_BITS-2 +: MAN_W+EXTRA-1], sticky_bit};

         subtract_reg <= subtract;

`ifdef SPECIAL_CASES
         special_reg2 <= special_reg;
         res_special_reg2 <= res_special_reg;
`endif

         done_int2 <= done_int;
      end
   end

   // Addition
   wire [MAN_W+EXTRA:0]        Temp = {subtract_reg, A_Mantissa_reg2} + {1'b0, B_Mantissa_reg2} + {{(MAN_W+EXTRA){1'b0}}, subtract_reg};

   // pipeline stage 3
   reg                         A_sign_reg3;
   reg                         subtract_reg2;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg3 <= 1'b0;
         subtract_reg2 <= 1'b0;

         res_exp <= {EXP_W{1'b0}};
         res_man <= {(MAN_W+EXTRA+1){1'b0}};

`ifdef SPECIAL_CASES
         special <= 1'b0;
         res_special <= {DATA_W{1'b0}};
`endif

         done <= 1'b0;
      end else begin
         A_sign_reg3 <= A_sign_reg2;
         subtract_reg2 <= subtract_reg;

         res_exp <= A_Exponent_reg2;
         res_man <= Temp;

`ifdef SPECIAL_CASES
         special <= special_reg2;
         res_special <= res_special_reg2;
`endif

         done <= done_int2;
      end
   end

   // Compute result sign
   assign res_sign = subtract_reg2? ~A_sign_reg3 ^ res_man[MAN_W+EXTRA]: A_sign_reg3;
   assign res_inv  = subtract_reg2 & res_man[MAN_W+EXTRA];

endmodule
