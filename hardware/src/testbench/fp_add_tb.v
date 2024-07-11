`timescale 1ns / 1ps

`include "fp_defs.vh"

module fp_add_tb;
   parameter DATA_W = 32;
   parameter EXP_W = 8;

   parameter BIAS = 2**(EXP_W-1)-1;

   parameter clk_per = 20;

   reg clk = 0;
   reg rst = 0;

   reg start;
   wire done;

   real op_a;
   real op_b;

   real res;

   // Auxilary signals
   reg [DATA_W-1:0] op_a_;
   reg [DATA_W-1:0] op_b_;

   wire [DATA_W-1:0] res_;

   function [DATA_W-1:0] float2bin;
      input real     x;
      reg [63:0]     x_d;

      begin
         x_d = $realtobits(x);
         float2bin[DATA_W-1] = x_d[63];
         float2bin[DATA_W-2 -: EXP_W] = x_d[62 -: 11] - 1023 + BIAS;
         float2bin[DATA_W-EXP_W-2 -: DATA_W-EXP_W-1] = x_d[63-12 -: DATA_W-EXP_W-1];
      end
   endfunction

   function real bin2float;
      input [DATA_W-1:0] x;
      reg [63:0]         x_d;

      begin
         x_d[63] = x[DATA_W-1];
         x_d[62 -: 11] = x[DATA_W-2 -: EXP_W] - BIAS + 1023;
         x_d[63-12 -: 52] = {x[DATA_W-EXP_W-2 -: DATA_W-EXP_W-1], {(52-(DATA_W-EXP_W-1)){1'b0}}};
         bin2float = $bitstoreal(x_d);
      end
   endfunction

   fp_add
     #(
       .DATA_W  (DATA_W),
       .EXP_W   (EXP_W)
       )
   add
     (
      .clk   (clk),
      .rst   (rst),

      .start (start),
      .done  (done),

      .op_a  (op_a_),
      .op_b  (op_b_),

      .res   (res_)
      );

   initial begin

      $dumpfile("fp_add.vcd");
      $dumpvars();

      start = 0;

      #(clk_per+1);

      rst = 1;
      #(100*clk_per);
      rst = 0;

      #clk_per;
      op_a = -5.0;
      op_b = 4.0;
      start = 1;

      #clk_per;
      op_a = 5.0;
      op_b = -4.0;
      start = 1;

      #clk_per;
      op_a = -4.0;
      op_b = 5.0;
      start = 1;

      #clk_per;
      op_a = 4.0;
      op_b = -5.0;
      start = 1;

      #clk_per;
      op_a = 2.0;
      op_b = 3.0;
      start = 1;

      #clk_per;
      op_a = 4.0;
      op_b = 5.0;

      #clk_per;
      op_a = 6.0;
      op_b = 7.0;

      #clk_per;
      op_a = -1.0;
      op_b = 3.0;

      #clk_per;
      op_a = -2.0;
      op_b = -4.0;

      #clk_per;
      op_a = -5.0;
      op_b = 3.0;

      #clk_per;
      op_a = 2.0;
      op_b = -7.0;

      #clk_per;
      op_a = -3.0;
      op_b = -2.0;

      #clk_per;
      op_a = 11.0;
      op_b = 13.0;

      #clk_per;
      op_a = 17.0;
      op_b = 19.0;

      #clk_per;
      start = 0;

      while (~done) #clk_per;

      #clk_per $finish;
   end

   assign op_a_ = float2bin(op_a);
   assign op_b_ = float2bin(op_b);
   assign res   = bin2float(res_);

   // Clock
   always #(clk_per/2) clk = ~clk;

endmodule
