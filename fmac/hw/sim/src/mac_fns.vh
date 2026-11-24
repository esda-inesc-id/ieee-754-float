real ea, er;
integer i;

integer fp;

real x, fact;
real p;

real vfio[0:3];
initial begin
   vfio[0] = 2.62;
   vfio[1] = -10.5;
   vfio[2] = 0.1;
   vfio[3] = 5.0;
end

real X1, X2;
real call = 0;

function real randn;
   input real mu;
   input real sigma;
   real U1, U2, W, mult;

   begin
      if (call) begin
         randn = mu + sigma * X2;
      end else begin
         do begin
            U1 = -1.0 + $itor($random & `RANDMAX) / $itor(`RANDMAX) * 2.0;
            U2 = -1.0 + $itor($random & `RANDMAX) / $itor(`RANDMAX) * 2.0;
            W  = U1 * U1 + U2 * U2;
         end while (W >= 1.0 || W == 0.0);

         mult  = $sqrt(-2.0 * $ln(W) / W);
         X1    = U1 * mult;
         X2    = U2 * mult;

         randn = mu + sigma * X1;
      end

      call = !call;
   end
endfunction

