library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ieee754_add_wrapper is
  PORT (
    clk : in std_logic;
    X : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    Y : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    R : OUT STD_LOGIC_VECTOR(31 DOWNTO 0) 
  );

end ieee754_add_wrapper;

architecture Behavioral of ieee754_add_wrapper is
COMPONENT ieee754_add
  PORT (
    clk : IN STD_LOGIC;
    rst : IN STD_LOGIC;
    start : IN STD_LOGIC;
    op_a : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    op_b : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    done : OUT STD_LOGIC;
    res : OUT STD_LOGIC_VECTOR(31 DOWNTO 0) 
  );
END COMPONENT;
signal regX, regY, regR : STD_LOGIC_VECTOR(31 DOWNTO 0);
begin
fpa0 : ieee754_add
  PORT MAP (
    clk => clk,
    rst => '0',
    start => '1',
    op_a => regX,
    op_b => regY,
    done => open,
    res => regR
  );
process (clk)
begin
   if clk'event and clk='1' then
    regX <= X;
    regY <= Y;
--    R <= regR;
   end if;
end process;
R <= regR;
end Behavioral;
