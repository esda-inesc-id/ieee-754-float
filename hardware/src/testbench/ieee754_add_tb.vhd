--------------------------------------------------------------------------------
--                RightShifterSticky26_by_max_25_Freq300_uid4
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Bogdan Pasca (2008-2011), Florent de Dinechin (2008-2019)
--------------------------------------------------------------------------------
-- Pipeline depth: 1 cycles
-- Clock period (ns): 3.33333
-- Target frequency (MHz): 300
-- Input signals: X S
-- Output signals: R Sticky

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library std;
use std.textio.all;
library work;

entity RightShifterSticky26_by_max_25_Freq300_uid4 is
    port (clk : in std_logic;
          X : in  std_logic_vector(25 downto 0);
          S : in  std_logic_vector(4 downto 0);
          R : out  std_logic_vector(25 downto 0);
          Sticky : out  std_logic   );
end entity;

architecture arch of RightShifterSticky26_by_max_25_Freq300_uid4 is
signal ps, ps_d1 :  std_logic_vector(4 downto 0);
signal Xpadded :  std_logic_vector(25 downto 0);
signal level5 :  std_logic_vector(25 downto 0);
signal stk4 :  std_logic;
signal level4 :  std_logic_vector(25 downto 0);
signal stk3 :  std_logic;
signal level3 :  std_logic_vector(25 downto 0);
signal stk2, stk2_d1 :  std_logic;
signal level2, level2_d1 :  std_logic_vector(25 downto 0);
signal stk1 :  std_logic;
signal level1, level1_d1 :  std_logic_vector(25 downto 0);
signal stk0 :  std_logic;
signal level0 :  std_logic_vector(25 downto 0);
begin
   process(clk)
      begin
         if clk'event and clk = '1' then
            ps_d1 <=  ps;
            stk2_d1 <=  stk2;
            level2_d1 <=  level2;
            level1_d1 <=  level1;
         end if;
      end process;
   ps<= S;
   Xpadded <= X;
   level5<= Xpadded;
   stk4 <= '1' when (level5(15 downto 0)/="0000000000000000" and ps(4)='1')   else '0';
   level4 <=  level5 when  ps(4)='0'    else (15 downto 0 => '0') & level5(25 downto 16);
   stk3 <= '1' when (level4(7 downto 0)/="00000000" and ps(3)='1') or stk4 ='1'   else '0';
   level3 <=  level4 when  ps(3)='0'    else (7 downto 0 => '0') & level4(25 downto 8);
   stk2 <= '1' when (level3(3 downto 0)/="0000" and ps(2)='1') or stk3 ='1'   else '0';
   level2 <=  level3 when  ps(2)='0'    else (3 downto 0 => '0') & level3(25 downto 4);
   stk1 <= '1' when (level2_d1(1 downto 0)/="00" and ps_d1(1)='1') or stk2_d1 ='1'   else '0';
   level1 <=  level2 when  ps(1)='0'    else (1 downto 0 => '0') & level2(25 downto 2);
   stk0 <= '1' when (level1_d1(0 downto 0)/="0" and ps_d1(0)='1') or stk1 ='1'   else '0';
   level0 <=  level1 when  ps(0)='0'    else (0 downto 0 => '0') & level1(25 downto 1);
   R <= level0;
   Sticky <= stk0;
end architecture;

--------------------------------------------------------------------------------
--                          IntAdder_27_Freq300_uid6
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Bogdan Pasca, Florent de Dinechin (2008-2016)
--------------------------------------------------------------------------------
-- Pipeline depth: 1 cycles
-- Clock period (ns): 3.33333
-- Target frequency (MHz): 300
-- Input signals: X Y Cin
-- Output signals: R

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library std;
use std.textio.all;
library work;

entity IntAdder_27_Freq300_uid6 is
    port (clk : in std_logic;
          X : in  std_logic_vector(26 downto 0);
          Y : in  std_logic_vector(26 downto 0);
          Cin : in  std_logic;
          R : out  std_logic_vector(26 downto 0)   );
end entity;

architecture arch of IntAdder_27_Freq300_uid6 is
signal Rtmp :  std_logic_vector(26 downto 0);
signal X_d1 :  std_logic_vector(26 downto 0);
signal Y_d1 :  std_logic_vector(26 downto 0);
begin
   process(clk)
      begin
         if clk'event and clk = '1' then
            X_d1 <=  X;
            Y_d1 <=  Y;
         end if;
      end process;
   Rtmp <= X_d1 + Y_d1 + Cin;
   R <= Rtmp;
end architecture;

--------------------------------------------------------------------------------
--                            LZC_26_Freq300_uid8
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Florent de Dinechin, Bogdan Pasca (2007)
--------------------------------------------------------------------------------
-- Pipeline depth: 0 cycles
-- Clock period (ns): 3.33333
-- Target frequency (MHz): 300
-- Input signals: I
-- Output signals: O

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library std;
use std.textio.all;
library work;

entity LZC_26_Freq300_uid8 is
    port (clk : in std_logic;
          I : in  std_logic_vector(25 downto 0);
          O : out  std_logic_vector(4 downto 0)   );
end entity;

architecture arch of LZC_26_Freq300_uid8 is
signal level5 :  std_logic_vector(30 downto 0);
signal digit4 :  std_logic;
signal level4 :  std_logic_vector(14 downto 0);
signal digit3 :  std_logic;
signal level3 :  std_logic_vector(6 downto 0);
signal digit2 :  std_logic;
signal level2 :  std_logic_vector(2 downto 0);
signal lowBits :  std_logic_vector(1 downto 0);
signal outHighBits :  std_logic_vector(2 downto 0);
begin
   -- pad input to the next power of two minus 1
   level5 <= I & "11111";
   -- Main iteration for large inputs
   digit4<= '1' when level5(30 downto 15) = "0000000000000000" else '0';
   level4<= level5(14 downto 0) when digit4='1' else level5(30 downto 16);
   digit3<= '1' when level4(14 downto 7) = "00000000" else '0';
   level3<= level4(6 downto 0) when digit3='1' else level4(14 downto 8);
   digit2<= '1' when level3(6 downto 3) = "0000" else '0';
   level2<= level3(2 downto 0) when digit2='1' else level3(6 downto 4);
   -- Finish counting with one LUT
   with level2  select  lowBits <= 
      "11" when "000",
      "10" when "001",
      "01" when "010",
      "01" when "011",
      "00" when others;
   outHighBits <= digit4 & digit3 & digit2 & "";
   O <= outHighBits & lowBits ;
end architecture;

--------------------------------------------------------------------------------
--                   LeftShifter27_by_max_26_Freq300_uid10
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Bogdan Pasca (2008-2011), Florent de Dinechin (2008-2019)
--------------------------------------------------------------------------------
-- Pipeline depth: 1 cycles
-- Clock period (ns): 3.33333
-- Target frequency (MHz): 300
-- Input signals: X S
-- Output signals: R

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library std;
use std.textio.all;
library work;

entity LeftShifter27_by_max_26_Freq300_uid10 is
    port (clk : in std_logic;
          X : in  std_logic_vector(26 downto 0);
          S : in  std_logic_vector(4 downto 0);
          R : out  std_logic_vector(52 downto 0)   );
end entity;

architecture arch of LeftShifter27_by_max_26_Freq300_uid10 is
signal ps :  std_logic_vector(4 downto 0);
signal level0, level0_d1 :  std_logic_vector(26 downto 0);
signal level1 :  std_logic_vector(27 downto 0);
signal level2 :  std_logic_vector(29 downto 0);
signal level3 :  std_logic_vector(33 downto 0);
signal level4 :  std_logic_vector(41 downto 0);
signal level5 :  std_logic_vector(57 downto 0);
begin
   process(clk)
      begin
         if clk'event and clk = '1' then
            level0_d1 <=  level0;
         end if;
      end process;
   ps<= S;
   level0<= X;
   level1<= level0_d1 & (0 downto 0 => '0') when ps(0)= '1' else     (0 downto 0 => '0') & level0_d1;
   level2<= level1 & (1 downto 0 => '0') when ps(1)= '1' else     (1 downto 0 => '0') & level1;
   level3<= level2 & (3 downto 0 => '0') when ps(2)= '1' else     (3 downto 0 => '0') & level2;
   level4<= level3 & (7 downto 0 => '0') when ps(3)= '1' else     (7 downto 0 => '0') & level3;
   level5<= level4 & (15 downto 0 => '0') when ps(4)= '1' else     (15 downto 0 => '0') & level4;
   R <= level5(52 downto 0);
end architecture;

--------------------------------------------------------------------------------
--                         IntAdder_31_Freq300_uid13
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Bogdan Pasca, Florent de Dinechin (2008-2016)
--------------------------------------------------------------------------------
-- Pipeline depth: 3 cycles
-- Clock period (ns): 3.33333
-- Target frequency (MHz): 300
-- Input signals: X Y Cin
-- Output signals: R

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library std;
use std.textio.all;
library work;

entity IntAdder_31_Freq300_uid13 is
    port (clk : in std_logic;
          X : in  std_logic_vector(30 downto 0);
          Y : in  std_logic_vector(30 downto 0);
          Cin : in  std_logic;
          R : out  std_logic_vector(30 downto 0)   );
end entity;

architecture arch of IntAdder_31_Freq300_uid13 is
signal Cin_0, Cin_0_d1 :  std_logic;
signal X_0, X_0_d1 :  std_logic_vector(16 downto 0);
signal Y_0, Y_0_d1, Y_0_d2, Y_0_d3 :  std_logic_vector(16 downto 0);
signal S_0 :  std_logic_vector(16 downto 0);
signal R_0 :  std_logic_vector(15 downto 0);
signal Cin_1 :  std_logic;
signal X_1, X_1_d1 :  std_logic_vector(15 downto 0);
signal Y_1, Y_1_d1, Y_1_d2, Y_1_d3 :  std_logic_vector(15 downto 0);
signal S_1 :  std_logic_vector(15 downto 0);
signal R_1 :  std_logic_vector(14 downto 0);
begin
   process(clk)
      begin
         if clk'event and clk = '1' then
            Cin_0_d1 <=  Cin_0;
            X_0_d1 <=  X_0;
            Y_0_d1 <=  Y_0;
            Y_0_d2 <=  Y_0_d1;
            Y_0_d3 <=  Y_0_d2;
            X_1_d1 <=  X_1;
            Y_1_d1 <=  Y_1;
            Y_1_d2 <=  Y_1_d1;
            Y_1_d3 <=  Y_1_d2;
         end if;
      end process;
   Cin_0 <= Cin;
   X_0 <= '0' & X(15 downto 0);
   Y_0 <= '0' & Y(15 downto 0);
   S_0 <= X_0_d1 + Y_0_d3 + Cin_0_d1;
   R_0 <= S_0(15 downto 0);
   Cin_1 <= S_0(16);
   X_1 <= '0' & X(30 downto 16);
   Y_1 <= '0' & Y(30 downto 16);
   S_1 <= X_1_d1 + Y_1_d3 + Cin_1;
   R_1 <= S_1(14 downto 0);
   R <= R_1 & R_0 ;
end architecture;

--------------------------------------------------------------------------------
--                        IEEEFPAdd_8_23_Freq300_uid2
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Florent de Dinechin, Valentin Huguet (2016)
--------------------------------------------------------------------------------
-- Pipeline depth: 3 cycles
-- Clock period (ns): 3.33333
-- Target frequency (MHz): 300
-- Input signals: X Y
-- Output signals: R

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library std;
use std.textio.all;
library work;

entity IEEEFPAdd_8_23_Freq300_uid2 is
    port (clk : in std_logic;
          X : in  std_logic_vector(31 downto 0);
          Y : in  std_logic_vector(31 downto 0);
          R : out  std_logic_vector(31 downto 0)   );
end entity;

architecture arch of IEEEFPAdd_8_23_Freq300_uid2 is
   component RightShifterSticky26_by_max_25_Freq300_uid4 is
      port ( clk : in std_logic;
             X : in  std_logic_vector(25 downto 0);
             S : in  std_logic_vector(4 downto 0);
             R : out  std_logic_vector(25 downto 0);
             Sticky : out  std_logic   );
   end component;

   component IntAdder_27_Freq300_uid6 is
      port ( clk : in std_logic;
             X : in  std_logic_vector(26 downto 0);
             Y : in  std_logic_vector(26 downto 0);
             Cin : in  std_logic;
             R : out  std_logic_vector(26 downto 0)   );
   end component;

   component LZC_26_Freq300_uid8 is
      port ( clk : in std_logic;
             I : in  std_logic_vector(25 downto 0);
             O : out  std_logic_vector(4 downto 0)   );
   end component;

   component LeftShifter27_by_max_26_Freq300_uid10 is
      port ( clk : in std_logic;
             X : in  std_logic_vector(26 downto 0);
             S : in  std_logic_vector(4 downto 0);
             R : out  std_logic_vector(52 downto 0)   );
   end component;

   component IntAdder_31_Freq300_uid13 is
      port ( clk : in std_logic;
             X : in  std_logic_vector(30 downto 0);
             Y : in  std_logic_vector(30 downto 0);
             Cin : in  std_logic;
             R : out  std_logic_vector(30 downto 0)   );
   end component;

signal expFracX :  std_logic_vector(30 downto 0);
signal expFracY :  std_logic_vector(30 downto 0);
signal expXmExpY :  std_logic_vector(8 downto 0);
signal expYmExpX :  std_logic_vector(8 downto 0);
signal swap :  std_logic;
signal newX :  std_logic_vector(31 downto 0);
signal newY :  std_logic_vector(31 downto 0);
signal expDiff :  std_logic_vector(8 downto 0);
signal expNewX, expNewX_d1, expNewX_d2 :  std_logic_vector(7 downto 0);
signal expNewY :  std_logic_vector(7 downto 0);
signal signNewX, signNewX_d1, signNewX_d2, signNewX_d3 :  std_logic;
signal signNewY, signNewY_d1, signNewY_d2, signNewY_d3 :  std_logic;
signal EffSub, EffSub_d1, EffSub_d2, EffSub_d3 :  std_logic;
signal xExpFieldZero, xExpFieldZero_d1, xExpFieldZero_d2 :  std_logic;
signal yExpFieldZero :  std_logic;
signal xExpFieldAllOnes :  std_logic;
signal yExpFieldAllOnes :  std_logic;
signal xSigFieldZero :  std_logic;
signal ySigFieldZero :  std_logic;
signal xIsNaN :  std_logic;
signal yIsNaN :  std_logic;
signal xIsInfinity, xIsInfinity_d1, xIsInfinity_d2, xIsInfinity_d3 :  std_logic;
signal yIsInfinity, yIsInfinity_d1, yIsInfinity_d2, yIsInfinity_d3 :  std_logic;
signal xIsZero, xIsZero_d1, xIsZero_d2, xIsZero_d3 :  std_logic;
signal yIsZero, yIsZero_d1, yIsZero_d2, yIsZero_d3 :  std_logic;
signal bothSubNormals :  std_logic;
signal resultIsNaN, resultIsNaN_d1, resultIsNaN_d2, resultIsNaN_d3 :  std_logic;
signal significandNewX :  std_logic_vector(23 downto 0);
signal significandNewY :  std_logic_vector(23 downto 0);
signal allShiftedOut :  std_logic;
signal rightShiftValue :  std_logic_vector(4 downto 0);
signal shiftCorrection :  std_logic;
signal finalRightShiftValue :  std_logic_vector(4 downto 0);
signal significandY00 :  std_logic_vector(25 downto 0);
signal shiftedSignificandY :  std_logic_vector(25 downto 0);
signal stickyLow, stickyLow_d1 :  std_logic;
signal summandY :  std_logic_vector(26 downto 0);
signal summandX :  std_logic_vector(26 downto 0);
signal carryIn :  std_logic;
signal significandZ :  std_logic_vector(26 downto 0);
signal z1, z1_d1 :  std_logic;
signal z0, z0_d1 :  std_logic;
signal lzcZInput :  std_logic_vector(25 downto 0);
signal lzc, lzc_d1 :  std_logic_vector(4 downto 0);
signal leftShiftVal :  std_logic_vector(4 downto 0);
signal normalizedSignificand :  std_logic_vector(52 downto 0);
signal significandPreRound :  std_logic_vector(22 downto 0);
signal lsb :  std_logic;
signal roundBit :  std_logic;
signal stickyBit :  std_logic;
signal deltaExp, deltaExp_d1 :  std_logic_vector(7 downto 0);
signal fullCancellation, fullCancellation_d1 :  std_logic;
signal expPreRound :  std_logic_vector(7 downto 0);
signal expSigPreRound :  std_logic_vector(30 downto 0);
signal roundUpBit :  std_logic;
signal expSigR :  std_logic_vector(30 downto 0);
signal resultIsZero :  std_logic;
signal resultIsInf :  std_logic;
signal constInf, constInf_d1, constInf_d2, constInf_d3 :  std_logic_vector(30 downto 0);
signal constNaN, constNaN_d1, constNaN_d2, constNaN_d3 :  std_logic_vector(30 downto 0);
signal expSigR2 :  std_logic_vector(30 downto 0);
signal signR :  std_logic;
signal computedR :  std_logic_vector(31 downto 0);
begin
   process(clk)
      begin
         if clk'event and clk = '1' then
            expNewX_d1 <=  expNewX;
            expNewX_d2 <=  expNewX_d1;
            signNewX_d1 <=  signNewX;
            signNewX_d2 <=  signNewX_d1;
            signNewX_d3 <=  signNewX_d2;
            signNewY_d1 <=  signNewY;
            signNewY_d2 <=  signNewY_d1;
            signNewY_d3 <=  signNewY_d2;
            EffSub_d1 <=  EffSub;
            EffSub_d2 <=  EffSub_d1;
            EffSub_d3 <=  EffSub_d2;
            xExpFieldZero_d1 <=  xExpFieldZero;
            xExpFieldZero_d2 <=  xExpFieldZero_d1;
            xIsInfinity_d1 <=  xIsInfinity;
            xIsInfinity_d2 <=  xIsInfinity_d1;
            xIsInfinity_d3 <=  xIsInfinity_d2;
            yIsInfinity_d1 <=  yIsInfinity;
            yIsInfinity_d2 <=  yIsInfinity_d1;
            yIsInfinity_d3 <=  yIsInfinity_d2;
            xIsZero_d1 <=  xIsZero;
            xIsZero_d2 <=  xIsZero_d1;
            xIsZero_d3 <=  xIsZero_d2;
            yIsZero_d1 <=  yIsZero;
            yIsZero_d2 <=  yIsZero_d1;
            yIsZero_d3 <=  yIsZero_d2;
            resultIsNaN_d1 <=  resultIsNaN;
            resultIsNaN_d2 <=  resultIsNaN_d1;
            resultIsNaN_d3 <=  resultIsNaN_d2;
            stickyLow_d1 <=  stickyLow;
            z1_d1 <=  z1;
            z0_d1 <=  z0;
            lzc_d1 <=  lzc;
            deltaExp_d1 <=  deltaExp;
            fullCancellation_d1 <=  fullCancellation;
            constInf_d1 <=  constInf;
            constInf_d2 <=  constInf_d1;
            constInf_d3 <=  constInf_d2;
            constNaN_d1 <=  constNaN;
            constNaN_d2 <=  constNaN_d1;
            constNaN_d3 <=  constNaN_d2;
         end if;
      end process;

   -- Exponent difference and swap
   expFracX <= X(30 downto 0);
   expFracY <= Y(30 downto 0);
   expXmExpY <= ('0' & X(30 downto 23)) - ('0'  & Y(30 downto 23)) ;
   expYmExpX <= ('0' & Y(30 downto 23)) - ('0'  & X(30 downto 23)) ;
   swap <= '0' when expFracX >= expFracY else '1';
   newX <= X when swap = '0' else Y;
   newY <= Y when swap = '0' else X;
   expDiff <= expXmExpY when swap = '0' else expYmExpX;
   expNewX <= newX(30 downto 23);
   expNewY <= newY(30 downto 23);
   signNewX <= newX(31);
   signNewY <= newY(31);
   EffSub <= signNewX xor signNewY;
   -- Special case dectection
   xExpFieldZero <= '1' when expNewX="00000000" else '0';
   yExpFieldZero <= '1' when expNewY="00000000" else '0';
   xExpFieldAllOnes <= '1' when expNewX="11111111" else '0';
   yExpFieldAllOnes <= '1' when expNewY="11111111" else '0';
   xSigFieldZero <= '1' when newX(22 downto 0)="00000000000000000000000" else '0';
   ySigFieldZero <= '1' when newY(22 downto 0)="00000000000000000000000" else '0';
   xIsNaN <= xExpFieldAllOnes and not xSigFieldZero;
   yIsNaN <= yExpFieldAllOnes and not ySigFieldZero;
   xIsInfinity <= xExpFieldAllOnes and xSigFieldZero;
   yIsInfinity <= yExpFieldAllOnes and ySigFieldZero;
   xIsZero <= xExpFieldZero and xSigFieldZero;
   yIsZero <= yExpFieldZero and ySigFieldZero;
   bothSubNormals <=  xExpFieldZero and yExpFieldZero;
   resultIsNaN <=  xIsNaN or yIsNaN  or  (xIsInfinity and yIsInfinity and EffSub);
   significandNewX <= not(xExpFieldZero) & newX(22 downto 0);
   significandNewY <= not(yExpFieldZero) & newY(22 downto 0);

   -- Significand alignment
   allShiftedOut <= '1' when (expDiff >= 26) else '0';
   rightShiftValue <= expDiff(4 downto 0) when allShiftedOut='0' else CONV_STD_LOGIC_VECTOR(26,5) ;
   shiftCorrection <= '1' when (yExpFieldZero='1' and xExpFieldZero='0') else '0'; -- only other cases are: both normal or both subnormal
   finalRightShiftValue <= rightShiftValue - ("0000" & shiftCorrection);
   significandY00 <= significandNewY & "00";
   RightShifterComponent: RightShifterSticky26_by_max_25_Freq300_uid4
      port map ( clk  => clk,
                 S => finalRightShiftValue,
                 X => significandY00,
                 R => shiftedSignificandY,
                 Sticky => stickyLow);
   summandY <= ('0' & shiftedSignificandY) xor (26 downto 0 => EffSub);


   -- Significand addition
   summandX <= '0' & significandNewX & '0' & '0';
   carryIn <= EffSub_d1 and not stickyLow;
   fracAdder: IntAdder_27_Freq300_uid6
      port map ( clk  => clk,
                 Cin => carryIn,
                 X => summandX,
                 Y => summandY,
                 R => significandZ);

   -- Cancellation detection, renormalization (see explanations in IEEEFPAdd.cpp) 
   z1 <=  significandZ(26); -- bit of weight 1
   z0 <=  significandZ(25); -- bit of weight 0
   lzcZInput <= significandZ(26 downto 1);
   IEEEFPAdd_8_23_Freq300_uid2LeadingZeroCounter: LZC_26_Freq300_uid8
      port map ( clk  => clk,
                 I => lzcZInput,
                 O => lzc);
   leftShiftVal <= 
      lzc_d1 when ((z1_d1='1') or (z1_d1='0' and z0_d1='1' and xExpFieldZero_d2='1') or (z1_d1='0' and z0_d1='0' and xExpFieldZero_d2='0' and lzc_d1<=expNewX_d2)  or (xExpFieldZero_d2='0' and lzc_d1>=26) ) 
      else (expNewX_d2(4 downto 0)) when (xExpFieldZero_d2='0' and (lzc_d1 < 26) and (("000"&lzc_d1)>=expNewX_d2)) 
       else "0000"&'1';
   LeftShifterComponent: LeftShifter27_by_max_26_Freq300_uid10
      port map ( clk  => clk,
                 S => leftShiftVal,
                 X => significandZ,
                 R => normalizedSignificand);
   significandPreRound <= normalizedSignificand(25 downto 3); -- remove the implicit zero/one
   lsb <= normalizedSignificand(3);
   roundBit <= normalizedSignificand(2);
   stickyBit <= stickyLow_d1 or  normalizedSignificand(1)or  normalizedSignificand(0);
   deltaExp <=    -- value to subtract to exponent for normalization
      "00000000" when ( (z1='0' and z0='1' and xExpFieldZero_d1='0')
          or  (z1='0' and z0='0' and xExpFieldZero_d1='1') )
      else "11111111" when ( (z1='1')  or  (z1='0' and z0='1' and xExpFieldZero_d1='1'))
      else ("000" & lzc)-'1' when (z1='0' and z0='0' and xExpFieldZero_d1='0' and lzc<=expNewX_d1 and lzc<26)      else expNewX_d1;
   fullCancellation <= '1' when (lzc_d1>=26) else '0';
   expPreRound <= expNewX_d2 - deltaExp_d1; -- we may have a first overflow here
   expSigPreRound <= expPreRound & significandPreRound; 
   -- Final rounding, with the mantissa overflowing in the exponent  
   roundUpBit <= '1' when roundBit='1' and (stickyBit='1' or (stickyBit='0' and lsb='1')) else '0';
   roundingAdder: IntAdder_31_Freq300_uid13
      port map ( clk  => clk,
                 Cin => roundUpBit,
                 X => expSigPreRound,
                 Y => "0000000000000000000000000000000",
                 R => expSigR);
   -- Final packing
   resultIsZero <= '1' when (fullCancellation_d1='1' and expSigR(30 downto 23)="00000000") else '0';
   resultIsInf <= '1' when resultIsNaN_d3='0' and (((xIsInfinity_d3='1' and yIsInfinity_d3='1'  and EffSub_d3='0')  or (xIsInfinity_d3='0' and yIsInfinity_d3='1')  or (xIsInfinity_d3='1' and yIsInfinity_d3='0')  or  (expSigR(30 downto 23)="11111111"))) else '0';
   constInf <= "11111111" & "00000000000000000000000";
   constNaN <= "1111111111111111111111111111111";
   expSigR2 <= constInf_d3 when resultIsInf='1' else constNaN_d3 when resultIsNaN_d3='1' else expSigR;
   signR <= '0' when ((resultIsNaN_d3='1'  or (resultIsZero='1' and xIsInfinity_d3='0' and yIsInfinity_d3='0')) and (xIsZero_d3='0' or yIsZero_d3='0' or (signNewX_d3 /= signNewY_d3)) )  else signNewX_d3;
   computedR <= signR & expSigR2;
   R <= computedR;
end architecture;

--------------------------------------------------------------------------------
--            TestBench_IEEEFPAdd_8_23_Freq300_uid2_Freq300_uid15
-- VHDL generated for VirtexUltrascalePlus @ 300MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Florent de Dinechin, Cristian Klein, Nicolas Brunie (2007-2010)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
library work;

entity ieee754_add_tb is
end entity;

architecture behavorial of ieee754_add_tb is
--   component IEEEFPAdd_8_23_Freq300_uid2 is
   component ieee754_add_wrapper is
      generic (
        DATA_W: integer := 32;
        EXP_W: integer := 8
        );
      port ( clk : in std_logic;
             X : in  std_logic_vector(31 downto 0);
             Y : in  std_logic_vector(31 downto 0);
             R : out  std_logic_vector(31 downto 0)   );
   end component;
signal X :  std_logic_vector(31 downto 0);
signal Y :  std_logic_vector(31 downto 0);
signal R :  std_logic_vector(31 downto 0);
signal clk :  std_logic;
signal rst :  std_logic;
constant DATA_W : integer := 32;
constant EXP_W : integer := 8;

 -- converts std_logic into a character
   function chr(sl: std_logic) return character is
      variable c: character;
   begin
      case sl is
         when 'U' => c:= 'U';
         when 'X' => c:= 'X';
         when '0' => c:= '0';
         when '1' => c:= '1';
         when 'Z' => c:= 'Z';
         when 'W' => c:= 'W';
         when 'L' => c:= 'L';
         when 'H' => c:= 'H';
         when '-' => c:= '-';
      end case;
      return c;
   end chr;

   -- converts bit to std_logic (1 to 1)
   function to_stdlogic(b : bit) return std_logic is
       variable sl : std_logic;
   begin
      case b is 
         when '0' => sl := '0';
         when '1' => sl := '1';
      end case;
      return sl;
   end to_stdlogic;

   -- converts std_logic into a string (1 to 1)
   function str(sl: std_logic) return string is
    variable s: string(1 to 1);
    begin
      s(1) := chr(sl);
      return s;
   end str;

   -- converts std_logic_vector into a string (binary base)
   -- (this also takes care of the fact that the range of
   --  a string is natural while a std_logic_vector may
   --  have an integer range)
   function str(slv: std_logic_vector) return string is
      variable result : string (1 to slv'length);
      variable r : integer;
   begin
      r := 1;
      for i in slv'range loop
         result(r) := chr(slv(i));
         r := r + 1;
      end loop;
      return result;
   end str;

   -- test isZero
   function iszero(a : std_logic_vector) return boolean is
   begin
      return	a = (a'high downto 0 => '0');
   end;

   -- FP IEEE compare function (found vs. real)
   function fp_equal_ieee(a : std_logic_vector; b : std_logic_vector; we : integer; wf : integer) return boolean is
   begin
      if a(wf+we downto wf) = b(wf+we downto wf) and b(we+wf-1 downto wf) = (we downto 1 => '1') then
         if iszero(b(wf-1 downto 0)) then return  iszero(a(wf-1 downto 0));
         else return not iszero(a(wf - 1 downto 0));
         end if;
      else
         return a(a'high downto 0) = b(b'high downto 0);
      end if;
   end;

   function fp_inf_or_equal_ieee(a : std_logic_vector; b : std_logic_vector; we : integer; wf : integer) return boolean is
   begin
      return false; -- TODO 
   end;

   -- FP subtypes for casting
   subtype fp32 is std_logic_vector(31 downto 0);
   function testLine(testCounter:integer; expectedOutputS: string(1 to 10000); expectedOutputSize: integer; R:  std_logic_vector(31 downto 0)) return boolean is
      variable expectedOutput: line;
      variable possibilityNumber : integer;
      variable testSuccess: boolean;
      variable errorMessage: string(1 to 10000);
      variable testSuccess_R: boolean;
      variable expected_R: bit_vector (31 downto 0); -- for list of values
      variable inf_R: bit_vector (31 downto 0); -- for intervals
      variable sup_R: bit_vector (31 downto 0); -- for intervals
   begin
      write(expectedOutput, expectedOutputS);
      read(expectedOutput, possibilityNumber); -- for R
      if possibilityNumber = 0 then
         -- TODO define what it means to have 0 possible output. Currently it means a test fails...
      end if;
      if possibilityNumber > 0 then -- a list of values
      testSuccess_R := false;
         for i in 1 to possibilityNumber loop
            read(expectedOutput, expected_R);
            if expected_R="01111111111111111111111111111111" then
               expected_R:="01111111110000000000000000000000";
            end if;
            if fp_equal_ieee(R, to_stdlogicvector(expected_R), 8, 23) then
               testSuccess_R := true;
            end if;
            end loop;
      end if;
      if possibilityNumber < 0  then -- an interval
         read(expectedOutput, inf_R);
         read(expectedOutput, sup_R);
         if possibilityNumber =-1  then -- an unsigned interval
            testSuccess_R := (R >= to_stdlogicvector(inf_R)) and (R <= to_stdlogicvector(sup_R));
         elsif possibilityNumber =-2  then -- a signed interval
            testSuccess_R := (signed(R) >= signed(to_stdlogicvector(inf_R))) and (signed(R) <= signed(to_stdlogicvector(sup_R)));
         elsif possibilityNumber =-3  then -- an IEEE floating-point interval
            testSuccess_R := fp_inf_or_equal_ieee(to_stdlogicvector(inf_R), R, 8, 23) and fp_inf_or_equal_ieee(R, to_stdlogicvector(sup_R), 8, 23);
         end if;
      end if;
      if testSuccess_R = false then
         report("Test #" & integer'image(testCounter) & ", incorrect output for R: " & lf & " expected values: " & expectedOutputS(1 to expectedOutputSize) & lf  & "          result:    " & str(R) ) severity error;
      end if;
      
      testSuccess := true and testSuccess_R;
      return testSuccess;
   end testLine;

begin
   -- Ticking clock signal
   process
   begin
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
   end process;

--   test: IEEEFPAdd_8_23_Freq300_uid2
   test: ieee754_add_wrapper
      generic map (
        DATA_W => DATA_W,
        EXP_W => EXP_W
      )
      port map ( clk  => clk,
                 X => X,
                 Y => Y,
                 R => R);
   -- Process that sets the inputs  (read from a file) 
   process
      variable input, expectedOutput : line; 
      variable tmpChar : character;
      file inputsFile : text is "ieee754_add.input"; 
      variable V_X : bit_vector(31 downto 0);
      variable V_Y : bit_vector(31 downto 0);
      variable V_R : bit_vector(31 downto 0);
   begin
      -- Send reset
      rst <= '1';
      wait for 10 ns;
      rst <= '0';
      readline(inputsFile, input); -- skip the first line of advertising
      while not endfile(inputsFile) loop
         readline(inputsFile, input); -- skip the comment line
         readline(inputsFile, input);
         readline(inputsFile, expectedOutput); -- comment line, unused in this process
         readline(inputsFile, expectedOutput); -- unused in this process
         read(input ,V_X);
         read(input,tmpChar);
         X <= to_stdlogicvector(V_X);
         read(input ,V_Y);
         read(input,tmpChar);
         Y <= to_stdlogicvector(V_Y);
         wait for 10 ns;
      end loop;
         wait for 130 ns; -- wait for pipeline to flush (and some more)
   end process;

    -- Process that verifies the corresponding output
   process
      file inputsFile : text is "ieee754_add.input"; 
      variable input, expectedOutput : line; 
      variable testCounter : integer := 1;
      variable errorCounter : integer := 0;
      variable expectedOutputString : string(1 to 10000);
      variable testSuccess: boolean;
   begin
      wait for 12 ns; -- wait for reset 
      wait for 60 ns; -- wait for pipeline to flush HCN
      readline(inputsFile, input); -- skip the first line of advertising
      while not endfile(inputsFile) loop
         readline(inputsFile, input); -- input comment, unused
         readline(inputsFile, input); -- input line, unused
         readline(inputsFile, expectedOutput); -- comment line, unused in this process
         readline(inputsFile, expectedOutput);
         expectedOutputString := expectedOutput.all & (expectedOutput'Length+1 to 10000 => ' ');
         testSuccess := testLine(testCounter, expectedOutputString, expectedOutput'Length, R);
         if not testSuccess then 
               errorCounter := errorCounter + 1; -- incrementing global error counter
         end if;
            testCounter := testCounter + 1; -- incrementing global error counter
         wait for 10 ns;
      end loop;
      report integer'image(errorCounter) & " error(s) encoutered." severity note;
      report "End of simulation after " & integer'image(testCounter-1) & " tests" severity failure;
   end process;

end architecture;

