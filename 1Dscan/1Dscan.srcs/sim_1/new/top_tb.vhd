----------------------------------------------------------------------------------
-- Author: Giacomo Rizzi 
-- 
-- Create Date: 24.01.2023 16:13:56
-- Design Name: top
-- Module Name: top
-- Project Name: 1D scan
-- module description: simulation of the top module of 1D scan. 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_tb is
end top_tb;

architecture Behavioral of top_tb is
component top
    Port (
        clk: in std_logic;
        reset : in std_logic;
		trig: in std_logic;
        led : out std_logic;
        uartTX: out std_logic
          );
end component;

signal clk: std_logic := '0';
signal reset: std_logic;
signal trig: std_logic := '0';
signal led: std_logic; 
signal uartTX : std_logic;

begin
Inst_top: top port map (
                        clk => clk, 
                        reset => reset,
                        trig => trig,
                        led => led,
                        uartTX => uartTX);

clk <= not clk after 41.67 ns; -- 12 MHz
trig <= not trig after 100 us; 

-- Stimulus process
stim_proc: process
begin        
   -- hold reset state for 100 ns.
     reset <= '1';
   wait for 100 ns;    
    reset <= '0';
   wait;
end process;

end Behavioral;