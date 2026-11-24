`timescale 1ns / 1ps

// Applies vectors.tv to fmac (define FMAC) or fpu and writes results.out.
// fmac: product streams separated by the minimum idle gap.
// fpu: add, sub and mul on consecutive cycles; div held until its result.
// +rnd_mode=<n> sets the rounding mode (default 0). +rnd_cycle instead gives operation or
// product k (from 0) the mode (3k + k/8) mod 8, and idle cycles another mode, as
// model_run does with "cycle".

module rtl_tb;

   // the format and guard widths come from macros, set by check.py
`ifndef RTL_DATA_W
`define RTL_DATA_W 32
`endif
`ifndef RTL_EXP_W
`define RTL_EXP_W 8
`endif
`ifndef RTL_LGUARD_W
`define RTL_LGUARD_W 0
`endif
`ifndef RTL_RGUARD_W
`define RTL_RGUARD_W 0
`endif
   parameter DATA_W = `RTL_DATA_W;
   parameter EXP_W = `RTL_EXP_W;
   parameter LGUARD_W = `RTL_LGUARD_W;
   parameter RGUARD_W = `RTL_RGUARD_W;
   parameter CLK_PER = 20;
   parameter GAP = 2;
   parameter MAX_WAIT = 1024;

   reg               clk = 0;
   reg               rst = 0;
   reg               valid_i = 0;
   reg  [DATA_W-1:0] op_a = 0;
   reg  [DATA_W-1:0] op_b = 0;
   reg  [       2:0] rnd_mode = 0;
   wire              valid_o;
   wire [DATA_W-1:0] res;

   integer           rnd_arg = 0;
   integer           rnd_cycle = 0;
   integer           k = 0;

   function [2:0] cycle_mode(input integer idx);
      cycle_mode = idx * 3 + idx / 8;
   endfunction

   // mode of the next operation or product
   task next_mode;
      begin
         if (rnd_cycle) begin
            rnd_mode = cycle_mode(k);
            k = k + 1;
         end
      end
   endtask

   // mode while idle, which must not affect results
   task idle_mode;
      begin
         if (rnd_cycle) rnd_mode = ~rnd_mode;
      end
   endtask

`ifdef FMAC
   fmac #(
      .DATA_W  (DATA_W),
      .EXP_W   (EXP_W),
      .LGUARD_W(LGUARD_W),
      .RGUARD_W(RGUARD_W)
   ) dut (
      .clk    (clk),
      .rst    (rst),
      .valid_i(valid_i),
      .valid_o(valid_o),
      .rnd_mode(rnd_mode),
      .op_a   (op_a),
      .op_b   (op_b),
      .res    (res)
   );
`else
   reg [1:0] funct = 0;
   reg [8*128-1:0] line;
   fpu #(
      .DATA_W(DATA_W),
      .EXP_W (EXP_W)
   ) dut (
      .clk    (clk),
      .rst    (rst),
      .valid_i(valid_i),
      .valid_o(valid_o),
      .rnd_mode(rnd_mode),
      .funct  (funct),
      .op_a   (op_a),
      .op_b   (op_b),
      .res    (res)
   );
`endif

   integer vec_fd, res_fd, n_read, n, i, waited, code;
   integer sent = 0;
   integer received = 0;

   always @(negedge clk) begin
      if (valid_o) begin
         $fdisplay(res_fd, "%h", res);
         received = received + 1;
      end
   end

   task wait_results;
      begin
         waited = 0;
         while (received < sent && waited < MAX_WAIT) begin
            @(posedge clk);
            waited = waited + 1;
         end
      end
   endtask

   initial begin
      if ($value$plusargs("rnd_mode=%d", rnd_arg)) rnd_mode = rnd_arg[2:0];
      rnd_cycle = $test$plusargs("rnd_cycle");
      vec_fd = $fopen("vectors.tv", "r");
      res_fd = $fopen("results.out", "w");
      if (vec_fd == 0) begin
         $display("RTL_TB ERROR: cannot open vectors.tv");
         $finish;
      end

      repeat (2) @(posedge clk);
      rst = 1;
      repeat (10) @(posedge clk);
      rst = 0;
      repeat (2) @(posedge clk);
      #1;

`ifdef FMAC
      n_read = $fscanf(vec_fd, "%d\n", n);
      while (n_read == 1) begin
         valid_i = 1;
         for (i = 0; i < n; i = i + 1) begin
            n_read = $fscanf(vec_fd, "%h %h\n", op_a, op_b);
            next_mode;
            @(posedge clk);
            #1;
         end
         valid_i = 0;
         idle_mode;
         sent    = sent + 1;
         repeat (GAP + ((sent % 4 == 0) ? sent % 3 : 0)) @(posedge clk);
         #1;
         n_read = $fscanf(vec_fd, "%d\n", n);
      end
`else
      n_read = $fscanf(vec_fd, "%d %h %h", code, op_a, op_b);
      while (n_read == 3) begin
         n_read  = $fgets(line, vec_fd);
         funct   = code[1:0];
         valid_i = 1;
         next_mode;
         sent    = sent + 1;
         @(posedge clk);
         #1;
         if (code == 3) begin
            valid_i = 0;
            funct   = 0;
            idle_mode;
            wait_results;
            @(posedge clk);
            #1;
         end
         n_read = $fscanf(vec_fd, "%d %h %h", code, op_a, op_b);
      end
      valid_i = 0;
      idle_mode;
`endif

      wait_results;
      repeat (8) @(posedge clk);

      $fclose(vec_fd);
      $fclose(res_fd);
      $display("RTL_TB sent=%0d received=%0d", sent, received);
      $finish;
   end

   always #(CLK_PER / 2) clk = ~clk;

endmodule
