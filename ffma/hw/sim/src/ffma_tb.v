`timescale 1ns / 1ps

// VCD comes from sim_config.vh, written by the make flow
`include "sim_config.vh"

// A few fused multiply-adds, one per cycle; the TestFloat runs check the unit
module ffma_tb;
   parameter DATA_W = 32;
   parameter EXP_W = 8;

   parameter BIAS = 2 ** (EXP_W - 1) - 1;

   parameter clk_per = 20;

   reg               clk = 0;
   reg               rst = 0;

   reg               valid_i;
   wire              valid_o;

   real              op_a;
   real              op_b;
   real              op_c;
   real              res;

   wire [DATA_W-1:0] res_;

   `include "functions.vh"

   ffma #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) ffma0 (
      .clk(clk),
      .rst(rst),

      .valid_i(valid_i),
      .valid_o(valid_o),
      .rnd_mode(3'd0),

      .op_a(float2bin(op_a)),
      .op_b(float2bin(op_b)),
      .op_c(float2bin(op_c)),

      .res(res_)
   );

   initial begin

`ifdef VCD
      $dumpfile("ffma.vcd");
      $dumpvars();
`endif

      valid_i = 0;
      op_a    = 0.0;
      op_b    = 0.0;
      op_c    = 0.0;

      #(clk_per + 1);

      rst = 1;
      #(100 * clk_per);
      rst = 0;

      #clk_per;
      op_a    = 2.0;
      op_b    = 3.0;
      op_c    = 1.0;
      valid_i = 1;

      #clk_per;
      op_a = -5.0;
      op_b = 4.0;
      op_c = 20.0;

      #clk_per;
      op_a = 1.5;
      op_b = 1.5;
      op_c = -0.25;

      #clk_per;
      op_a = 1.0e10;
      op_b = 1.0e-10;
      op_c = -1.0;

      #clk_per;
      valid_i = 0;

      while (~valid_o) #clk_per;
      while (valid_o) begin
         $display("ffma: %f", res);
         #clk_per;
      end

      #clk_per $finish;
   end

   always @* res = bin2float(res_);

   // Clock
   always #(clk_per / 2) clk = ~clk;

endmodule
