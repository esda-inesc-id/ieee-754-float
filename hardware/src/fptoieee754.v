`timescale 1ns / 1ps

`include "ieee754_defs.vh"

module fptoieee754
  #(
    parameter DATA_W   = 64,
    parameter EXP_W    = 11,
    parameter FP_EXP_W = 16,
    parameter FP_MAN_W = 27
    )
   (
    input                clk,
    input                rst,

    input                start,
    output               done,

    input                sign_i,
    input [FP_EXP_W-1:0] exp_i,
    input [FP_MAN_W-1:0] man_i,

    output [DATA_W-1:0]  data_o
    );

   wire                  done_int;
   assign done_int = start;

   wire [FP_MAN_W-1:0]   man_norm;
`ifdef SUBNORMALS
   localparam LDS_W = $clog2(FP_MAN_W+1);
   wire [LDS_W-1:0]      lds;
   cls
     #(
       .DATA_W(FP_MAN_W)
       )
   cls0
     (
      .data_in  (man_i),
      .symbol   (1'b0),
      .data_out (lds)
      );

   assign man_norm = man_i << lds;
`else
   assign man_norm = man_i[FP_MAN_W-1]? man_i: 1'b0;
`endif

   wire                  overflow;
   wire                  underflow;
   wire [EXP_W+1:0]      exp_int;
   wire [FP_EXP_W+1:0]   shift, mask;
   generate
      if (EXP_W > FP_EXP_W) begin
`ifdef SUBNORMALS
         assign exp_int = {{(EXP_W+2-FP_EXP_W){exp_i[FP_EXP_W-1]}}, exp_i} + `BIAS - {{(EXP_W+2-LDS_W){1'b0}}, lds};
`else
         assign exp_int = {{(EXP_W+2-FP_EXP_W){exp_i[FP_EXP_W-1]}}, exp_i} + `BIAS;
`endif

         assign shift = 1'b0;
         assign mask  = 1'b0;

         assign overflow  = 1'b0;
         assign underflow = 1'b0;
      end else begin
         wire [FP_EXP_W+1:0] exp_int_tmp;
`ifdef SUBNORMALS
         assign exp_int_tmp = {{2{exp_i[FP_EXP_W-1]}}, exp_i} + {{(FP_EXP_W+2-EXP_W){1'b0}}, `BIAS} - {{(FP_EXP_W+2-LDS_W){1'b0}}, lds};

         assign shift = (exp_int_tmp ^ {(FP_EXP_W+2){exp_int_tmp[FP_EXP_W+1]}}) + {{FP_EXP_W{1'b0}}, exp_int_tmp[FP_EXP_W+1], 1'b0};

`ifdef ROUNDING
         iob_mask
           #(
             .DATA_W (FP_EXP_W+2)
             )
         mask0
           (
            .maskl_i (shift),
            .mask_o  (mask)
            );
`endif
`else
         assign exp_int_tmp = {exp_i[FP_EXP_W-1], exp_i} + {{(FP_EXP_W+2-EXP_W){1'b0}}, `BIAS};
`endif

         assign underflow = exp_int_tmp[FP_EXP_W+1];
         assign overflow  = |exp_int_tmp[FP_EXP_W:EXP_W];

         assign exp_int = underflow? {(EXP_W+2){1'b0}}:
                           overflow? {(EXP_W+2){1'b1}}:
                                     exp_int_tmp[EXP_W+1:0];
      end
   endgenerate

   wire [`MAN_W+`EXTRA-1:0] man_shift, man_int_, man_int;
   generate
      if (`MAN_W > FP_MAN_W) begin
         assign man_int_ = {man_norm, {(`MAN_W+`EXTRA-FP_MAN_W){1'b0}}};
      end else begin
`ifdef ROUNDING
         assign man_int_ = {man_norm[FP_MAN_W-1 -: `MAN_W+`EXTRA-1], |man_norm[FP_MAN_W-1-(`MAN_W+`EXTRA-1):0]};
`else
         assign man_int_ = man_norm[FP_MAN_W-1 -: `MAN_W+`EXTRA];
`endif
      end
   endgenerate

   generate
      if (EXP_W > FP_EXP_W) begin
         assign man_int = man_int_;
      end else begin
`ifdef SUBNORMALS
         wire [`MAN_W+`EXTRA-1:0] man_shift_;
         assign man_shift_ = man_int_ >> shift;

`ifdef ROUNDING
         wire                     sticky;
         assign sticky = |(man_int_ & mask);

         assign man_shift = {man_shift_[`MAN_W+`EXTRA-1:1], man_shift_[0] | sticky};
`else
         assign man_shift = man_shift_;
`endif
`else
         assign man_shift = {(`MAN_W+`EXTRA){1'b0}};
`endif

         assign man_int = underflow? man_shift:
                           overflow? 1'b0:
                                     man_int_;
      end
   endgenerate

   // pipeline stage 1
   reg                            sign_int_reg;
   reg [EXP_W+1:0]                exp_int_reg;
   reg [`MAN_W+`EXTRA-1:0]        man_int_reg;

   reg                            done_reg;
   always @(posedge clk) begin
      if (rst) begin
         sign_int_reg <= 1'b0;
         exp_int_reg  <= {(EXP_W+2){1'b0}};
         man_int_reg  <= {(`MAN_W+`EXTRA){1'b0}};

         done_reg <= 1'b0;
      end else begin
         sign_int_reg <= sign_i;
         exp_int_reg  <= exp_int;
         man_int_reg  <= man_int;

         done_reg <= done_int;
      end
   end

   reg                            sign_f;
   reg [EXP_W-1:0]                exp_f;
   reg [`F_W-1:0]                 frac_f;
   wire                           nzero;
   reg                            done_f;
`ifdef ROUNDING
   wire [EXP_W-1:0]               exp_f_;
   wire [`MAN_W-1:0]              man_f_;
   wire                           round;
   round #(
           .DATA_W (`MAN_W),
           .EXP_W  (EXP_W)
           )
   round0
     (
      .exponent_i (exp_int_reg),
      .mantissa_i (man_int_reg),
      .inv        (1'b0),

      .exponent_o (exp_f_),
      .mantissa_o (man_f_),
      .round      (round)
      );

   assign nzero = |man_int_reg[`MAN_W+`EXTRA-1:3] | round;

   // pipeline stage 2
   always @(posedge clk) begin
      if (rst) begin
         sign_f <= 1'b0;
         exp_f  <= {EXP_W{1'b0}};
         frac_f <= {`F_W{1'b0}};

         done_f <= 1'b0;
      end else begin
         sign_f <= nzero & sign_int_reg;
         exp_f  <= man_f_[`MAN_W-1:0]? exp_f_: {EXP_W{1'b0}};
         frac_f <= man_f_[`F_W-1:0];

         done_f <= done_reg;
      end
   end
`else
   assign nzero  = |man_int_reg;

   always @* begin
      sign_f = nzero & sign_int_reg;
      exp_f  = man_int_reg[`MAN_W-1]? exp_int_reg: {EXP_W{1'b0}};
      frac_f = man_int_reg[`F_W-1:0];
      done_f = done_reg;
   end
`endif

   assign data_o = {sign_f, exp_f, frac_f};

   assign done = done_f;

endmodule
