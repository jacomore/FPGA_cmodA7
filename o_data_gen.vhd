library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity o_data_gen is
    Port (
        clk: in std_logic;
        reset : in std_logic;
        o_trig: out std_logic;
        o_data: out std_logic_vector(7 downto 0)
         );
end o_data_gen;

architecture Behavioral of o_data_gen is

-- CONSTANTS
constant n_periods: integer := 100000000;

-- TRIGGER GENERATION
signal n_clk_cycles: integer range 0 to n_periods := 0;
signal trig: std_logic; 
signal old_trig: std_logic;

begin

counter: process (clk, reset)
    begin 
    if rising_edge(clk) then 
        if (reset = '1') then 
            n_clk_cycles <= 0;
        elsif (n_clk_cycles = n_periods) then
            n_clk_cycles <= 1;
        else
            n_clk_cycles <= n_clk_cycles + 1;
        end if; 
    end if;
end process counter;

old_trig <= trig;
trig_gen: process(clk,n_clk_cycles)
    begin 
    if rising_edge(clk) then
        if (reset = '1') then 
            trig <= '0';
        elsif (n_clk_cycles = n_periods) then 
            trig <= not old_trig; 
        end if;
    end if; 
end process trig_gen;
o_trig <= trig; 

o_data_assign: process(trig)
begin 
    if (trig = '1') then
        o_data <= "10101010";
    else 
        o_data <= "01001000";
    end if; 
end process o_data_assign;

end Behavioral;
