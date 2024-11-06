`timescale 1ns / 1ps

module fp_special #(
                    parameter DATA_W = 32,
                    parameter EXP_W = 8
                    )
   (
    input [DATA_W-1:0] data_i,

    output             nan,
    output             infinite,
    output             zero
    );

   localparam FRAC_W = DATA_W-EXP_W-1;

   wire [EXP_W-1:0]    exponent = data_i[DATA_W-2 -: EXP_W];
   wire [FRAC_W-1:0]   fraction = data_i[FRAC_W-1:0];

   wire                exp_all_ones = &exponent;
   wire                exp_zero = ~|exponent;
   wire                frac_nzero = |fraction;
   wire                frac_zero = ~frac_nzero;

   assign nan       = exp_all_ones & frac_nzero;
   assign infinite  = exp_all_ones & frac_zero;
   assign zero      = exp_zero & frac_zero;

endmodule
