`timescale 1ns / 1ps

module norm #(
   parameter DATA_W = 32,
   parameter EXP_W  = 8,
   parameter MAN_W  = DATA_W - EXP_W,
   // mantissa input width; the top bit has weight 2
   parameter IN_W   = 2 * MAN_W,
   // 1: exp_i is signed, EXP_W+2 bits, and a result below exponent 1 is shifted
   // right to a subnormal; 0: exp_i is unsigned, EXP_W bits and never below 1 (fadd)
   parameter RSHIFT = 1,
   // top bits examined by the leading-sign count, which bounds the left shift
   parameter LZC_W  = IN_W
) (
   input clk,
   input rst,

   input      valid_i,
   output reg valid_o,

   input               sign_i,
   input [(RSHIFT != 0 ? EXP_W + 2 : EXP_W)-1:0] exp_i,
   input [   IN_W-1:0] man_i,

   input      [       2:0] res_special_i,  // special result code, as in pack
   output reg [       2:0] res_special_o,

   output reg               sign_o,
   // never negative: EXP_W+1 bits, or EXP_W with RSHIFT=0
   output reg [(RSHIFT != 0 ? EXP_W + 1 : EXP_W)-1:0] exp_o,
   output reg [MAN_W+3-1:0] man_o
);

   localparam EXTRA = 3;

   // the top mantissa bit has weight 2
   localparam OFFSET = 2;
   localparam EXP_MIN = 0;
   localparam RSHIFT_LIM = MAN_W + 2;
   localparam RSH_W = $clog2(RSHIFT_LIM + 1);

   // Normalize
   localparam LSC_W = $clog2(LZC_W + 1);

   wire [LSC_W-1:0] lsc;
   cls #(
      .DATA_W(LZC_W)
   ) cls0 (
      .data_in (man_i[IN_W-1-:LZC_W]),
      .data_out(lsc)
   );

   // exp_norm = exp_i - lshift + OFFSET - 1, with the left shift limited so that a
   // subnormal result keeps exponent 1
   localparam EXP_O_W = RSHIFT != 0 ? EXP_W + 1 : EXP_W;
   wire [EXP_O_W-1:0] exp_adjust;
   wire [ IN_W-1:0] man_norm;
   generate
      if (RSHIFT != 0) begin : gen_rshift
         wire [EXP_W+1:0] exp_diff = EXP_MIN[EXP_W+1:0] - exp_i + lsc;
         wire [EXP_W+1:0] exp_diff2 = EXP_MIN[EXP_W+1:0] - exp_i;

         wire [  EXP_W:0] lshift = exp_diff[EXP_W+1] ? lsc : exp_i[EXP_W:0] - EXP_MIN[EXP_W:0];
         // never negative and below 2**(EXP_W+1), so computed in EXP_W+1 bits
         wire [  EXP_W:0] exp_norm = exp_i[EXP_W:0] - lshift + (OFFSET - 1);
         wire [ IN_W-1:0] man_lsht = man_i << lshift[LSC_W-1:0];

         // Right shift to a subnormal result
         wire [RSH_W-1:0] rshift = (exp_diff2 > RSHIFT_LIM) ? RSHIFT_LIM[RSH_W-1:0] :
            exp_diff2[RSH_W-1:0];
         wire [IN_W+RSHIFT_LIM-1:0] man_rsht = {man_i, {RSHIFT_LIM{1'b0}}} >> rshift;
         wire [IN_W-1:0] man_rsht_st = {
            man_rsht[IN_W+RSHIFT_LIM-1:RSHIFT_LIM+1], |man_rsht[RSHIFT_LIM:0]
         };
         assign man_norm   = exp_diff2[EXP_W+1] ? man_lsht : man_rsht_st;
         assign exp_adjust = exp_norm;
      end else begin : gen_no_rshift
         // exp_i >= 1: shift by lsc, or by exp_i when that is smaller
         wire [LSC_W-1:0] lshift = (lsc < exp_i) ? lsc : exp_i[LSC_W-1:0];
         assign man_norm   = man_i << lshift;
         // at most 2**EXP_W-1: the largest exponent plus one carry
         assign exp_adjust = exp_i - lshift + (OFFSET - 1);
      end
   endgenerate

   wire [MAN_W+EXTRA-1:0] man_adjust = {
      man_norm[IN_W-1-:MAN_W+EXTRA-1], |man_norm[IN_W-MAN_W-EXTRA:0]
   };

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res_special_o <= 3'd0;

         sign_o        <= 1'b0;
         exp_o         <= {EXP_O_W{1'b0}};
         man_o         <= {(MAN_W + EXTRA) {1'b0}};

         valid_o       <= 1'b0;
      end else begin
         res_special_o <= res_special_i;

         sign_o        <= sign_i;
         exp_o         <= exp_adjust;
         man_o         <= man_adjust;

         valid_o       <= valid_i;
      end
   end

endmodule
