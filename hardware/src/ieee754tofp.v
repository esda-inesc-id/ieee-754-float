`timescale 1ns / 1ps

`include "ieee754_defs.vh"

module ieee754tofp
  #(
    parameter DATA_W     = 64,
    parameter EXP_W      = 11,
    parameter FP_EXP_W   = 16,
    parameter FP_MAN_W   = 27,
    parameter FP_EXP_MAX = {1'b0, {(FP_EXP_W-1){1'b1}}},
    parameter FP_EXP_MIN = {1'b1, {(FP_EXP_W-2){1'b0}}, 1'b1}
    )
   (
    input                            clk,
    input                            rst,

    input                            start,
    output reg                       done,

    input [DATA_W-1:0]               data_i,

    output reg                       sign_o,
    output reg [FP_EXP_W+1:0]        exp_o,
    output reg [FP_MAN_W+`EXTRA-1:0] man_o
    );

   wire                              done_int;
   assign done_int = start;

   wire                              nsub, sub;
   assign nsub = |data_i[DATA_W-2 -: EXP_W];
   assign sub  = ~nsub;

   wire                              sign_int;
   assign sign_int = data_i[DATA_W-1];

   wire [EXP_W-1:0]                  fp_exp;
   assign fp_exp = {data_i[DATA_W-2 -: EXP_W-1], sub | data_i[DATA_W-EXP_W-1]};

   wire [`MAN_W-1:0]                 fp_sig;
   assign fp_sig  = {nsub, data_i[`F_W-1:0]};

   wire [`MAN_W-1:0]                 fp_man_norm;
`ifdef SUBNORMALS
   localparam LDS_W = $clog2(`MAN_W+1);
   wire [LDS_W-1:0]                  lds;
   cls
     #(
       .DATA_W(`MAN_W)
       )
   cls0
     (
      .data_in  (fp_sig),
      .symbol   (1'b0),
      .data_out (lds)
      );

   assign fp_man_norm = fp_sig << lds;
`else
   assign fp_man_norm = fp_sig[`MAN_W-1]? fp_sig: 1'b0;
`endif

   wire [FP_EXP_W+1:0]               exp_int_;
   generate
      if (FP_EXP_W > EXP_W) begin
`ifdef SUBNORMALS
         assign exp_int_ = {{(FP_EXP_W+2-EXP_W){1'b0}}, fp_exp} - {{(FP_EXP_W+2-EXP_W){1'b0}}, `BIAS} - {{(FP_EXP_W+2-LDS_W){1'b0}}, lds};
`else
         assign exp_int_ = {{(FP_EXP_W+2-EXP_W){1'b0}}, fp_exp} - {{(FP_EXP_W+2-EXP_W){1'b0}}, `BIAS};
`endif
      end else begin
         wire [EXP_W-1:0] exp_int_tmp;
`ifdef SUBNORMALS
         assign exp_int_tmp  = fp_exp - `BIAS - {{(EXP_W-LDS_W){1'b0}}, lds};
`else
         assign exp_int_tmp  = fp_exp - `BIAS;
`endif

         wire [EXP_W-1:0] shift;
         assign shift = {{(EXP_W-FP_EXP_W){1'b1}}, FP_EXP_MIN} - exp_int_tmp;

         wire                 overflow;
         wire                 underflow;
         assign underflow = ~&shift[EXP_W-1:FP_EXP_W+1];
         assign overflow  = ~(&exp_int_tmp[EXP_W-1:FP_EXP_W+1] | ~|exp_int_tmp[EXP_W-1:FP_EXP_W+1]);

         assign exp_int_ = underflow? {2'b11, FP_EXP_MIN}:
                            overflow? {2'b00, FP_EXP_MAX}:
                                      exp_int_tmp[FP_EXP_W+1:0];
      end
   endgenerate

   wire                              zero;
   assign zero = ~|fp_sig;

   wire [FP_EXP_W+1:0]               exp_int;
   assign exp_int = zero? {2'b11, FP_EXP_MIN}: exp_int_;

   wire [FP_MAN_W+`EXTRA-1:0]        man_int;
   generate
      if (FP_MAN_W > `MAN_W) begin
         assign man_int = {fp_man_norm, {(FP_MAN_W+`EXTRA-`MAN_W){1'b0}}};
      end else begin
`ifdef ROUNDING
         assign man_int = {fp_man_norm[`MAN_W-1 -: FP_MAN_W+`EXTRA-1], |fp_man_norm[`MAN_W-1-(FP_MAN_W+`EXTRA-1):0]};
`else
         assign man_int = fp_man_norm[`MAN_W-1 -: FP_MAN_W+`EXTRA];
`endif
      end
   endgenerate

   // pipeline stage 1
   always @(posedge clk) begin
      if (rst) begin
         sign_o <= 1'b0;
         exp_o  <= {(FP_EXP_W+2){1'b0}};
         man_o  <= {(FP_MAN_W+`EXTRA){1'b0}};

         done <= 1'b0;
      end else begin
         sign_o <= sign_int;
         exp_o  <= exp_int;
         man_o  <= man_int;

         done <= done_int;
      end
   end

endmodule
