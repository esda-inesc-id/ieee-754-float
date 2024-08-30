`timescale 1ns / 1ps

`include "ieee754_defs.vh"

module fp_div #(
                parameter DATA_W = 32,
                parameter EXP_W = 8
                )
   (
    input                     clk,
    input                     rst,

    input                     start,
    output                    done,

    input                     op_a_sign,
    input [EXP_W-1:0]         op_a_exp,
    input [`MAN_W-1:0]        op_a_man,

`ifdef SPECIAL_CASES
    input                     op_a_nan,
    input                     op_a_inf,
    input                     op_a_zero,
`endif

    input                     op_b_sign,
    input [EXP_W-1:0]         op_b_exp,
    input [`MAN_W-1:0]        op_b_man,

`ifdef SPECIAL_CASES
    input                     op_b_nan,
    input                     op_b_inf,
    input                     op_b_zero,

    output reg                special,
    output reg [DATA_W-1:0]   res_special,
`endif

    output reg                res_sign,
    output reg [EXP_W+1:0]    res_exp,
    output reg [2*`MAN_W-1:0] res_man,
    output [EXP_W+1:0]        offset
    );

   // Special cases
`ifdef SPECIAL_CASES
   wire                       special_int = op_a_nan | op_a_inf | op_b_nan | op_b_inf | op_b_zero;
   wire [DATA_W-1:0]          res_special_int = (op_a_nan | op_b_nan)? `NAN:
                                                             op_b_inf? (op_a_inf? `NAN: {DATA_W{1'b0}}):
                                               (op_a_inf & op_b_zero)? `NAN:
                                              (op_a_zero & op_b_zero)? `NAN:
                                                                       `INF(op_a_sign ^ op_b_sign);
`endif

   wire                       A_sign     = op_a_sign;
   wire [EXP_W-1:0]           A_Exponent = op_a_exp;
   wire [`MAN_W-1:0]          A_Mantissa = op_a_man;

   wire                       B_sign     = op_b_sign;
   wire [EXP_W-1:0]           B_Exponent = op_b_exp;
   wire [`MAN_W-1:0]          B_Mantissa = op_b_man;

   // pipeline stage 1
   reg                        A_sign_reg;
   reg [EXP_W-1:0]            A_Exponent_reg;

   reg                        B_sign_reg;
   reg [EXP_W-1:0]            B_Exponent_reg;

`ifdef SPECIAL_CASES
   reg                        special_reg;
   reg [DATA_W-1:0]           res_special_reg;
`endif
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};

         B_sign_reg <= 1'b0;
         B_Exponent_reg <= {EXP_W{1'b0}};

`ifdef SPECIAL_CASES
         special_reg <= 1'b0;
         res_special_reg <= {DATA_W{1'b0}};
`endif
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;

         B_sign_reg <= B_sign;
         B_Exponent_reg <= B_Exponent;

`ifdef SPECIAL_CASES
         special_reg <= special_int;
         res_special_reg <= res_special_int;
`endif
      end
   end

   // Division
   wire                       Temp_sign = A_sign_reg ^ B_sign_reg;
   wire [EXP_W+1:0]           Temp_Exponent = {2'd0, A_Exponent_reg} - {2'd0, B_Exponent_reg} + `BIAS;
   wire [2*`MAN_W-1:0]        Temp_Mantissa; // = A_Mantissa_reg / B_Mantissa_reg;
   wire [2*`MAN_W-1:0]        remainder;
   wire                       div_en = ~start & ~rst;
   wire                       div_done_;
   div_subshift #(
                  .DATA_W(2*`MAN_W)
                  )
   div_subshift
     (
      .clk       (clk),

      .en        (div_en),
      .sign      (1'b0),
      .done      (div_done_),

      .dividend  ({A_Mantissa, {`MAN_W{1'b0}}}),
      .divisor   ({{`MAN_W{1'b0}}, B_Mantissa}),
      .quotient  (Temp_Mantissa),
      .remainder (remainder)
      );

   reg                        div_start;
   wire                       div_done = div_done_ & div_start;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         div_start <= 1'b0;
      end else if (start) begin
         div_start <= 1'b1;
      end
   end

   reg                        div_done_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         div_done_reg <= 1'b1;
      end else begin
         div_done_reg <= div_done;
      end
   end

   assign done = div_done & ~div_done_reg;

   // pipeline stage 2
   always @(posedge clk) begin
      if (rst) begin
         res_sign <= 1'b0;
         res_exp <= {(EXP_W+2){1'b0}};
         res_man <= {(2*`MAN_W){1'b0}};

`ifdef SPECIAL_CASES
         special <= 1'b0;
         res_special <= {DATA_W{1'b0}};
`endif
      end else begin
         res_sign <= Temp_sign;
         res_exp <= Temp_Exponent;
         res_man <= {Temp_Mantissa[2*`MAN_W-1:1], Temp_Mantissa[0] | |remainder};

`ifdef SPECIAL_CASES
         special <= special_reg;
         res_special <= res_special_reg;
`endif
      end
   end

   assign offset = 24; // 24 -> 23 for the left shift and 1 for the 2's Complement

endmodule
