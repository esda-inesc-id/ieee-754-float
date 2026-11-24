`timescale 1ns / 1ps

// Radix-4 SRT divider: a drop-in alternative to fdiv_core.v, with the same ports and
// output format, producing two quotient bits per clock cycle.
//
// NOT TESTED and not in any file list. Before use: add it to fdiv/hw/hw.mk and
// fpu/hw/hw.mk in place of fdiv_core.v (module name fdiv_srt4_core), and run the full tests.
//
// Algorithm (Ercegovac and Lang, Digital Arithmetic, radix-4 SRT with the
// minimally redundant digit set {-2, ..., 2}):
//   d = B/2 in [1/2, 1), w[0] = A/8, so |w[0]| <= 2/3 d
//   w[j+1] = 4 w[j] - q[j+1] d, with the partial remainder w in carry-save form
//   q[j+1] chosen from a 7-bit estimate of 4 w[j] and 3 bits of d
//   q = sum q[j] 4**-j = A / (4 B); a negative final remainder decrements q
// The latency is N + 4 clock cycles in fdiv, N = ceil((MAN_W + 4) / 2): 18 for
// binary32, against MAN_W + 6 = 30 for fdiv_core.v.

module fdiv_srt4_core #(
   parameter DATA_W        = 32,
   parameter EXP_W         = 8,
   parameter MAN_W         = DATA_W - EXP_W,
   parameter SPECIAL_CASES = 1
) (
   input clk,
   input rst,

   input  valid_i,
   output valid_o,

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

   // The results are valid with valid_o and stay until the next valid_i
   // special result code {kind, sign}, as in pack
   output reg [       2:0] res_special,

   output reg             res_sign,
   output reg [EXP_W+1:0] res_exp,
   // quotient bits from weight 1 down to 2**-(MAN_W+2), then the sticky bit; norm
   // reads the top bit as weight 2, so res_exp is one less than the quotient exponent
   output reg [MAN_W+3:0] res_man
);

   localparam EXTRA = 3;

   localparam BIAS = 2 ** (EXP_W - 1) - 1;

   // Special cases
   wire special_int = SPECIAL_CASES & (op_a_nan | op_a_inf | op_b_nan | op_b_inf | op_b_zero);
   wire special_sign = op_a_sign ^ op_b_sign;
   wire special_nan = op_a_nan | op_b_nan | (op_a_inf & op_b_inf) | (op_a_zero & op_b_zero);
   // a NaN, a zero for a zero dividend or a finite number over infinity, or an infinity
   wire [2:0] res_special_int = {
      special_int ? (special_nan ? 2'b01 : op_b_inf ? 2'b11 : 2'b10) : op_a_zero ? 2'b11 : 2'b00,
      special_sign
   };

   // Normalize the significands, so that subnormal operands keep full precision
   localparam LZ_W = $clog2(MAN_W + 1);

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

   wire [MAN_W-1:0] A_Mantissa_norm = op_a_man << A_lz;
   wire [MAN_W-1:0] B_Mantissa_norm = op_b_man << B_lz;

   // Exponent of the quotient
   wire [EXP_W+1:0] exponent = {2'd0, op_a_exp} - {2'd0, op_b_exp} + (BIAS - 1) - A_lz + B_lz;

   // Sign, exponent and special cases, captured with valid_i
   reg  [ EXP_W+1:0] exp_reg;
   reg               sign_reg;
   reg  [       2:0] res_special_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         exp_reg         <= {(EXP_W + 2) {1'b0}};
         sign_reg        <= 1'b0;
         res_special_reg <= 3'd0;
      end else if (valid_i) begin
         exp_reg         <= exponent;
         sign_reg        <= op_a_sign ^ op_b_sign;
         res_special_reg <= res_special_int;
      end
   end

   // Widths: the partial remainder has a sign bit, two integer bits and F fraction
   // bits; N iterations give QB = 2 N quotient bits
   localparam N = (MAN_W + 5) / 2;
   localparam QB = 2 * N;
   localparam F = MAN_W + 2;
   localparam W = F + 3;
   localparam Q_W = MAN_W + EXTRA;
   localparam CNT_W = $clog2(N + 1);

   // w[0] = A/8 and d = B/2, both with F fraction bits
   wire [W-1:0] x_init = {5'b00000, A_Mantissa_norm};
   wire [W-1:0] d_init = {3'b000, B_Mantissa_norm, 2'b00};

   reg  [W-1:0] ws;  // partial remainder, sum word
   reg  [W-1:0] wc;  // partial remainder, carry word
   reg  [W-1:0] d;
   reg  [  2:0] d_idx;  // the three bits of d after its leading 1
   reg  [QB-1:0] qp;  // positive quotient digits
   reg  [QB-1:0] qn;  // magnitudes of the negative quotient digits
   reg  [CNT_W-1:0] cnt;
   reg              busy;
   reg              done;

   // Quotient digit selection from the estimate y of 4 w, in units of 1/16
   wire [6:0] y_u = ws[W-3-:7] + wc[W-3-:7];
   wire signed [6:0] y = y_u;

   reg signed [6:0] m2, m1, m0, mm1;
   always @* begin
      case (d_idx)
         3'd0: begin m2 = 7'sd12; m1 = 7'sd4; m0 = -7'sd4; mm1 = -7'sd13; end
         3'd1: begin m2 = 7'sd14; m1 = 7'sd4; m0 = -7'sd5; mm1 = -7'sd15; end
         3'd2: begin m2 = 7'sd15; m1 = 7'sd4; m0 = -7'sd6; mm1 = -7'sd16; end
         3'd3: begin m2 = 7'sd16; m1 = 7'sd4; m0 = -7'sd6; mm1 = -7'sd18; end
         3'd4: begin m2 = 7'sd18; m1 = 7'sd6; m0 = -7'sd6; mm1 = -7'sd20; end
         3'd5: begin m2 = 7'sd20; m1 = 7'sd6; m0 = -7'sd8; mm1 = -7'sd20; end
         3'd6: begin m2 = 7'sd20; m1 = 7'sd8; m0 = -7'sd8; mm1 = -7'sd22; end
         default: begin m2 = 7'sd24; m1 = 7'sd8; m0 = -7'sd8; mm1 = -7'sd24; end
      endcase
   end

   wire       q_pos = (y >= m1);
   wire       q_neg = (y < m0);
   wire [1:0] q_mag = (y >= m2 || y < mm1) ? 2'd2 : (q_pos || q_neg) ? 2'd1 : 2'd0;

   // w[j+1] = 4 w[j] - q d, with a 3:2 carry-save adder; -q d for a positive digit
   // is the inverted multiple plus one, the 1 entering at the carry LSB
   wire [W-1:0] ws4 = {ws[W-3:0], 2'b00};
   wire [W-1:0] wc4 = {wc[W-3:0], 2'b00};
   wire [W-1:0] qd = (q_mag == 2'd2) ? {d[W-2:0], 1'b0} : (q_mag == 2'd1) ? d : {W{1'b0}};
   wire [W-1:0] t = q_pos ? ~qd : qd;
   wire [W-1:0] ws_next = ws4 ^ wc4 ^ t;
   wire [W-1:0] wc_maj = (ws4 & wc4) | (ws4 & t) | (wc4 & t);
   wire [W-1:0] wc_next = {wc_maj[W-2:0], q_pos};

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         ws    <= {W{1'b0}};
         wc    <= {W{1'b0}};
         d     <= {W{1'b0}};
         d_idx <= 3'd0;
         qp    <= {QB{1'b0}};
         qn    <= {QB{1'b0}};
         cnt   <= {CNT_W{1'b0}};
         busy  <= 1'b0;
         done  <= 1'b0;
      end else if (valid_i) begin
         ws    <= x_init;
         wc    <= {W{1'b0}};
         d     <= d_init;
         d_idx <= B_Mantissa_norm[MAN_W-2-:3];
         qp    <= {QB{1'b0}};
         qn    <= {QB{1'b0}};
         cnt   <= N[CNT_W-1:0];
         busy  <= 1'b1;
         done  <= 1'b0;
      end else begin
         if (busy) begin
            ws   <= ws_next;
            wc   <= wc_next;
            qp   <= {qp[QB-3:0], q_pos ? q_mag : 2'd0};
            qn   <= {qn[QB-3:0], q_neg ? q_mag : 2'd0};
            cnt  <= cnt - 1'b1;
            busy <= (cnt != 1);
         end
         done <= busy & (cnt == 1);
      end
   end

   // Final remainder and quotient: a negative remainder decrements the quotient,
   // and any nonzero remainder sets the sticky bit
   wire [ W-1:0] w_final = ws + wc;
   wire          w_neg = w_final[W-1];
   wire          w_nz = |w_final;
   wire [QB-1:0] q_final = qp - qn - {{(QB - 1) {1'b0}}, w_neg};

   // q = A / (4 B) < 1/2, so the top quotient bit is 0 and the next has weight 1 in
   // A / B; the extra 0 below keeps the sticky slice non-empty
   wire [  QB:0] q_ext = {q_final, 1'b0};

   reg res_valid;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res_sign    <= 1'b0;
         res_exp     <= {(EXP_W + 2) {1'b0}};
         res_man     <= {(MAN_W + 4) {1'b0}};
         res_special <= 3'd0;
         res_valid   <= 1'b0;
      end else begin
         if (done) begin
            res_sign    <= sign_reg;
            res_exp     <= exp_reg;
            res_man     <= {q_ext[QB-1-:Q_W], (|q_ext[QB-1-Q_W:0]) | w_nz};
            res_special <= res_special_reg;
         end
         res_valid   <= done & ~valid_i;
      end
   end

   assign valid_o = res_valid & ~valid_i;

endmodule
