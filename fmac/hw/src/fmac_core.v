`timescale 1ns / 1ps

module fmac_core #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter MAN_W         = DATA_W - EXP_W,
   parameter SPECIAL_CASES = 1,
   parameter LGUARD_W      = 0,
   parameter RGUARD_W      = 0
) (
   input clk,
   input rst,

   input      valid_i,
   output reg valid_o,

   input             op_a_sign,
   input [EXP_W-1:0] op_a_exp,
   input [MAN_W-1:0] op_a_man,
   input             op_a_nan,
   input             op_a_inf,
   input             op_a_zero,

   input             op_b_sign,
   input [EXP_W-1:0] op_b_exp,
   input [MAN_W-1:0] op_b_man,
   input             op_b_nan,
   input             op_b_inf,
   input             op_b_zero,

   output              special,
   output [DATA_W-1:0] res_special,

   output reg               res_sign,
   output reg [  EXP_W+1:0] res_exp,
   output reg [MAN_W+3-1:0] res_man,
   output                   res_inv
);

   localparam EXTRA = 3;

   localparam BIAS = 2 ** (EXP_W - 1) - 1;

   // Normalize the significands, so that subnormal products keep full precision
   localparam LZ_W = $clog2(MAN_W + 1);
   // exponent of an empty accumulator or zero product: below any real product
   localparam [EXP_W+1:0] EXP_ZERO = -(2 ** EXP_W + 2 * MAN_W);

   wire [LZ_W-1:0] A_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_a (
      .data_in (op_a_man),
      .symbol  (1'b0),
      .data_out(A_lz)
   );

   wire [LZ_W-1:0] B_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (op_b_man),
      .symbol  (1'b0),
      .data_out(B_lz)
   );

   reg [ LZ_W-1:0] A_lz_reg;
   reg [ LZ_W-1:0] B_lz_reg;

   // pipeline stage 1
   reg             A_sign_reg;
   reg [EXP_W-1:0] A_Exponent_reg;
   reg [MAN_W-1:0] A_Mantissa_reg;

   reg             B_sign_reg;
   reg [EXP_W-1:0] B_Exponent_reg;
   reg [MAN_W-1:0] B_Mantissa_reg;

   reg             valid_d1;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_lz_reg       <= {LZ_W{1'b0}};
         B_lz_reg       <= {LZ_W{1'b0}};

         A_sign_reg     <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};

         B_sign_reg     <= 1'b0;
         B_Exponent_reg <= {EXP_W{1'b0}};
         B_Mantissa_reg <= {MAN_W{1'b0}};

         valid_d1       <= 1'b0;
      end else begin
         A_lz_reg       <= A_lz;
         B_lz_reg       <= B_lz;

         A_sign_reg     <= op_a_sign;
         A_Exponent_reg <= op_a_exp;
         A_Mantissa_reg <= op_a_man << A_lz;

         B_sign_reg     <= op_b_sign;
         B_Exponent_reg <= op_b_exp;
         B_Mantissa_reg <= op_b_man << B_lz;

         valid_d1       <= valid_i;
      end
   end

   // Multiplication
   wire mul_sign = A_sign_reg ^ B_sign_reg;
   wire mul_zero = ~(|A_Mantissa_reg & |B_Mantissa_reg);
   wire [EXP_W+1:0] A_lz_ext = {{(EXP_W + 2 - LZ_W) {1'b0}}, A_lz_reg};
   wire [EXP_W+1:0] B_lz_ext = {{(EXP_W + 2 - LZ_W) {1'b0}}, B_lz_reg};
   // a zero product must not take part in the alignment
   wire [EXP_W+1:0] mul_exp = mul_zero ? EXP_ZERO :
      {2'd0, A_Exponent_reg} + {2'd0, B_Exponent_reg} - BIAS - A_lz_ext - B_lz_ext;
   wire [2*MAN_W-1:0] mul_man = A_Mantissa_reg * B_Mantissa_reg;

   // pipeline stage 2
   reg mul_sign_reg;
   reg [EXP_W+1:0] mul_exp_reg;
   reg [2*MAN_W-1:0] mul_man_reg;

   reg valid_d2;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         mul_sign_reg <= 1'b0;
         mul_exp_reg  <= {(EXP_W + 2) {1'b0}};
         mul_man_reg  <= {(2 * MAN_W) {1'b0}};

         valid_d2     <= 1'b0;
      end else begin
         mul_sign_reg <= mul_sign;
         mul_exp_reg  <= mul_exp;
         mul_man_reg  <= mul_man;

         valid_d2     <= valid_d1;
      end
   end

   localparam ACC_W = LGUARD_W + 1 + 2 * MAN_W + RGUARD_W;

   // Accumulation in 2's Complement
   wire [2*MAN_W-1:0] mul_man_c_ = mul_man_reg ^ {(2 * MAN_W) {mul_sign_reg}};
   wire [ACC_W+EXTRA:0] mul_man_c = {
      {(LGUARD_W + 2) {mul_sign_reg}}, mul_man_c_, {(RGUARD_W + EXTRA) {mul_sign_reg}}
   };

   reg [EXP_W+1:0] acc_exp_reg, acc_exp_reg2;
   reg [ACC_W+EXTRA:0] acc_man_reg;
   reg [ACC_W+EXTRA:0] acc_man_reg2;

   // Round to odd: keeps the final rounding correct
   wire [ACC_W:0] acc_odd = {
      acc_man_reg[ACC_W+EXTRA:EXTRA+1], acc_man_reg[EXTRA] | (|acc_man_reg[EXTRA-1:0])
   };

   wire [EXP_W+1:0] A_exp_int = valid_d2 ? mul_exp_reg : acc_exp_reg2;
   wire [ACC_W+EXTRA:0] A_man_int = valid_d2 ? mul_man_c : acc_man_reg2;

   wire cin_int = valid_d2 & mul_sign_reg;

   // The first two products of a stream start the even and odd accumulators from zero
   reg valid_d3, valid_d4;
   wire acc_clr = (valid_d2 & ~valid_d3) | (valid_d3 & ~valid_d4);

   wire ovf_int = ^acc_man_reg[ACC_W+EXTRA-:2];
   wire undf_int = (~^acc_man_reg[ACC_W+EXTRA-1-:2]) & (|acc_man_reg);

   wire [EXP_W+1:0] B_exp_int = acc_clr ? EXP_ZERO :
      ovf_int ? acc_exp_reg + 1'b1 :
      undf_int ? acc_exp_reg - 1'b1 :
      acc_exp_reg;
   wire [ACC_W+EXTRA:0] B_man_int =
      acc_clr ? {(ACC_W + 1 + EXTRA) {1'b0}} :
      ovf_int ? {acc_man_reg[ACC_W+EXTRA], acc_odd, {(EXTRA-1){1'b0}}} :
      undf_int ? {acc_odd[ACC_W-1:0], {(EXTRA+1){1'b0}}} :
      {acc_odd, {EXTRA{1'b0}}};

   wire comp = ($signed(
       A_exp_int
   ) >= $signed(
       B_exp_int
   )) ? 1'b1 : 1'b0;  // exponents can be negative

   wire [EXP_W+1:0] A_exp = comp ? A_exp_int : B_exp_int;
   wire [ACC_W+EXTRA:0] A_man = comp ? A_man_int : B_man_int;

   wire [EXP_W+1:0] B_exp = comp ? B_exp_int : A_exp_int;
   wire [ACC_W+EXTRA:0] B_man = comp ? B_man_int : A_man_int;

   localparam STICKY_BITS = ACC_W + EXTRA + 2;

   // Align significants
   wire [EXP_W+1:0] diff_exp = A_exp - B_exp;
   wire [EXP_W+1:0] shift = (diff_exp > STICKY_BITS[EXP_W+1:0]) ? STICKY_BITS[EXP_W+1:0] : diff_exp;
   wire [ACC_W+EXTRA+STICKY_BITS:0] B_man_in = $signed({B_man, {STICKY_BITS{1'b0}}}) >>> shift;

   // Sticky
   wire sticky = |B_man_in[STICKY_BITS:0];

   // pipeline stage 3
   reg [EXP_W+1:0] A_exp_reg;
   reg [ACC_W+EXTRA:0] A_man_reg;

   reg [ACC_W+EXTRA:0] B_man_reg;

   reg cin;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_exp_reg <= {(EXP_W + 2) {1'b0}};
         A_man_reg <= {(ACC_W + 1 + EXTRA) {1'b0}};

         B_man_reg <= {(ACC_W + 1 + EXTRA) {1'b0}};

         cin       <= 1'b0;

         valid_d3  <= 1'b0;
      end else begin
         A_exp_reg <= A_exp;
         A_man_reg <= A_man;

         B_man_reg <= {B_man_in[STICKY_BITS+1+:ACC_W+EXTRA], sticky};

         cin       <= cin_int;

         valid_d3  <= valid_d2;
      end
   end

   // Accumulation
   wire [ACC_W+EXTRA:0] acc_man = A_man_reg + B_man_reg + cin;

   // pipeline stage 4
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc_exp_reg <= {(EXP_W + 2) {1'b0}};
         acc_man_reg <= {(ACC_W + 1 + EXTRA) {1'b0}};

         valid_d4    <= 1'b0;
      end else begin
         acc_exp_reg <= A_exp_reg;
         acc_man_reg <= acc_man;

         valid_d4    <= valid_d3;
      end
   end

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc_exp_reg2 <= {(EXP_W + 2) {1'b0}};
         acc_man_reg2 <= {(ACC_W + 1 + EXTRA) {1'b0}};
      end else begin
         acc_exp_reg2 <= B_exp_int;
         acc_man_reg2 <= B_man_int;
      end
   end

   // Special cases: sticky over one accumulation, aligned with the result
   localparam SPECIAL_DELAY = 6;

   wire term_nan = op_a_nan | op_b_nan | (op_a_inf & op_b_zero) | (op_a_zero & op_b_inf);
   wire term_inf = (op_a_inf | op_b_inf) & ~term_nan;
   wire term_sign = op_a_sign ^ op_b_sign;
   wire term_zero = (op_a_zero | op_b_zero) & ~term_nan;
   wire [4:0] term_flags = {
      term_zero & ~term_sign, term_zero & term_sign, term_inf & term_sign, term_inf & ~term_sign,
      term_nan
   };

   reg [4:0] acc_flags;
   reg [5*SPECIAL_DELAY-1:0] flags_pipe;
   wire [4:0] acc_merge = {acc_flags[4:3] & term_flags[4:3], acc_flags[2:0] | term_flags[2:0]};
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc_flags  <= 5'b00000;
         flags_pipe <= {(5 * SPECIAL_DELAY) {1'b0}};
      end else begin
         // NaN and infinities are sticky; a signed zero needs every term to be a zero
         // of that sign, so the result keeps that sign in every rounding mode
         if (valid_i) acc_flags <= valid_d1 ? acc_merge : term_flags;
         flags_pipe <= {flags_pipe[5*SPECIAL_DELAY-6:0], acc_flags};
      end
   end

   wire [4:0] res_flags = flags_pipe[5*SPECIAL_DELAY-1-:5];
   wire       res_nan = res_flags[0] | (res_flags[1] & res_flags[2]);

   assign special = (SPECIAL_CASES != 0) & (|res_flags);
   assign res_special = res_nan ? {1'b0, {EXP_W{1'b1}}, 1'b1, {(MAN_W-2){1'b0}}} :
      res_flags[3] ? {1'b1, {(DATA_W-1){1'b0}}} :
      res_flags[4] ? {DATA_W{1'b0}} :
      {res_flags[2], {EXP_W{1'b1}}, {(MAN_W-1){1'b0}}};

   // Convert final result to sign-magnitude
   wire res_sign_int = acc_man_reg[ACC_W+EXTRA];

   // exponent at which the normalized result has the subnormal exponent (1)
   localparam EXP_MIN = -(LGUARD_W + 2);
   localparam RSHIFT_LIM = MAN_W + 2;

   // Normalize
   localparam LSC_W = $clog2(ACC_W + EXTRA + 2);
   localparam OFFSET = LGUARD_W + 4;  // the top accumulator bit has weight 2**(OFFSET-1)

   wire [LSC_W-1:0] lsc;
   cls #(
      .DATA_W(ACC_W + EXTRA + 1)
   ) cls0 (
      .data_in (acc_man_reg),
      .symbol  (res_sign_int),
      .data_out(lsc)
   );

   wire [EXP_W+1:0] exp_diff = EXP_MIN[EXP_W+1:0] - acc_exp_reg + lsc;
   wire [EXP_W+1:0] exp_diff2 = EXP_MIN[EXP_W+1:0] - acc_exp_reg;
   wire [EXP_W+1:0] exp_diff2_1 = acc_exp_reg - EXP_MIN[EXP_W+1:0];

   wire [EXP_W+1:0] lshift = exp_diff[EXP_W+1] ? lsc : exp_diff2_1;
   wire [EXP_W+1:0] lshift_inv = ~lshift;

   wire [EXP_W+1:0] rshift_lim = RSHIFT_LIM[EXP_W+1:0];
   wire [EXP_W+1:0] rshift = (exp_diff2 > rshift_lim) ? rshift_lim : exp_diff2;
   wire [ACC_W+EXTRA+RSHIFT_LIM:0] man_rsht = $signed({acc_man_reg, {RSHIFT_LIM{1'b0}}}) >>> rshift;

   wire [EXP_W+1:0] exp_norm = acc_exp_reg + lshift_inv + OFFSET[EXP_W+1:0];
   wire [ACC_W+EXTRA:0] man_rsht_st = {
      man_rsht[ACC_W+EXTRA+RSHIFT_LIM:RSHIFT_LIM+1], |man_rsht[RSHIFT_LIM:0]
   };
   wire [ACC_W+EXTRA:0] man_norm = exp_diff2[EXP_W+1] ? acc_man_reg << lshift : man_rsht_st;

   wire [EXP_W+1:0] exp_adjust = exp_norm;
   wire [MAN_W+EXTRA-1:0] man_adjust = {
      man_norm[ACC_W+EXTRA-:MAN_W+EXTRA-1], |man_norm[ACC_W+EXTRA-(MAN_W+EXTRA-1):0]
   };

   // pipeline stage 5
   reg valid_d5, valid_d6;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res_sign <= 1'b0;
         res_exp  <= {(EXP_W + 2) {1'b0}};
         res_man  <= {(MAN_W + EXTRA) {1'b0}};

         valid_d5 <= 1'b0;
         valid_d6 <= 1'b0;
         valid_o  <= 1'b0;
      end else begin
         res_sign <= res_sign_int;
         res_exp  <= exp_adjust;
         res_man  <= man_adjust;

         valid_d5 <= valid_d4;
         valid_d6 <= valid_d5;
         valid_o  <= valid_d6 & ~valid_d5;
      end
   end

   assign res_inv = res_sign;

endmodule
