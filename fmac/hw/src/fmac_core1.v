`timescale 1ns / 1ps

// fmac_core for small formats: the product, its alignment and the addition in one clock
// cycle into a single accumulator, without pipeline registers. At the end of a stream (the
// first cycle with valid_i low) the outputs carry the normalized accumulator, which pack
// rounds and registers. The arithmetic is that of fmac_core with STEP = 1.
module fmac_core1 #(
   parameter EXP_W         = 2,
   parameter MAN_W         = 2,
   parameter SPECIAL_CASES = 1,
   parameter LGUARD_W      = 0,
   parameter RGUARD_W      = 0
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

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

   // special result code {kind, sign}, as in pack
   output [2:0] res_special,

   output               res_sign,
   // never negative and below 2**(EXP_W+1)
   output [    EXP_W:0] res_exp,
   output [MAN_W+3-1:0] res_man
);

   localparam EXTRA = 3;
   localparam BIAS = 2 ** (EXP_W - 1) - 1;
   localparam LZ_W = $clog2(MAN_W + 1);
   // exponent of an empty accumulator or zero product: below any real product
   localparam ACC_W = LGUARD_W + 1 + 2 * MAN_W + RGUARD_W;
   // Accumulator exponent: signed, two bits wider than the format's, and wider still for
   // exponents under 5 bits, so that it holds the sum of at least 2**16 products of the
   // largest magnitude (its range above the largest product is 2**(XE+EXP_W-1))
   localparam XE = EXP_W < 5 ? 5 - EXP_W : 0;
   localparam AE_W = EXP_W + 2 + XE;
   localparam [AE_W-1:0] EXP_ZERO = -(2 ** EXP_W + 2 * MAN_W);

   reg                  valid_d1;
   reg  [   AE_W-1:0]   acc_exp_reg;
   reg  [ACC_W+EXTRA:0] acc_man_reg;

   // Exact product of the normalized significands, in two's complement
   wire [   LZ_W-1:0] a_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_a (
      .data_in (op_a_man),
      .data_out(a_lz)
   );
   wire [LZ_W-1:0] b_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (op_b_man),
      .data_out(b_lz)
   );
   wire [MAN_W-1:0] a_man = op_a_man << a_lz;
   wire [MAN_W-1:0] b_man = op_b_man << b_lz;

   wire mul_sign = op_a_sign ^ op_b_sign;
   wire mul_zero = ~(|a_man & |b_man);
   // a zero product must not take part in the alignment
   wire [AE_W-1:0] mul_exp = mul_zero ? EXP_ZERO :
      {{(AE_W - EXP_W) {1'b0}}, op_a_exp} + {{(AE_W - EXP_W) {1'b0}}, op_b_exp} - BIAS - a_lz - b_lz;
   wire [2*MAN_W-1:0] mul_man = a_man * b_man;
   wire [2*MAN_W-1:0] mul_man_c_ = mul_man ^ {(2 * MAN_W) {mul_sign}};
   wire [ACC_W+EXTRA:0] mul_man_c = {
      {(LGUARD_W + 2) {mul_sign}}, mul_man_c_, {(RGUARD_W + EXTRA) {mul_sign}}
   };

   // Feedback: the accumulator rounded to nearest, ties to even, dropping the EXTRA low
   // bits, then shifted by one bit right or left, or cleared by the first product
   wire acc_rnd = acc_man_reg[EXTRA-1] & (acc_man_reg[EXTRA] | (|acc_man_reg[EXTRA-2:0]));
   wire [ACC_W:0] acc_fb = acc_man_reg[ACC_W+EXTRA:EXTRA] + {{ACC_W{1'b0}}, acc_rnd};
   wire ovf = ^acc_man_reg[ACC_W+EXTRA-:2];
   wire undf = (~^acc_man_reg[ACC_W+EXTRA-1-:2]) & (|acc_man_reg);
   wire [AE_W-1:0] fb_exp = ~valid_d1 ? EXP_ZERO :
      ovf ? acc_exp_reg + 1'b1 :
      undf ? acc_exp_reg - 1'b1 :
      acc_exp_reg;
   wire [ACC_W+1:0] fb_man_hi =
      ~valid_d1 ? {(ACC_W + 2) {1'b0}} :
      ovf ? {acc_man_reg[ACC_W+EXTRA], acc_fb} :
      undf ? {acc_fb[ACC_W-1:0], 2'b00} :
      {acc_fb, 1'b0};

   // Alignment of the smaller addend, with a sticky bit
   wire comp = $signed(mul_exp) >= $signed(fb_exp);  // exponents can be negative
   wire [AE_W-1:0] big_exp = comp ? mul_exp : fb_exp;
   wire [AE_W-1:0] small_exp = comp ? fb_exp : mul_exp;
   wire [ACC_W+EXTRA:0] big_man = comp ? mul_man_c : {fb_man_hi, {(EXTRA - 1) {1'b0}}};
   // a negative product that is the smaller addend is aligned as a magnitude and negated
   // after the shift (sticky included), so the carry-in completes its two's complement
   // (the smaller addend has EXTRA - 1 low zero bits, which are not shifted)
   wire [ACC_W+1:0] small_man = comp ? fb_man_hi :
      {{(LGUARD_W + 2) {1'b0}}, mul_man, {(RGUARD_W + 1) {1'b0}}};
   wire inv = ~comp & mul_sign;

   localparam STICKY_BITS = ACC_W + EXTRA + 2;
   localparam SH_W = $clog2(STICKY_BITS + 1);
   wire [AE_W-1:0] diff_exp = big_exp - small_exp;
   wire [SH_W-1:0] shift = (diff_exp > STICKY_BITS) ? STICKY_BITS[SH_W-1:0] : diff_exp[SH_W-1:0];
   wire [ACC_W+1+STICKY_BITS:0] small_in = $signed({small_man, {STICKY_BITS{1'b0}}}) >>> shift;
   wire sticky = |small_in[STICKY_BITS+1-EXTRA:0];
   wire [ACC_W+EXTRA:0] small_al = {small_in[STICKY_BITS+2-EXTRA+:ACC_W+EXTRA], sticky};

   // Accumulation; the +1 of a negative product's two's complement is the carry-in
   wire [ACC_W+EXTRA:0] acc_man = big_man + (small_al ^ {(ACC_W + EXTRA + 1) {inv}}) +
      {{(ACC_W + EXTRA) {1'b0}}, mul_sign};

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc_exp_reg <= {AE_W{1'b0}};
         acc_man_reg <= {(ACC_W + 1 + EXTRA) {1'b0}};
         valid_d1    <= 1'b0;
      end else begin
         if (valid_i) begin
            acc_exp_reg <= big_exp;
            acc_man_reg <= acc_man;
         end
         valid_d1 <= valid_i;
      end
   end

   // Special cases over the stream
   wire term_nan = op_a_nan | op_b_nan | (op_a_inf & op_b_zero) | (op_a_zero & op_b_inf);
   wire term_inf = (op_a_inf | op_b_inf) & ~term_nan;
   wire term_sign = op_a_sign ^ op_b_sign;
   wire term_zero = (op_a_zero | op_b_zero) & ~term_nan;
   wire [4:0] term_flags = {
      term_zero & ~term_sign, term_zero & term_sign, term_inf & term_sign, term_inf & ~term_sign,
      term_nan
   };

   reg  [4:0] acc_flags;
   wire [4:0] acc_merge = {acc_flags[4:3] & term_flags[4:3], acc_flags[2:0] | term_flags[2:0]};
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc_flags <= 5'b00000;
      end else if (valid_i) begin
         // NaN and infinities are sticky; a signed zero needs every term to be a zero of
         // that sign, so the result keeps that sign in every rounding mode
         acc_flags <= valid_d1 ? acc_merge : term_flags;
      end
   end

   wire res_nan = acc_flags[0] | (acc_flags[1] & acc_flags[2]);
   wire special = (SPECIAL_CASES != 0) & (|acc_flags);
   // a NaN, -0 or +0 for streams of signed zeros, or an infinity
   wire res_zero = acc_flags[3] | acc_flags[4];
   assign res_special = {
      ~special ? 2'b00 : res_nan ? 2'b01 : res_zero ? 2'b11 : 2'b10,
      acc_flags[3] | (~acc_flags[4] & acc_flags[2])
   };

   // End of a stream: the normalized accumulator
   assign valid_o  = valid_d1 & ~valid_i;
   assign res_sign = acc_man_reg[ACC_W+EXTRA];

   // exponent at which the normalized result has the subnormal exponent (1)
   localparam EXP_MIN = -(LGUARD_W + 2);
   localparam RSHIFT_LIM = MAN_W + 2;
   localparam LSC_W = $clog2(ACC_W + EXTRA + 2);
   localparam OFFSET = LGUARD_W + 4;  // the top accumulator bit has weight 2**(OFFSET-1)

   // the leading sign bits of the accumulator are the leading zeros of its XOR with the sign
   wire [LSC_W-1:0] lsc;
   cls #(
      .DATA_W(ACC_W + EXTRA + 1)
   ) cls0 (
      .data_in (acc_man_reg ^ {(ACC_W + EXTRA + 1) {res_sign}}),
      .data_out(lsc)
   );

   wire [AE_W-1:0] exp_diff = EXP_MIN[AE_W-1:0] - acc_exp_reg + lsc;
   wire [AE_W-1:0] exp_diff2 = EXP_MIN[AE_W-1:0] - acc_exp_reg;
   wire [AE_W-1:0] exp_diff2_1 = acc_exp_reg - EXP_MIN[AE_W-1:0];
   wire [AE_W-1:0] lshift = exp_diff[AE_W-1] ? lsc : exp_diff2_1;

   // right shift of a result below the subnormal exponent; the accumulator's exponent is
   // that low in the small formats only for a zero sum, so the shift is not a named wire
   localparam RSH_W = $clog2(RSHIFT_LIM + 1);
   wire [ACC_W+EXTRA+RSHIFT_LIM:0] man_rsht = $signed({acc_man_reg, {RSHIFT_LIM{1'b0}}}) >>>
      ((exp_diff2 > RSHIFT_LIM) ? RSHIFT_LIM[RSH_W-1:0] : exp_diff2[RSH_W-1:0]);
   wire [ACC_W+EXTRA:0] man_rsht_st = {
      man_rsht[ACC_W+EXTRA+RSHIFT_LIM:RSHIFT_LIM+1], |man_rsht[RSHIFT_LIM:0]
   };
   wire [ACC_W+EXTRA:0] man_norm = exp_diff2[AE_W-1] ? acc_man_reg << lshift : man_rsht_st;

   // the result's exponent, never negative; with a wider accumulator exponent (XE > 0),
   // from 2**(EXP_W+1)-1 up it saturates at 2**(EXP_W+1)-2, an overflow for pack that a
   // rounding carry cannot wrap
   function [EXP_W:0] res_exp_f(input [AE_W-1:0] acc_exp, input [AE_W-1:0] lsh);
      reg [AE_W-1:0] e;
      begin
         e = acc_exp - lsh + (OFFSET - 1);
         res_exp_f = (XE > 0 && (e[AE_W-1:EXP_W+1] != 0 || &e[EXP_W:0])) ?
            {{EXP_W{1'b1}}, 1'b0} : e[EXP_W:0];
      end
   endfunction
   assign res_exp = res_exp_f(acc_exp_reg, lshift);
   assign res_man = {
      man_norm[ACC_W+EXTRA-:MAN_W+EXTRA-1], |man_norm[ACC_W+EXTRA-(MAN_W+EXTRA-1):0]
   };

endmodule
