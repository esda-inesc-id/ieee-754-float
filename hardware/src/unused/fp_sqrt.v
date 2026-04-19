`timescale 1ns / 1ps

module fp_sqrt #(
                 parameter DATA_W = 32,
                 parameter EXP_W = 8
                )
   (
    input                   clk,
    input                   rst,

    input                   start,
    output reg              done,

    input [DATA_W-1:0]      op,

    output                  overflow,
    output                  underflow,
    output                  exception,

    output reg [DATA_W-1:0] res
    );

   localparam MAN_W = DATA_W-EXP_W;
   localparam BIAS = 2**(EXP_W-1)-1;
   localparam EXTRA = 3;

   // Unpack
   wire                     A_nsub = |op[DATA_W-2 -: EXP_W];

   wire                     A_sub = ~A_nsub;

   wire                     A_sign = op[DATA_W-1];
   wire [EXP_W-1:0]         A_Exponent = {op[DATA_W-2 -: EXP_W-1], A_sub | op[DATA_W-EXP_W-1]};
   wire [MAN_W-1:0]         A_Mantissa = {A_nsub, op[MAN_W-2:0]};

   // pipeline stage 1
   reg                      A_sign_reg;
   reg [EXP_W-1:0]          A_Exponent_reg;
   reg [MAN_W-1:0]          A_Mantissa_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= {EXP_W{1'b0}};
         A_Mantissa_reg <= {MAN_W{1'b0}};
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;
      end
   end

   // Square root
   wire                     Temp_sign = A_sign_reg;
   wire [EXP_W-1:0]         Temp_Exponent = ((A_Exponent_reg - BIAS) >> 1) + BIAS;
   wire [MAN_W+EXTRA-1:0]   Temp_Mantissa; // = sqrt(A_Mantissa_reg);
   wire                     sqrt_done;
   int_sqrt # (
               .DATA_W(2*(MAN_W+EXTRA))
               )
   int_sqrt (
             .clk   (clk),
             .rst   (rst),

             .start (start),
             .done  (sqrt_done),

             .op    ({1'b0, A_Mantissa, {(MAN_W+2*EXTRA-1){1'b0}}}),
             .res   (Temp_Mantissa)
             );

   reg                      sqrt_done_reg;
   wire                     done_int = sqrt_done & ~sqrt_done_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         sqrt_done_reg <= 1'b1;
      end else begin
         sqrt_done_reg <= sqrt_done;
      end
   end

   // pipeline stage 2
   reg                      Temp_sign_reg;
   reg [EXP_W-1:0]          Temp_Exponent_reg;
   reg [MAN_W+EXTRA-1:0]    Temp_Mantissa_reg;

   reg                      done_reg;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         Temp_sign_reg <= 1'b0;
         Temp_Exponent_reg <= {EXP_W{1'b0}};
         Temp_Mantissa_reg <= {(MAN_W+EXTRA){1'b0}};

         done_reg <= 1'b0;
      end else begin
         Temp_sign_reg <= Temp_sign;
         Temp_Exponent_reg <= Temp_Exponent;
         Temp_Mantissa_reg <= Temp_Mantissa;

         done_reg <= done_int;
      end
   end

   // Normalize
   localparam LSC_W = $clog2(MAN_W+EXTRA+1);

   wire [LSC_W-1:0] lzc_int;
   clz #(
         .DATA_W(MAN_W+EXTRA)
         )
   clz0
     (
      .data_in  (Temp_Mantissa_reg),
      .data_out (lzc_int)
      );

   wire [LSC_W-1:0]         lzc = ({{(EXP_W-LSC_W){1'b0}}, lzc_int} > Temp_Exponent_reg)? Temp_Exponent_reg[LSC_W-1:0]: lzc_int;

   wire [EXP_W-1:0]         exp_adjust = Temp_Exponent_reg - {{(EXP_W-LSC_W){1'b0}}, lzc};
   wire [MAN_W+EXTRA-1:0]   man_adjust = Temp_Mantissa_reg << lzc;

   // pipeline stage 3
   reg                      Temp_sign_reg2;

   reg [EXP_W-1:0]          exp_adjust_reg;
   reg [MAN_W+EXTRA-1:0]    man_adjust_reg;

   reg                      done_reg2;
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         Temp_sign_reg2 <= 1'b0;

         exp_adjust_reg <= {EXP_W{1'b0}};
         man_adjust_reg <= {(MAN_W+EXTRA){1'b0}};

         done_reg2 <= 1'b0;
      end else begin
         Temp_sign_reg2 <= Temp_sign_reg;

         exp_adjust_reg <= exp_adjust;
         man_adjust_reg <= man_adjust;

         done_reg2 <= done_reg;
      end
   end

   // Round
   wire [EXP_W-1:0]         exp_adjust_rnd;
   wire [MAN_W-1:0]         man_adjust_rnd;
   wire                     round;
   round #(
           .DATA_W (MAN_W),
           .EXP_W  (EXP_W)
           )
   round0
     (
      .exponent_i (exp_adjust_reg),
      .mantissa_i (man_adjust_reg),
      .cin        (1'b0),

      .exponent_o (exp_adjust_rnd),
      .mantissa_o (man_adjust_rnd),
      .round      (round)
      );

   wire                     nzero = |man_adjust_reg[MAN_W+EXTRA-1:3] | round;

   // Pack
   wire [MAN_W-2:0]         Fraction = man_adjust_rnd[MAN_W-2:0];
   wire [EXP_W-1:0]         Exponent = man_adjust_rnd[MAN_W-1]? exp_adjust_rnd: {EXP_W{1'b0}};
   wire                     Sign     = nzero & Temp_sign_reg2;

   // pipeline stage 4
   always @(posedge clk, posedge rst) begin
      if (rst) begin
         res <= {DATA_W{1'b0}};
         done <= 1'b0;
      end else begin
         res <= {Sign, Exponent, Fraction};
         done <= done_reg2;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
