`timescale 1ns / 1ps

// Applies TestFloat vectors (a b result flags) from vectors.tv to one unit.
// The units have no exception flags, so only the result is compared, and any
// NaN matches any NaN. Failing vectors are written to fails.tv.

module testfloat_tb;

   parameter clk_per = 20;
   parameter MAX_CYCLES = 1000;

   reg         clk = 0;
   reg         rst = 0;
   reg         valid_i = 0;
   wire        valid_o;
   reg  [31:0] op_a = 0;
   reg  [31:0] op_b = 0;
   wire [31:0] res;

   `TF_DUT #(
      .DATA_W(32),
      .EXP_W (8)
   ) dut (
      .clk    (clk),
      .rst    (rst),
      .valid_i(valid_i),
      .valid_o(valid_o),
`ifdef TF_FPU
      .funct  (2'd`TF_FUNCT),
`endif
      .op_a   (op_a),
      .op_b   (op_b),
      .res    (res)
   );

   function is_nan(input [31:0] x);
      is_nan = (&x[30:23]) & (|x[22:0]);
   endfunction

   integer vec_fd, fail_fd, n_read, cycles;
   integer        vectors = 0;
   integer        fails = 0;
   reg     [31:0] expected;
   reg     [ 7:0] flags;
   reg [31:0] vec_a, vec_b, vec_c;

   task read_vector;
      begin
`ifdef TF_3OP
         n_read = $fscanf(vec_fd, "%h %h %h %h %h\n", vec_a, vec_b, vec_c, expected, flags) - 1;
`else
         n_read = $fscanf(vec_fd, "%h %h %h %h\n", vec_a, vec_b, expected, flags);
`endif
      end
   endtask

   initial begin
      vec_fd  = $fopen("vectors.tv", "r");
      fail_fd = $fopen("fails.tv", "w");
      if (vec_fd == 0) begin
         $display("TESTFLOAT ERROR: cannot open vectors.tv");
         $finish;
      end

      repeat (2) @(negedge clk);
      rst = 1;
      repeat (10) @(negedge clk);
      rst = 0;
      repeat (2) @(negedge clk);

      read_vector;
      while (n_read == 4) begin
         op_a    = vec_a;
         op_b    = vec_b;
         valid_i = 1;
         @(negedge clk);
`ifdef TF_3OP
         // a*b + c*1.0
         op_a = vec_c;
         op_b = 32'h3f800000;
         @(negedge clk);
`endif
         valid_i = 0;

         cycles  = 0;
         while (!valid_o && cycles < MAX_CYCLES) begin
            @(negedge clk);
            cycles = cycles + 1;
         end
         if (!valid_o) begin
            $display("TESTFLOAT ERROR: no valid_o after %0d cycles, a=%h b=%h", MAX_CYCLES, op_a,
                     op_b);
            $display("TESTFLOAT vectors=%0d fails=timeout", vectors);
            $finish;
         end

         vectors = vectors + 1;
         if (!(res === expected || (is_nan(res) === 1'b1 && is_nan(expected)))) begin
            fails = fails + 1;
`ifdef TF_3OP
            $fdisplay(fail_fd, "%h %h %h %h %h", vec_a, vec_b, vec_c, expected, res);
`else
            $fdisplay(fail_fd, "%h %h %h %h", vec_a, vec_b, expected, res);
`endif
         end

         while (valid_o) @(negedge clk);

         read_vector;
      end

      $fclose(vec_fd);
      $fclose(fail_fd);
      $display("TESTFLOAT vectors=%0d fails=%0d", vectors, fails);
      $finish;
   end

   always #(clk_per / 2) clk = ~clk;

endmodule
