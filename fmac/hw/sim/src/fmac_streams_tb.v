`timescale 1ns / 1ps

// Applies the product streams of streams.tv with the minimum idle gap between
// them and writes one result per stream to streams.out.

module fmac_streams_tb;

   parameter CLK_PER = 20;
   parameter GAP = 2;
   parameter MAX_WAIT = 64;

   reg         clk = 0;
   reg         rst = 0;
   reg         valid_i = 0;
   reg  [31:0] op_a = 0;
   reg  [31:0] op_b = 0;
   wire        valid_o;
   wire [31:0] res;

   fmac dut (
      .clk    (clk),
      .rst    (rst),
      .valid_i(valid_i),
      .valid_o(valid_o),
      .op_a   (op_a),
      .op_b   (op_b),
      .res    (res)
   );

   integer vec_fd, res_fd, n_read, n, i, waited;
   integer sent = 0;
   integer received = 0;

   always @(negedge clk) begin
      if (valid_o) begin
         $fdisplay(res_fd, "%h", res);
         received = received + 1;
      end
   end

   initial begin
      vec_fd = $fopen("streams.tv", "r");
      res_fd = $fopen("streams.out", "w");
      if (vec_fd == 0) begin
         $display("FMAC_STREAMS ERROR: cannot open streams.tv");
         $finish;
      end

      repeat (2) @(posedge clk);
      rst = 1;
      repeat (10) @(posedge clk);
      rst = 0;
      repeat (2) @(posedge clk);

      n_read = $fscanf(vec_fd, "%d\n", n);
      while (n_read == 1) begin
         valid_i = 1;
         for (i = 0; i < n; i = i + 1) begin
            n_read = $fscanf(vec_fd, "%h %h\n", op_a, op_b);
            @(posedge clk);
            #1;
         end
         valid_i = 0;
         sent    = sent + 1;
         repeat (GAP + ((sent % 4 == 0) ? sent % 3 : 0)) @(posedge clk);
         #1;
         n_read = $fscanf(vec_fd, "%d\n", n);
      end

      waited = 0;
      while (received < sent && waited < MAX_WAIT) begin
         @(posedge clk);
         waited = waited + 1;
      end
      @(posedge clk);

      $fclose(vec_fd);
      $fclose(res_fd);
      $finish;
   end

   always #(CLK_PER / 2) clk = ~clk;

endmodule
