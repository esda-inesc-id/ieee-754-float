`timescale 1ns / 1ps

module norm
  #(
    parameter DATA_W = 32,
    parameter EXP_W = 8
    )
   (
    input                        clk,
    input                        rst,

    input                        start,
    output reg                   done,

    input                        sign_i,
    input [EXP_W+1:0]            exp_i,
    input [2*MAN_W-1:0]          man_i,
    input                        inv_i,
    input [EXP_W+1:0]            offset,

    output reg                   sign_o,
    output reg [EXP_W+1:0]       exp_o,
    output reg [MAN_W+EXTRA-1:0] man_o,
    output reg                   inv_o
    );

   localparam MAN_W = DATA_W-EXP_W;
   localparam BIAS  = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;

   localparam EXP_MIN = 0;
   localparam RSHIFT_LIM = MAN_W+2;

   // Normalize
   localparam LSC_W  = $clog2(2*MAN_W+1);

   wire [LSC_W-1:0] lzc;
   cls #(
         .DATA_W(2*MAN_W)
         )
   cls0
     (
      .data_in  (man_i),
      .symbol   (inv_i),
      .data_out (lzc)
      );

   wire [EXP_W+1:0]        exp_diff  = EXP_MIN - exp_i + lzc;
   wire [EXP_W+1:0]        exp_diff2 = EXP_MIN - exp_i;
   wire [EXP_W+1:0]        exp_diff2_1 = exp_i - EXP_MIN;

   wire [EXP_W+1:0]        lshift = exp_diff[EXP_W+1]? lzc: exp_diff2_1;
   wire [EXP_W+1:0]        lshift_inv = ~lshift;

   wire [EXP_W+1:0]        rshift = (exp_diff2 > RSHIFT_LIM)? RSHIFT_LIM: exp_diff2;
   wire [2*MAN_W+RSHIFT_LIM-1:0] man_rsht = {man_i, {RSHIFT_LIM{1'b0}}} >> rshift;

   wire [EXP_W+1:0]        exp_norm = exp_diff2[EXP_W+1]? exp_i + lshift_inv + offset:
                                                          1'b0;
   wire [2*MAN_W-1:0]      man_norm = exp_diff2[EXP_W+1]? man_i << lshift:
                                                          {man_rsht[2*MAN_W+RSHIFT_LIM-1:RSHIFT_LIM+1], |man_rsht[RSHIFT_LIM:0]};

   wire [EXP_W+1:0]        exp_adjust = exp_norm;
   wire [MAN_W+EXTRA-1:0]  man_adjust = {man_norm[2*MAN_W-1 -: MAN_W+EXTRA-1], |man_norm[MAN_W-EXTRA:0]};

   always @(posedge clk) begin
      if (rst) begin
         sign_o <= 1'b0;
         exp_o <= {(EXP_W+2){1'b0}};
         man_o <= {(MAN_W+EXTRA){1'b0}};

         inv_o <= 1'b0;

         done <= 1'b0;
      end else begin
         sign_o <= sign_i;
         exp_o <= exp_adjust;
         man_o <= man_adjust;

         inv_o <= inv_i;

         done <= start;
      end
   end

endmodule
