`timescale 1ns / 1ps

`define FUNCT_W 2

module fpu_tb;
   parameter DATA_W = 32;
   parameter EXP_W = 8;

   parameter BIAS = 2 ** (EXP_W - 1) - 1;

   parameter clk_per = 20;

   reg                 clk = 0;
   reg                 rst = 0;

   reg                 valid_i;
   wire                valid_o;

   reg  [`FUNCT_W-1:0] funct;

   real                op_a;
   real                op_b;

   reg                 raw = 0;

   reg  [  DATA_W-1:0] op_a_raw;
   reg  [  DATA_W-1:0] op_b_raw;

   real                res;

   // Auxilary signals
   reg  [  DATA_W-1:0] op_a_;
   reg  [  DATA_W-1:0] op_b_;

   wire [  DATA_W-1:0] res_;

   `include "functions.vh"

fpu #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) fpu0 (
      .clk(clk),
      .rst(rst),

      .valid_i(valid_i),
      .valid_o(valid_o),
      .rnd_mode(3'd0),

      .funct(funct),

      .op_a(op_a_),
      .op_b(op_b_),

      .res(res_)
   );

   initial begin

`ifdef VCD
      $dumpfile("fpu.vcd");
      $dumpvars();
`endif

      valid_i = 0;

      #(clk_per + 1);

      rst = 1;
      #(100 * clk_per);
      rst   = 0;

      //
      // Test addition
      //
      funct = 0;

      #clk_per;
      op_a    = -5.0;
      op_b    = 4.0;
      valid_i = 1;

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
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b10000000000000000000000000000000;
      raw      = 1;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b11111111100000000000000000000000;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b10000000000000000000000000000001;

      #clk_per;
      op_a_raw = 'b10001011111011000110111001010100;
      op_b_raw = 'b00000110111001111010011111101000;

      #clk_per;
      valid_i = 0;
      raw     = 0;

      while (~valid_o) #clk_per;
      while (valid_o) #clk_per;

      //
      // Test multiplication
      //
      funct = 2;

      #clk_per;
      op_a    = -5.0;
      op_b    = 4.0;
      valid_i = 1;

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
      raw      = 1;

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
      valid_i = 0;
      raw     = 0;

      while (~valid_o) #clk_per;
      while (valid_o) #clk_per;

      //
      // Test division
      //
      funct = 3;

      #clk_per;
      op_a    = -5.0;
      op_b    = 4.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 5.0;
      op_b    = -4.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = -4.0;
      op_b    = 5.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 4.0;
      op_b    = -5.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 2.0;
      op_b    = 3.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 4.0;
      op_b    = 5.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 6.0;
      op_b    = 7.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = -1.0;
      op_b    = 3.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = -2.0;
      op_b    = -4.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = -5.0;
      op_b    = 3.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 2.0;
      op_b    = -7.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = -3.0;
      op_b    = -2.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 11.0;
      op_b    = 13.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 17.0;
      op_b    = 19.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a    = 4.0;
      op_b    = -3.0;
      valid_i = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b00000000111111111111111111111111;
      raw      = 1;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000111111111111111111111111;
      op_b_raw = 'b00000000000000000000000000000001;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000111111111111111111111111;
      op_b_raw = 'b00000000111111111111111111111111;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b00000000000000000000000000000001;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b10000000000000000000000000000000;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b11111111100000000000000000000000;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000001;
      op_b_raw = 'b10000000000000000000000000000001;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;

      #clk_per;
      op_a_raw = 'b00000000000000000000000000000000;
      op_b_raw = 'b01000000000000000000000000000000;
      valid_i  = 1;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;
      while (valid_o) #clk_per;

      #clk_per $finish;
   end

   always @* op_a_ = raw ? op_a_raw : float2bin(op_a);
   always @* op_b_ = raw ? op_b_raw : float2bin(op_b);
   always @* res = bin2float(res_);

   // Clock
   always #(clk_per / 2) clk = ~clk;

endmodule
