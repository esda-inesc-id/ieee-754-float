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
    input [FP_MAN_W-1:0] sig_i,

    output [DATA_W-1:0]  data_o
    );

   wire                  done_int;
   assign done_int = start;

   wire [FP_MAN_W-1:0]   sig_norm;
`ifdef SUBNORMALS
   localparam LDS_W = $clog2(FP_MAN_W+1);
   wire [LDS_W-1:0]            lds;
   cls
     #(
       .DATA_W(FP_MAN_W)
       )
   cls0
     (
      .data_in  (sig_i),
      .symbol   (1'b0),
      .data_out (lds)
      );

   assign sig_norm = sig_i << lds;
`else
   assign sig_norm = sig_i[FP_MAN_W-1]? sig_i: 1'b0;
`endif

   wire                        overflow;
   wire                        underflow;
   wire [EXP_W-1:0]            exp_int_;
   wire [FP_EXP_W:0]           shift, mask;
   generate
      if (EXP_W > FP_EXP_W) begin
`ifdef SUBNORMALS
         assign exp_int_ = {{(EXP_W-(FP_EXP_W+1)){exp_i[FP_EXP_W-1]}}, exp_i} + `BIAS - {{(EXP_W-LDS_W){1'b0}}, lds};
`else
         assign exp_int_ = {{(EXP_W-FP_EXP_W){exp_i[FP_EXP_W-1]}}, exp_i} + `BIAS;
`endif

         assign shift = 1'b0;
         assign mask  = 1'b0;

         assign overflow  = 1'b0;
         assign underflow = 1'b0;
      end else begin
         wire [FP_EXP_W:0] exp_int_tmp;
`ifdef SUBNORMALS
         assign exp_int_tmp = {exp_i[FP_EXP_W-1], exp_i} + {{(FP_EXP_W+1-EXP_W){1'b0}}, `BIAS} - {{(FP_EXP_W+1-LDS_W){1'b0}}, lds};

         assign shift = (exp_int_tmp ^ {(FP_EXP_W+1){exp_int_tmp[FP_EXP_W]}}) + {{(FP_EXP_W){1'b0}}, exp_int_tmp[FP_EXP_W]};

`ifdef ROUNDING
         iob_mask
           #(
             .DATA_W (FP_EXP_W+1)
             )
         mask0
           (
            .maskl_i (shift),
            .mask_o  (mask)
            );
`endif
`else
         assign exp_int_tmp = {exp_i[FP_EXP_W-1], exp_i} + {{(FP_EXP_W+1-EXP_W){1'b0}}, `BIAS};
`endif

         assign underflow = exp_int_tmp[FP_EXP_W];
         assign overflow  = |exp_int_tmp[FP_EXP_W-1:EXP_W];

         assign exp_int_ = underflow? {EXP_W{1'b0}}:
                            overflow? {EXP_W{1'b1}}:
                                      exp_int_tmp[EXP_W-1:0];
      end
   endgenerate

   wire                        zero;
   assign zero = ~|sig_i;

   wire [EXP_W-1:0]     exp_int;
   assign exp_int = zero? {EXP_W{1'b0}}: exp_int_;

   localparam RES_W = `MAN_W+EXTRA;

   wire [RES_W-1:0]            sig_shift, sig_int_, sig_int;
   generate
      if (`MAN_W > FP_MAN_W) begin
         assign sig_int_ = {sig_norm, {(RES_W-FP_MAN_W){1'b0}}};
      end else begin
`ifdef ROUNDING
         assign sig_int_ = {sig_norm[FP_MAN_W-1 -: RES_W-1], |sig_norm[FP_MAN_W-1-(RES_W-1):0]};
`else
         assign sig_int_ = sig_norm[FP_MAN_W-1 -: RES_W];
`endif
      end
   endgenerate

   generate
      if (EXP_W > FP_EXP_W) begin
         assign sig_int = sig_int_;
      end else begin
`ifdef SUBNORMALS
         wire [RES_W-1:0]      sig_shift_;
         assign sig_shift_ = sig_int_ >> shift;

`ifdef ROUNDING
         wire                  sticky;
         assign sticky = |(sig_int_ & mask);

         assign sig_shift = {sig_shift_[RES_W-1:1], sig_shift_[0] | sticky};
`else
         assign sig_shift = sig_shift_;
`endif
`else
         assign sig_shift = {RES_W{1'b0}};
`endif

         assign sig_int = underflow? sig_shift:
                           overflow? 1'b0:
                                     sig_int_;
      end
   endgenerate

   // pipeline stage 1
   reg                         sign_int_reg;
   reg [EXP_W-1:0]             exp_int_reg;
   wire [RES_W-1:0]            sig_int_reg;

   reg                         done_reg;
   always @(posedge clk) begin
      if (rst) begin
         sign_int_reg <= 1'b0;
         exp_int_reg  <= {EXP_W{1'b0}};
         sig_int_reg  <= {RES_W{1'b0}};

         done_reg <= 1'b0;
      end else begin
         sign_int_reg <= sign_i;
         exp_int_reg  <= exp_int;
         sig_int_reg  <= sig_int;

         done_reg <= done_int;
      end
   end

   wire                        sign_f;
   wire [EXP_W-1:0]            exp_f;
   wire [MAN_W-1:0]            sig_f;
   wire                        done_f;
`ifdef ROUNDING
   wire [EXP_W-1:0]            exp_f_;
   wire [`MAN_W-1:0]           sig_f_;
   round #(
           .DATA_W (`MAN_W),
           .EXP_W  (EXP_W)
           )
   round0
     (
      .exponent     (exp_int_reg),
      .mantissa     (sig_int_reg),
      .cin          (1'b0),

      .exponent_rnd (exp_f_),
      .mantissa_rnd (sig_f_)
      );

   // pipeline stage 2
   always @(posedge clk) begin
      if (rst) begin
         sign_f <= 1'b0;
         exp_f  <= {EXP_W{1'b0}};
         sig_f  <= {`MAN_W{1'b0}};

         done_f <= 1'b0;
      end else begin
         sign_f <= sign_int_reg;
         exp_f  <= exp_f_;
         sig_f  <= sig_f_;

         done_f <= done_reg;
      end
   end
`else
   assign sign_f = sign_int_reg;
   assign exp_f  = exp_int_reg;
   assign sig_f  = sig_int_reg;
   assign done_f = done_reg;
`endif

   assign data_o = {sign_f, exp_f, sig_f[`F_W-1:0]};

   assign done = done_f;

endmodule
