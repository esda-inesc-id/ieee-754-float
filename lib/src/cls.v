`timescale 1ns / 1ps

// Counts the leading zeros of data_in; DATA_W if all bits are zero

module cls #(
   parameter DATA_W = 32
) (
   input  [          DATA_W-1:0] data_in,
   output [$clog2(DATA_W+1)-1:0] data_out
);

   localparam BIT_W = $clog2(DATA_W + 1);

   // a continuous assignment, so that a constant input is counted from time 0
   function [BIT_W-1:0] count(input [DATA_W-1:0] d);
      integer i;
      begin
         count = DATA_W[BIT_W-1:0];
         for (i = 0; i < DATA_W; i = i + 1) begin
            if (d[i]) begin
               count = (DATA_W[BIT_W-1:0] - i[BIT_W-1:0] - 1'b1);
            end
         end
      end
   endfunction

   assign data_out = count(data_in);

endmodule
