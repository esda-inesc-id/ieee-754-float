`timescale 1ns / 1ps

// Fused multiply-add datapath: a*b + c with one rounding (in pack). The exact product
// and c are aligned as magnitudes, the smaller one with a sticky bit, then added in two's
// complement and normalized as in fmac_core.
module ffma_core #(
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
   input             op_a_nan,
   input             op_a_inf,
   input             op_a_zero,

   input             op_b_sign,
   input [EXP_W-1:0] op_b_exp,
   input [MAN_W-1:0] op_b_man,
   input             op_b_nan,
   input             op_b_inf,
   input             op_b_zero,

   input             op_c_sign,
   input [EXP_W-1:0] op_c_exp,
   input [MAN_W-1:0] op_c_man,
   input             op_c_nan,
   input             op_c_inf,
   input             op_c_zero,

   // special result code {kind, sign}, as in pack
   output [       2:0] res_special,

   output reg               res_sign,
   // never negative and below 2**(EXP_W+1)
   output reg [    EXP_W:0] res_exp,
   output reg [MAN_W+3-1:0] res_man
);

   localparam EXTRA = 3;
   localparam LGUARD_W = 0;
   localparam ACC_W = 2 * MAN_W + 1;

   localparam BIAS = 2 ** (EXP_W - 1) - 1;
   localparam LZ_W = $clog2(MAN_W + 1);
   // exponent of a zero term: below any real one
   localparam [EXP_W+1:0] EXP_ZERO = -(2 ** EXP_W + 2 * MAN_W);

   // Normalize the significands, so that subnormal operands keep full precision
   wire [LZ_W-1:0] A_lz, B_lz, C_lz;
   cls #(
      .DATA_W(MAN_W)
   ) cls_a (
      .data_in (op_a_man),
      .data_out(A_lz)
   );
   cls #(
      .DATA_W(MAN_W)
   ) cls_b (
      .data_in (op_b_man),
      .data_out(B_lz)
   );
   cls #(
      .DATA_W(MAN_W)
   ) cls_c (
      .data_in (op_c_man),
      .data_out(C_lz)
   );

   // pipeline stage 1
   reg [LZ_W-1:0] A_lz_reg, B_lz_reg, C_lz_reg;
   reg A_sign_reg, B_sign_reg, C_sign_reg;
   reg [EXP_W-1:0] A_exp_reg1, B_exp_reg1, C_exp_reg1;
   reg [MAN_W-1:0] A_man_reg1, B_man_reg1, C_man_reg1;
   reg valid_d1;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_lz_reg   <= {LZ_W{1'b0}};
         B_lz_reg   <= {LZ_W{1'b0}};
         C_lz_reg   <= {LZ_W{1'b0}};
         A_sign_reg <= 1'b0;
         B_sign_reg <= 1'b0;
         C_sign_reg <= 1'b0;
         A_exp_reg1 <= {EXP_W{1'b0}};
         B_exp_reg1 <= {EXP_W{1'b0}};
         C_exp_reg1 <= {EXP_W{1'b0}};
         A_man_reg1 <= {MAN_W{1'b0}};
         B_man_reg1 <= {MAN_W{1'b0}};
         C_man_reg1 <= {MAN_W{1'b0}};
         valid_d1   <= 1'b0;
      end else begin
         A_lz_reg   <= A_lz;
         B_lz_reg   <= B_lz;
         C_lz_reg   <= C_lz;
         A_sign_reg <= op_a_sign;
         B_sign_reg <= op_b_sign;
         C_sign_reg <= op_c_sign;
         A_exp_reg1 <= op_a_exp;
         B_exp_reg1 <= op_b_exp;
         C_exp_reg1 <= op_c_exp;
         A_man_reg1 <= op_a_man << A_lz;
         B_man_reg1 <= op_b_man << B_lz;
         C_man_reg1 <= op_c_man << C_lz;
         valid_d1   <= valid_i;
      end
   end

   // Multiplication, and c as the product c*1.0
   wire mul_zero = ~(|A_man_reg1 & |B_man_reg1);
   wire [EXP_W+1:0] mul_exp = mul_zero ? EXP_ZERO :
      {2'd0, A_exp_reg1} + {2'd0, B_exp_reg1} - BIAS - A_lz_reg - B_lz_reg;
   wire [2*MAN_W-1:0] mul_man = A_man_reg1 * B_man_reg1;
   wire [EXP_W+1:0] c_exp = ~|C_man_reg1 ? EXP_ZERO : {2'd0, C_exp_reg1} - C_lz_reg;

   // pipeline stage 2
   reg P_sign_reg, Q_sign_reg;
   reg [EXP_W+1:0] P_exp_reg, Q_exp_reg;
   reg [2*MAN_W-1:0] P_man_reg;
   // c's significand; as a product c*1.0 it is {1'b0, Q_man_reg, MAN_W-1 zeros}
   reg [MAN_W-1:0] Q_man_reg;
   reg valid_d2;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         P_sign_reg <= 1'b0;
         Q_sign_reg <= 1'b0;
         P_exp_reg  <= {(EXP_W + 2) {1'b0}};
         Q_exp_reg  <= {(EXP_W + 2) {1'b0}};
         P_man_reg  <= {(2 * MAN_W) {1'b0}};
         Q_man_reg  <= {MAN_W{1'b0}};
         valid_d2   <= 1'b0;
      end else begin
         P_sign_reg <= A_sign_reg ^ B_sign_reg;
         Q_sign_reg <= C_sign_reg;
         P_exp_reg  <= mul_exp;
         Q_exp_reg  <= c_exp;
         P_man_reg  <= mul_man;
         Q_man_reg  <= C_man_reg1;
         valid_d2   <= valid_d1;
      end
   end

   // Alignment of the magnitudes: the smaller term is shifted right with a sticky bit
   wire comp = $signed(P_exp_reg) >= $signed(Q_exp_reg);
   wire [EXP_W+1:0] big_exp = comp ? P_exp_reg : Q_exp_reg;
   wire [EXP_W+1:0] diff_exp = comp ? P_exp_reg - Q_exp_reg : Q_exp_reg - P_exp_reg;
   wire [2*MAN_W-1:0] big_m = comp ? P_man_reg : {1'b0, Q_man_reg, {(MAN_W - 1) {1'b0}}};
   wire [2*MAN_W-1:0] small_m = comp ? {1'b0, Q_man_reg, {(MAN_W - 1) {1'b0}}} : P_man_reg;
   wire big_sign = comp ? P_sign_reg : Q_sign_reg;
   wire small_sign = comp ? Q_sign_reg : P_sign_reg;

   // in the word, the terms sit EXTRA bits above its least significant bit; a shift of
   // SH_MAX or more leaves only the sticky bit
   localparam SH_MAX = 2 * MAN_W + EXTRA + 1;
   localparam SH_W = $clog2(SH_MAX + 1);
   wire [SH_W-1:0] shift = (diff_exp > SH_MAX) ? SH_MAX[SH_W-1:0] : diff_exp[SH_W-1:0];
   wire [2*MAN_W+SH_MAX-1:0] small_in = {small_m, {SH_MAX{1'b0}}} >> shift;
   wire sticky = |small_in[SH_MAX-EXTRA:0];
   wire [ACC_W+EXTRA:0] small_al = {
      2'b00, small_in[2*MAN_W+SH_MAX-1:SH_MAX-EXTRA+1], sticky
   };

   // pipeline stage 3: the terms in one's complement, completed by the carries
   reg [EXP_W+1:0] S_exp_reg;
   reg [ACC_W+EXTRA:0] S_a_reg, S_b_reg;
   reg cin_a, cin_b, valid_d3;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         S_exp_reg <= {(EXP_W + 2) {1'b0}};
         S_a_reg   <= {(ACC_W + EXTRA + 1) {1'b0}};
         S_b_reg   <= {(ACC_W + EXTRA + 1) {1'b0}};
         cin_a     <= 1'b0;
         cin_b     <= 1'b0;
         valid_d3  <= 1'b0;
      end else begin
         S_exp_reg <= big_exp;
         S_a_reg   <= {2'b00, big_m, {EXTRA{1'b0}}} ^ {(ACC_W + EXTRA + 1) {big_sign}};
         S_b_reg   <= small_al ^ {(ACC_W + EXTRA + 1) {small_sign}};
         cin_a     <= big_sign;
         cin_b     <= small_sign;
         valid_d3  <= valid_d2;
      end
   end

   // Addition, in two's complement
   wire [ACC_W+EXTRA:0] acc_man = S_a_reg + S_b_reg + cin_a + cin_b;

   // pipeline stage 4
   reg [EXP_W+1:0] acc_exp_reg;
   reg [ACC_W+EXTRA:0] acc_man_reg;
   reg valid_d4;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc_exp_reg <= {(EXP_W + 2) {1'b0}};
         acc_man_reg <= {(ACC_W + 1 + EXTRA) {1'b0}};
         valid_d4    <= 1'b0;
      end else begin
         acc_exp_reg <= S_exp_reg;
         acc_man_reg <= acc_man;
         valid_d4    <= valid_d3;
      end
   end

   // Special cases, aligned with the result
   localparam SPECIAL_DELAY = 5;
   wire p_nan = op_a_nan | op_b_nan | (op_a_inf & op_b_zero) | (op_a_zero & op_b_inf);
   wire p_inf = (op_a_inf | op_b_inf) & ~p_nan;
   wire p_sign = op_a_sign ^ op_b_sign;
   wire p_zero = (op_a_zero | op_b_zero) & ~p_nan;
   // {+0, -0, -inf, +inf, NaN}: a zero needs both terms to be zeros of that sign
   wire [4:0] flags = {
      p_zero & ~p_sign & op_c_zero & ~op_c_sign, p_zero & p_sign & op_c_zero & op_c_sign,
      (p_inf & p_sign) | (op_c_inf & op_c_sign), (p_inf & ~p_sign) | (op_c_inf & ~op_c_sign),
      p_nan | op_c_nan
   };
   reg [5*SPECIAL_DELAY-1:0] flags_pipe;
   always @(posedge clk, posedge rst) begin
      if (rst) flags_pipe <= {(5 * SPECIAL_DELAY) {1'b0}};
      else flags_pipe <= {flags_pipe[5*SPECIAL_DELAY-6:0], flags};
   end

   wire [4:0] res_flags = flags_pipe[5*SPECIAL_DELAY-1-:5];
   wire       res_nan = res_flags[0] | (res_flags[1] & res_flags[2]);

   wire       special = (SPECIAL_CASES != 0) & (|res_flags);
   // a NaN, -0 or +0 when both terms are zeros of one sign, or an infinity
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
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res_sign <= 1'b0;
         res_exp  <= {(EXP_W + 1) {1'b0}};
         res_man  <= {(MAN_W + EXTRA) {1'b0}};
         valid_o  <= 1'b0;
      end else begin
         res_sign <= res_sign_int;
         res_exp  <= exp_adjust;
         res_man  <= man_adjust;
         valid_o  <= valid_d4;
      end
   end


endmodule
