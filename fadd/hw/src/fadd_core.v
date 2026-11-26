`timescale 1ns / 1ps

module fadd_core #(
   parameter EXP_W         = 8,
   parameter MAN_W         = 24,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input      valid_i,
   output reg valid_o,

   input             op_a_sign,
   input [EXP_W-1:0] op_a_exp,
   input [MAN_W-1:0] op_a_man,

   input op_a_nan,
   input op_a_inf,
   input op_a_zero,

   input             op_b_sign,
   input [EXP_W-1:0] op_b_exp,
   input [MAN_W-1:0] op_b_man,

   input op_b_nan,
   input op_b_inf,
   input op_b_zero,

   // special result code {kind, sign}, as in pack
   output reg [         2:0] res_special,

   output                 res_sign,
   output reg [EXP_W-1:0] res_exp,
   output reg [MAN_W+3:0] res_man
);

   localparam EXTRA = 3;


   // Special cases
   wire special_int = SPECIAL_CASES & (op_a_nan | op_a_inf | op_b_nan | op_b_inf);
   wire inf_diff = op_a_inf & op_b_inf & (op_a_sign ^ op_b_sign);
   // a NaN, an infinity, or two zeros of the same sign, whose sum keeps that sign; zeros
   // of opposite signs cancel in the datapath
   wire zero_same = op_a_zero & op_b_zero & (op_a_sign == op_b_sign);
   wire [2:0] res_special_int = {
      special_int ? (op_a_nan | op_b_nan | inf_diff ? 2'b01 : 2'b10) : zero_same ? 2'b11 : 2'b00,
      op_b_inf ? op_b_sign : op_a_sign
   };

   // A is the operand with the larger magnitude, so A - B is never negative
   wire comp = ({op_a_exp, op_a_man} >= {op_b_exp, op_b_man});

   wire A_sign = comp ? op_a_sign : op_b_sign;
   wire [EXP_W-1:0] A_Exponent = comp ? op_a_exp : op_b_exp;
   wire [MAN_W-1:0] A_Mantissa = comp ? op_a_man : op_b_man;

   wire B_sign = comp ? op_b_sign : op_a_sign;
   wire [EXP_W-1:0] B_Exponent = comp ? op_b_exp : op_a_exp;
   wire [MAN_W-1:0] B_Mantissa = comp ? op_b_man : op_a_man;

   // pipeline stage 1
   reg A_sign_reg;
   reg [EXP_W-1:0] A_Exponent_reg;
   reg [MAN_W-1:0] A_Mantissa_reg;

   reg B_sign_reg;
   reg [EXP_W-1:0] B_Exponent_reg;
   reg [MAN_W-1:0] B_Mantissa_reg;

   reg [2:0] res_special_reg;

   reg valid_d1;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_sign_reg      <= 1'b0;
         A_Exponent_reg  <= {EXP_W{1'b0}};
         A_Mantissa_reg  <= {MAN_W{1'b0}};

         B_sign_reg      <= 1'b0;
         B_Exponent_reg  <= {EXP_W{1'b0}};
         B_Mantissa_reg  <= {MAN_W{1'b0}};

         res_special_reg <= 3'd0;

         valid_d1        <= 1'b0;
      end else begin
         A_sign_reg      <= A_sign;
         A_Exponent_reg  <= A_Exponent;
         A_Mantissa_reg  <= A_Mantissa;

         B_sign_reg      <= B_sign;
         B_Exponent_reg  <= B_Exponent;
         B_Mantissa_reg  <= B_Mantissa;

         res_special_reg <= res_special_int;

         valid_d1        <= valid_i;
      end
   end

   // Align significands: B keeps MAN_W+2 bits, the bits shifted out make the sticky bit
   localparam RSHIFT_LIM = MAN_W + 2;
   localparam RSH_W = $clog2(RSHIFT_LIM + 1);
   localparam TZ_W = $clog2(MAN_W + 1);

   wire [EXP_W-1:0] diff_Exponent = A_Exponent_reg - B_Exponent_reg;
   wire [RSH_W-1:0] rshift = (diff_Exponent > RSHIFT_LIM) ? RSHIFT_LIM[RSH_W-1:0] :
      diff_Exponent[RSH_W-1:0];
   wire [MAN_W+1:0] B_Mantissa_in = {B_Mantissa_reg, 2'b00} >> rshift;

   // Sticky: some bit is shifted out when the shift exceeds the trailing zeros of {B, 2'b00}
   wire [MAN_W-1:0] B_Mantissa_rev;
   genvar i;
   generate
      for (i = 0; i < MAN_W; i = i + 1) begin : gen_rev
         assign B_Mantissa_rev[i] = B_Mantissa_reg[MAN_W-1-i];
      end
   endgenerate

   wire [TZ_W-1:0] B_tz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (B_Mantissa_rev),
      .data_out(B_tz)
   );

   wire sticky_bit = ({1'b0, rshift} > ({{(RSH_W + 1 - TZ_W) {1'b0}}, B_tz} + 2'd2));

   // Invert B if subtraction
   wire                         subtract = A_sign_reg ^ B_sign_reg;
   wire [      MAN_W+EXTRA-1:0] B_Mantissa_al = {B_Mantissa_in, sticky_bit};

   // pipeline stage 2
   reg                          A_sign_reg2;
   reg  [            EXP_W-1:0] A_Exponent_reg2;
   reg  [            MAN_W-1:0] A_Mantissa_reg2;

   reg  [      MAN_W+EXTRA-1:0] B_Mantissa_reg2;

   reg                          subtract_reg;

   reg  [                  2:0] res_special_reg2;

   reg                          valid_d2;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_sign_reg2      <= 1'b0;
         A_Exponent_reg2  <= {EXP_W{1'b0}};
         A_Mantissa_reg2  <= {MAN_W{1'b0}};

         B_Mantissa_reg2  <= {(MAN_W + EXTRA) {1'b0}};

         subtract_reg     <= 1'b0;

         res_special_reg2 <= 3'd0;

         valid_d2         <= 1'b0;
      end else begin
         A_sign_reg2      <= A_sign_reg;
         A_Exponent_reg2  <= A_Exponent_reg;
         A_Mantissa_reg2  <= A_Mantissa_reg;

         B_Mantissa_reg2  <= {(MAN_W + EXTRA) {subtract}} ^ B_Mantissa_al;

         subtract_reg     <= subtract;

         res_special_reg2 <= res_special_reg;

         valid_d2         <= valid_d1;
      end
   end

   // Addition
   // A has zeros below it, at the guard, round and sticky positions of B
   wire [MAN_W+EXTRA:0] Temp = {1'b0, A_Mantissa_reg2, {EXTRA{1'b0}}} + {subtract_reg, B_Mantissa_reg2} +
      subtract_reg;

   // pipeline stage 3
   reg A_sign_reg3;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_sign_reg3   <= 1'b0;

         res_exp       <= {EXP_W{1'b0}};
         res_man       <= {(MAN_W + EXTRA + 1) {1'b0}};

         res_special   <= 3'd0;

         valid_o       <= 1'b0;
      end else begin
         A_sign_reg3   <= A_sign_reg2;

         res_exp       <= A_Exponent_reg2;
         res_man       <= Temp;

         res_special   <= res_special_reg2;

         valid_o       <= valid_d2;
      end
   end

   // The result has the sign of A and is never negative
   assign res_sign = A_sign_reg3;

endmodule
