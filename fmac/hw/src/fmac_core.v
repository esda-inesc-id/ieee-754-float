`timescale 1ns / 1ps

module fmac_core #(
   parameter EXP_W         = 8,
   parameter MAN_W         = 24,
   parameter SPECIAL_CASES = 1,
   parameter LGUARD_W      = 0,
   parameter RGUARD_W      = 0,
   // largest left normalization shift of the accumulator per accumulation: 1, or up to
   // LGUARD_W + 2 * MAN_W + RGUARD_W + 3 for full normalization (architecture studies)
   parameter STEP          = 1
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

   // special result code {kind, sign}, as in pack
   output [       2:0] res_special,

   output reg               res_sign,
   // never negative and below 2**(EXP_W+1)
   output reg [    EXP_W:0] res_exp,
   output reg [MAN_W+3-1:0] res_man
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
      .data_out(A_lz)
   );

   wire [LZ_W-1:0] B_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (op_b_man),
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
   // a zero product must not take part in the alignment
   wire [EXP_W+1:0] mul_exp = mul_zero ? EXP_ZERO :
      {2'd0, A_Exponent_reg} + {2'd0, B_Exponent_reg} - BIAS - A_lz_reg - B_lz_reg;
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
   // the EXTRA-1 bits below the rounded accumulator are zero and not stored
   reg [ACC_W+1:0] acc_man_reg2;

   // Feedback rounded to nearest, ties to even, dropping the EXTRA low bits
   wire acc_rnd = acc_man_reg[EXTRA-1] & (acc_man_reg[EXTRA] | (|acc_man_reg[EXTRA-2:0]));
   wire [ACC_W:0] acc_fb = acc_man_reg[ACC_W+EXTRA:EXTRA] + {{ACC_W{1'b0}}, acc_rnd};

   wire [EXP_W+1:0] A_exp_int = valid_d2 ? mul_exp_reg : acc_exp_reg2;
   wire [ACC_W+EXTRA:0] A_man_int = valid_d2 ? mul_man_c : {acc_man_reg2, {(EXTRA - 1) {1'b0}}};

   wire cin_int = valid_d2 & mul_sign_reg;

   // The first two products of a stream start the even and odd accumulators from zero
   reg valid_d3, valid_d4;
   wire acc_clr = (valid_d2 & ~valid_d3) | (valid_d3 & ~valid_d4);

   wire ovf_int = ^acc_man_reg[ACC_W+EXTRA-:2];
   wire undf_int = (~^acc_man_reg[ACC_W+EXTRA-1-:2]) & (|acc_man_reg);

   // left normalization: 1 bit, or up to STEP bits keeping two sign bits
   localparam STEP_LZ_W = $clog2(STEP + 2);
   wire [EXP_W+1:0] acc_exp_lsh;
   wire [ACC_W+1:0] acc_man_lsh;
   generate
      if (STEP == 1) begin : gen_step1
         assign acc_exp_lsh = acc_exp_reg - 1'b1;
         assign acc_man_lsh = {acc_fb[ACC_W-1:0], 2'b00};
      end else begin : gen_step
         // leading bits equal to the sign below it, within STEP + 1 bits
         wire [STEP_LZ_W-1:0] step_lz;
         cls #(
            .DATA_W(STEP + 1)
         ) cls_step (
            .data_in (acc_man_reg[ACC_W+EXTRA-1-:STEP+1] ^ {(STEP + 1) {acc_man_reg[ACC_W+EXTRA]}}),
            .data_out(step_lz)
         );
         wire [STEP_LZ_W-1:0] step_sh = step_lz - 1'b1;
         assign acc_exp_lsh = acc_exp_reg - step_sh;
         assign acc_man_lsh = {acc_fb, 1'b0} << step_sh;
      end
   endgenerate

   wire [EXP_W+1:0] B_exp_int = acc_clr ? EXP_ZERO :
      ovf_int ? acc_exp_reg + 1'b1 :
      undf_int ? acc_exp_lsh :
      acc_exp_reg;
   wire [ACC_W+1:0] B_man_hi =
      acc_clr ? {(ACC_W + 2) {1'b0}} :
      ovf_int ? {acc_man_reg[ACC_W+EXTRA], acc_fb} :
      undf_int ? acc_man_lsh :
      {acc_fb, 1'b0};

   wire comp = ($signed(
       A_exp_int
   ) >= $signed(
       B_exp_int
   )) ? 1'b1 : 1'b0;  // exponents can be negative

   wire [EXP_W+1:0] A_exp = comp ? A_exp_int : B_exp_int;
   wire [ACC_W+EXTRA:0] A_man = comp ? A_man_int : {B_man_hi, {(EXTRA - 1) {1'b0}}};

   wire [EXP_W+1:0] B_exp = comp ? B_exp_int : A_exp_int;
   wire [ACC_W+EXTRA:0] B_man = comp ? {B_man_hi, {(EXTRA - 1) {1'b0}}} : A_man_int;

   localparam STICKY_BITS = ACC_W + EXTRA + 2;

   // Align significants
   wire [EXP_W+1:0] diff_exp = A_exp - B_exp;
   localparam SH_W = $clog2(STICKY_BITS + 1);
   wire [SH_W-1:0] shift = (diff_exp > STICKY_BITS) ? STICKY_BITS[SH_W-1:0] : diff_exp[SH_W-1:0];
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
         acc_man_reg2 <= {(ACC_W + 2) {1'b0}};
      end else begin
         acc_exp_reg2 <= B_exp_int;
         acc_man_reg2 <= B_man_hi;
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

   wire       special = (SPECIAL_CASES != 0) & (|res_flags);
   // a NaN, -0 or +0 for streams of signed zeros, or an infinity
   wire       res_zero = res_flags[3] | res_flags[4];
   assign res_special = {
      ~special ? 2'b00 : res_nan ? 2'b01 : res_zero ? 2'b11 : 2'b10,
      res_flags[3] | (~res_flags[4] & res_flags[2])
   };

   // Convert final result to sign-magnitude
   wire res_sign_int = acc_man_reg[ACC_W+EXTRA];
   // the leading sign bits of the accumulator are the leading zeros of its XOR with the sign

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
      .data_in (acc_man_reg ^ {(ACC_W + EXTRA + 1) {res_sign_int}}),
      .data_out(lsc)
   );

   wire [EXP_W+1:0] exp_diff = EXP_MIN[EXP_W+1:0] - acc_exp_reg + lsc;
   wire [EXP_W+1:0] exp_diff2 = EXP_MIN[EXP_W+1:0] - acc_exp_reg;
   wire [EXP_W+1:0] exp_diff2_1 = acc_exp_reg - EXP_MIN[EXP_W+1:0];

   wire [EXP_W+1:0] lshift = exp_diff[EXP_W+1] ? lsc : exp_diff2_1;

   localparam RSH_W = $clog2(RSHIFT_LIM + 1);
   wire [RSH_W-1:0] rshift = (exp_diff2 > RSHIFT_LIM) ? RSHIFT_LIM[RSH_W-1:0] :
      exp_diff2[RSH_W-1:0];
   wire [ACC_W+EXTRA+RSHIFT_LIM:0] man_rsht = $signed({acc_man_reg, {RSHIFT_LIM{1'b0}}}) >>> rshift;

   // never negative and below 2**(EXP_W+1), so computed in EXP_W+1 bits
   wire [EXP_W:0] exp_norm = acc_exp_reg[EXP_W:0] - lshift[EXP_W:0] + (OFFSET - 1);
   wire [ACC_W+EXTRA:0] man_rsht_st = {
      man_rsht[ACC_W+EXTRA+RSHIFT_LIM:RSHIFT_LIM+1], |man_rsht[RSHIFT_LIM:0]
   };
   wire [ACC_W+EXTRA:0] man_norm = exp_diff2[EXP_W+1] ? acc_man_reg << lshift : man_rsht_st;

   wire [EXP_W:0] exp_adjust = exp_norm;
   wire [MAN_W+EXTRA-1:0] man_adjust = {
      man_norm[ACC_W+EXTRA-:MAN_W+EXTRA-1], |man_norm[ACC_W+EXTRA-(MAN_W+EXTRA-1):0]
   };

   // pipeline stage 5
   reg valid_d5, valid_d6;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res_sign <= 1'b0;
         res_exp  <= {(EXP_W + 1) {1'b0}};
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


endmodule
