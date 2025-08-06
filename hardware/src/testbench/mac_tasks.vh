      while (done) #clk_per;

      //
      // Simple Test
      //
      $display("\nSimple Test\n");

      op_b = 1.0;
      start = 1;

      fp = $fopen("../../src/testbench/simple.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 0; i < 4; i = i+1) begin
         op_a = vfio[i];
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Cos(i)
      //
      $display("\nCos(i)\n");

      op_b = 1.0;
      start = 1;

      /*fp = $fopen("../../src/testbench/cos.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);*/
      for (i = 1; i <= 5000; i = i+1) begin
         op_a = $cos($itor(i));
         #clk_per;
      end

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Sum(1/i)
      //
      $display("\nSum(1/i)\n");

      op_b = 1.0;
      start = 1;

      fp = $fopen("../../src/testbench/sumi.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 1; i <= 100000; i = i+1) begin
         op_a = 1.0/$itor(i);
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Sum(1/i**2)
      //
      $display("\nSum(1/i**2)\n");

      op_b = 1.0;
      start = 1;

      fp = $fopen("../../src/testbench/sumi2.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 1; i <= 100000; i = i+1) begin
         op_a = 1.0/($itor(i)*$itor(i));
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Taylor Series
      //
      $display("\nTaylor Series exp(-2.0 * PI)\n");

      x = 1.0;
      fact = 1.0;
      op_a = 1.0;
      op_b = 1.0;
      start = 1;
      #clk_per;

      fp = $fopen("../../src/testbench/taylor.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 1; i <= 64; i = i+1) begin
         x = x * $exp(-2.0 * `PI);
         fact = fact * $itor(i);
         op_a = x / fact;
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Normal distribution
      //
      $display("\nNormal distribution (0,1)\n");

      op_b = 1.0;
      start = 1;

      fp = $fopen("../../src/testbench/normal.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 0; i < 4096; i = i+1) begin
         op_a = randn(0.0, 1.0);
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Random 10**-35 <= 10**+35
      //
      $display("\nRandom 10**-35 <= 10**+35\n");

      op_b = 1.0;
      start = 1;

      fp = $fopen("../../src/testbench/random.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 0; i < 4096; i = i+1) begin
         p = randn(0.0, 35.0);
         if (p > 35.0) p = 35.0;
         else if (p < -35.0) p = -35.0;
         op_a = $pow(10.0, p);
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Equally spaced in [1,2]
      //
      $display("\nEqually spaced in [1,2]\n");

      op_a = 1.0;
      op_b = 1.0;
      start = 1;
      #clk_per;

      fp = $fopen("../../src/testbench/equally.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 0; i < 4096; i = i+1) begin
         op_a = 1.0 + $itor(i) / 4096.0;
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // Heavy Cancellation
      //
      $display("\nHeavy Cancellation\n");

      op_b = 1.0;
      start = 1;

      fp = $fopen("../../src/testbench/heavy.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 1; i <= 4096; i = i+1) begin
         if (i < 2048) op_a = 1.0;
         else if (i < 2050) op_a = 1.0e-18;
         else op_a = -1.0;
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;

      //
      // One large, many small
      //
      $display("\nOne large, many small\n");

      op_a = 1.0;
      op_b = 1.0;
      start = 1;
      #clk_per;

      fp = $fopen("../../src/testbench/large.bin","rb");
      while(!$feof(fp)) begin
         op_a = fread_d(fp);
         if (!$feof(fp)) #clk_per;
      end
      $fclose(fp);
      /*for (i = 2; i <= 1000001; i = i+1) begin
         op_a = 1.0e-16;
         #clk_per;
      end*/

      start = 0;

      while (~done) #clk_per;
      ea = `ABS(acc - res);
      er = acc? ea / `ABS(acc): ea;

      $display("%.16g ptf: er=%.16g ea=%.16g", res, er, ea);
      $display("%.16g", acc);

      while (done) #clk_per;
