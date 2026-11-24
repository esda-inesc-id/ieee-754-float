`timescale 1ns / 1ps

module norm #(
   parameter DATA_W = 32,
   parameter EXP_W  = 8,
   parameter MAN_W  = DATA_W - EXP_W,
   // mantissa input width; the top bit has weight 2
   parameter IN_W   = 2 * MAN_W,
   // 0 when exp_i is never below 1, which removes the subnormal right shift
   parameter RSHIFT = 1,
   // top bits examined by the leading-sign count, which bounds the left shift
   parameter LZC_W  = IN_W
) (
   input clk,
   input rst,

   input      valid_i,
   output reg valid_o,

   input               sign_i,
   input [  EXP_W+1:0] exp_i,
   input [   IN_W-1:0] man_i,
   input               inv_i,
   input               nsub_i,

   input                   special_i,
   input      [DATA_W-1:0] res_special_i,
   output reg              special_o,
   output reg [DATA_W-1:0] res_special_o,

   output reg               sign_o,
   output reg [  EXP_W+1:0] exp_o,
   output reg [MAN_W+3-1:0] man_o,
   output reg               inv_o,
   output reg               nsub_o
);

   localparam EXTRA = 3;

   // the top mantissa bit has weight 2
   localparam OFFSET = 2;
   localparam EXP_MIN = 0;
   localparam RSHIFT_LIM = MAN_W + 2;

   // Normalize
   localparam LSC_W = $clog2(LZC_W + 1);

   wire [LSC_W-1:0] lsc;
   cls #(
      .DATA_W(LZC_W)
   ) cls0 (
      .data_in (man_i[IN_W-1-:LZC_W]),
      .symbol  (inv_i),
      .data_out(lsc)
   );

   wire [EXP_W+1:0] exp_diff = EXP_MIN[EXP_W+1:0] - exp_i + lsc;
   wire [EXP_W+1:0] exp_diff2 = EXP_MIN[EXP_W+1:0] - exp_i;
   wire [EXP_W+1:0] exp_diff2_1 = exp_i - EXP_MIN[EXP_W+1:0];

   wire [EXP_W+1:0] lshift = exp_diff[EXP_W+1] ? lsc : exp_diff2_1;
   wire [EXP_W+1:0] lshift_inv = ~lshift;

   wire [EXP_W+1:0] rshift_lim = RSHIFT_LIM[EXP_W+1:0];
   wire [EXP_W+1:0] rshift = (exp_diff2 > rshift_lim) ? rshift_lim : exp_diff2;
   wire [IN_W+RSHIFT_LIM-1:0] man_rsht = {man_i, {RSHIFT_LIM{1'b0}}} >> rshift;

   wire [EXP_W+1:0] exp_norm = exp_i + lshift_inv + OFFSET[EXP_W+1:0];
   wire [IN_W-1:0] man_rsht_st = {
      man_rsht[IN_W+RSHIFT_LIM-1:RSHIFT_LIM+1], |man_rsht[RSHIFT_LIM:0]
   };
   wire [IN_W-1:0] man_norm = (RSHIFT == 0 || exp_diff2[EXP_W+1]) ? man_i << lshift[LSC_W-1:0] : man_rsht_st;

   wire [EXP_W+1:0] exp_adjust = exp_norm;
   wire [MAN_W+EXTRA-1:0] man_adjust = {
      man_norm[IN_W-1-:MAN_W+EXTRA-1], |man_norm[IN_W-MAN_W-EXTRA:0]
   };

   always @(posedge clk, posedge rst) begin
      if (rst) begin
         special_o     <= 1'b0;
         res_special_o <= {DATA_W{1'b0}};

         sign_o        <= 1'b0;
         exp_o         <= {(EXP_W + 2) {1'b0}};
         man_o         <= {(MAN_W + EXTRA) {1'b0}};

         inv_o         <= 1'b0;
         nsub_o        <= 1'b0;

         valid_o       <= 1'b0;
      end else begin
         special_o     <= special_i;
         res_special_o <= res_special_i;

         sign_o        <= sign_i;
         exp_o         <= exp_adjust;
         man_o         <= man_adjust;

         inv_o         <= inv_i;
         nsub_o        <= nsub_i;

         valid_o       <= valid_i;
      end
   end

endmodule
