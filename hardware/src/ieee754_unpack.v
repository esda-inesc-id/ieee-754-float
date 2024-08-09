`timescale 1ns / 1ps

module ieee754_unpack
  #(
    parameter DATA_W = 32,
    parameter EXP_W = 8
    )
   (
    input              clk,
    input              rst,

    input              start,
    output             done,

    input [DATA_W-1:0] data_i,

`ifdef SPECIAL_CASES
    output             nan,
    output             infinite,
    output             zero,
`endif

    output             sign,
    output [EXP_W-1:0] exponent,
    output [MAN_W-1:0] mantissa
    );

   localparam MAN_W = DATA_W-EXP_W;

   // Special cases
`ifdef SPECIAL_CASES
   fp_special #(
                .DATA_W(DATA_W),
                .EXP_W(EXP_W)
                )
   special
     (
      .data_i   (data_i),

      .nan      (nan),
      .infinite (infinite),
      .zero     (zero)
      );
`endif

   // Unpack
   wire                nsub = |data_i[DATA_W-2 -: EXP_W];
   wire                sub = ~nsub;

   assign sign     = data_i[DATA_W-1];
   assign exponent = {data_i[DATA_W-2 -: EXP_W-1], sub | data_i[DATA_W-EXP_W-1]};
   assign mantissa = {nsub, data_i[MAN_W-2:0]};

   assign done = start;

endmodule
