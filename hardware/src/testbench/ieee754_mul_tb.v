`timescale 1ns / 1ps

module ieee754_mul_tb;
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

   reg  raw = 0;

   reg [DATA_W-1:0] op_a_raw;
   reg [DATA_W-1:0] op_b_raw;

   real res;

   // Auxilary signals
   reg [DATA_W-1:0] op_a_;
   reg [DATA_W-1:0] op_b_;

   wire [DATA_W-1:0] res_;

`include "functions.vh"

   ieee754_mul
     #(
       .DATA_W  (DATA_W),
       .EXP_W   (EXP_W)
       )
   ieee754_mul0
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

`ifdef VCD
      $dumpfile("ieee754_mul.vcd");
      $dumpvars();
`endif

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

      #clk_per;
      op_a = -4.0;
      op_b = 5.0;

      #clk_per;
      op_a = 4.0;
      op_b = -5.0;

      #clk_per;
      op_a = 2.0;
      op_b = 3.0;

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
      op_a = 4.0;
      op_b = -3.0;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b00000000111111111111111111111111;
      raw = 1;

      #clk_per;
      op_a_raw = 'b00000000111111111111111111111111;
      op_b_raw = 'b00000000000000000000000000000001;

      #clk_per;
      op_a_raw = 'b00000000111111111111111111111111;
      op_b_raw = 'b00000000111111111111111111111111;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b00000000000000000000000000000001;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b10000000000000000000000000000000;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b11111111100000000000000000000000;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b10000000000000000000000000000001;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b01000000000000000000000000000000;

      #clk_per;
      op_a_raw = 'b00011110011111111111111111111111;
      op_b_raw = 'b00011110011111111111111111111111;

      #clk_per;
      op_a_raw = 'b00111111111111111111111111111111;
      op_b_raw = 'b00000000000000000000000000000001;

      #clk_per;
      op_a_raw = 'b01000000011111111111111111111111;
      op_b_raw = 'b00000000000000000000000000000001;

      #clk_per;
      op_a_raw = 'b01111111011111111111111111111111;
      op_b_raw = 'b01111111011111111111111111111111;

      #clk_per;
      op_a_raw = 'b10001001111111100001111001000000;
      op_b_raw = 'b10110110001000110111011101101011;

      #clk_per;
      op_a_raw = 'b10011000010110010001010000011000;
      op_b_raw = 'b00100111110111100000000101000101;

      #clk_per;
      start = 0;

      while (~done) #clk_per;
      while (done) #clk_per;

      #clk_per $finish;
   end

   assign op_a_ = raw? op_a_raw: float2bin(op_a);
   assign op_b_ = raw? op_b_raw: float2bin(op_b);
   assign res   = bin2float(res_);

   // Clock
   always #(clk_per/2) clk = ~clk;

endmodule
