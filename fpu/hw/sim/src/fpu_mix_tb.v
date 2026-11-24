`timescale 1ns / 1ps

// Issues the operations of mix.tv: add, sub and mul on consecutive cycles, and
// div with its operands held until its result. Results are checked in order.

module fpu_mix_tb;

   parameter CLK_PER = 20;
   parameter QUEUE_W = 6;
   parameter MAX_WAIT = 512;

   reg         clk = 0;
   reg         rst = 0;
   reg         valid_i = 0;
   reg  [ 1:0] funct = 0;
   reg  [31:0] op_a = 0;
   reg  [31:0] op_b = 0;
   wire        valid_o;
   wire [31:0] res;

   fpu dut (
      .clk    (clk),
      .rst    (rst),
      .valid_i(valid_i),
      .valid_o(valid_o),
      .rnd_mode(3'd0),
      .funct  (funct),
      .op_a   (op_a),
      .op_b   (op_b),
      .res    (res)
   );

   reg [31:0] queue    [0:(1<<QUEUE_W)-1];
   reg [31:0] expected;
   reg [31:0] next_a;
   reg [31:0] next_b;
   integer vec_fd, fail_fd, n_read, next_funct, waited;
   integer sent = 0;
   integer received = 0;
   integer fails = 0;

   function is_nan(input [31:0] x);
      is_nan = (&x[30:23]) & (|x[22:0]);
   endfunction

   always @(negedge clk) begin
      if (valid_o) begin
         if (received >= sent) begin
            fails = fails + 1;
         end else begin
            expected = queue[received%(1<<QUEUE_W)];
            if (!(res === expected || (is_nan(res) === 1'b1 && is_nan(expected)))) begin
               fails = fails + 1;
               $fdisplay(fail_fd, "%0d %h %h", received, expected, res);
            end
         end
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
      vec_fd  = $fopen("mix.tv", "r");
      fail_fd = $fopen("fails_mix.tv", "w");
      if (vec_fd == 0) begin
         $display("FPU_MIX ERROR: cannot open mix.tv");
         $finish;
      end

      repeat (2) @(posedge clk);
      rst = 1;
      repeat (10) @(posedge clk);
      rst = 0;
      repeat (2) @(posedge clk);
      #1;

      n_read = $fscanf(vec_fd, "%d %h %h %h\n", next_funct, next_a, next_b, expected);
      while (n_read == 4) begin
         funct                    = next_funct[1:0];
         op_a                     = next_a;
         op_b                     = next_b;
         valid_i                  = 1;
         queue[sent%(1<<QUEUE_W)] = expected;
         sent                     = sent + 1;
         @(posedge clk);
         #1;
         if (next_funct == 3) begin
            valid_i = 0;
            funct   = 0;
            wait_results;
            @(posedge clk);
            #1;
         end
         n_read = $fscanf(vec_fd, "%d %h %h %h\n", next_funct, next_a, next_b, expected);
      end
      valid_i = 0;
      wait_results;
      repeat (8) @(posedge clk);

      fails = fails + ((received < sent) ? sent - received : 0);
      $fclose(vec_fd);
      $fclose(fail_fd);
      $display("FPU_MIX vectors=%0d received=%0d fails=%0d", sent, received, fails);
      $finish;
   end

   always #(CLK_PER / 2) clk = ~clk;

endmodule
