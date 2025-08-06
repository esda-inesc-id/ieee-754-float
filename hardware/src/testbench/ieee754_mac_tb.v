`timescale 1ns / 1ps

`include "mac_tbdefs.vh"

module ieee754_mac_tb;
   parameter DATA_W = 32;
   parameter EXP_W = 8;
   parameter LGUARD_W = 0;
   parameter RGUARD_W = 0;

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

   real              acc;
   real              acc_in;

   integer           fp;

`include "functions.vh"

`include "mac_fns.vh"

   ieee754_mac
     #(
       .DATA_W   (DATA_W),
       .EXP_W    (EXP_W),
       .LGUARD_W (LGUARD_W),
       .RGUARD_W (RGUARD_W)
       )
   ieee754_mac0
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
      $dumpfile("ieee754_mac.vcd");
      $dumpvars();
`endif

      start = 0;

      #(clk_per+1);

      rst = 1;
      #(100*clk_per);
      rst = 0;

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

      if (res == acc) begin
         $display("Test passed!");
      end else begin
         $display("Test Failed!");
      end

`include "mac_tasks.vh"

      #clk_per $finish;
   end

   always @* op_a_ = float2bin(op_a);
   always @* op_b_ = float2bin(op_b);
   always @* res   = bin2float(res_);

   // Accumulator
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         acc <= 0.0;
      end else begin
         acc <= acc_in;
      end
   end

   always @* acc_in = start? acc + op_a * op_b:
                       done? 0.0:
                             acc;

   // Clock
   always #(clk_per/2) clk = ~clk;

endmodule
