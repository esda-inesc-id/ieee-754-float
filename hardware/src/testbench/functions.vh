//
// Count leading zeros in a double's significand
//
function [$clog2(53+1)-1:0] clz;
   input [51:0] f;
   integer      i;

   begin
      clz = 53;
      for (i=0; i < 52; i=i+1) begin
         if (f[i]) begin
            clz = 52 - i;
         end
      end
   end
endfunction

//
// Convert real to binary
//
function [DATA_W-1:0] float2bin;
   input real     x;
   reg [63:0]     x_d;
   reg signed [10:0] exp_d;
   reg [2*53+3-1:0]  frac;
   reg [10:0]        shift;

   begin
      x_d = $realtobits(x);

      float2bin[DATA_W-1] = x_d[63];
      frac = {1'b1, x_d[51:0], {(53+3){1'b0}}};

      exp_d = x_d[62 -: 11] - 1023 + BIAS;
      if (exp_d > (BIAS << 1)) begin
         exp_d = -1;
      end else if (exp_d < 0) begin
         shift = 1 - exp_d;
         if (shift > (53+3)) shift = 53+3;
         exp_d = 0;
         frac = frac >> shift;
      end
      float2bin[DATA_W-2 -: EXP_W] = exp_d[0 +: EXP_W];
      float2bin[DATA_W-EXP_W-2 -: DATA_W-EXP_W-1] = frac[2*53+3-2 -: DATA_W-EXP_W-1];
   end
endfunction

//
// Convert binary to real
//
function real bin2float;
   input [DATA_W-1:0] x;
   reg [63:0]         x_d;
   reg [51:0]         frac;
   reg [$clog2(53+1)-1:0] shift;

   begin
      x_d[63] = x[DATA_W-1];
      frac = {x[DATA_W-EXP_W-2 -: DATA_W-EXP_W-1], {(52-(DATA_W-EXP_W-1)){1'b0}}};
      if (x[DATA_W-2 -: EXP_W] == {EXP_W{1'b1}}) begin
         x_d[62 -: 11] = {11{1'b1}};
      end else if (x[DATA_W-2 -: EXP_W] == 'd0) begin
         shift = clz(frac);
         if (shift == 53) begin
            x_d[62 -: 11] = 0;
         end else begin
            x_d[62 -: 11] = 1 - BIAS - shift + 1023;
            frac = frac << shift;
         end
      end else begin
         x_d[62 -: 11] = x[DATA_W-2 -: EXP_W] - BIAS + 1023;
      end
      x_d[63-12 -: 52] = frac;
      bin2float = $bitstoreal(x_d);
   end
endfunction

//
// Read double from binary file
//
function real fread_d;
   input integer fd;
   reg [7:0]     byte_mem [0:7];
   reg [63:0]    d;

   begin
      d = -1;
      if (!$feof(fd)) begin
         if ($fread(byte_mem, fd)) begin
            d = {byte_mem[7], byte_mem[6], byte_mem[5], byte_mem[4], byte_mem[3], byte_mem[2], byte_mem[1], byte_mem[0]};
         end
      end
      fread_d = $bitstoreal(d);
   end
endfunction
