--------------------------------------------------------------------
-- author: Giacomo Rizzi
-- date: 28/01/23
-- project name: 1D scan
-- top module name: top
-- module name: input_data_gen
-- module description: this module simulates the flow of digital data from an external device
--                     to the FPGA Artix 7 35-T. "i_data" is therefore a std_logic_vector of dimension
--                     nbit and whose value ranges from 1 up to 7. 

-- I/Os description: 
--                     - nbit: number of bits for the i_data.       
--                     - clk: input clock of for the processes.  
--                     - reset: if reset goes high, i_data are set to vector of zeros. 
--                     - i_data: bits vector containing the data to be provided
--------------------------------------------------------------------  

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

ENTITY input_data_gen IS
    GENERIC (
    nbit : integer := 12
    );
    PORT (
        clk: in std_logic;
        reset : in std_logic;
        i_data: out std_logic_vector(11 downto 0)
         );
END input_data_gen;

ARCHITECTURE Behavioral OF input_data_gen IS
--------------------------------------------
-- DECLARATIONS
--------------------------------------------
    -- CONSTANT 
constant data_cycles: integer := 100000; -- 1 MHz          -- simulate the output frequency of an external device; 
                                                        -- the output frequency is given by: clk_freq / data_cycles
                   
    -- COUNTER
signal cnt_cycles: integer range 0 to data_cycles := 0; -- counts the number of clock cycles from 1 up to data_cycles   
                                                        -- to ensure that the data generation process is erogated with 
                                                        -- the desired output frequency.

-- DATA GENERATION
signal old_data: unsigned(nbit-1 downto 0);             -- previous input data is herein uploaded
signal curr_data: unsigned(nbit-1 downto 0);            -- curr data value is herein uploaded. curr_data = old_data + 1

begin 
---------------------------------------------
-- PROCESSES
---------------------------------------------


-- counter_data counts the number of clk cycles from up to data_cycles. 
-- When data_cycles is reached, cnt_cycles is set back to 1. 
counter_data: process (clk, reset)
    begin 
    if rising_edge(clk) then 
        if (reset = '1') then 
            cnt_cycles <= 0;
        elsif (cnt_cycles = data_cycles) then
            cnt_cycles <= 1;
        else
            cnt_cycles <= cnt_cycles + 1;
        end if; 
    end if;
end process counter_data;

-- old data has integer value from 0 up to 7. It is updated asinchrounously  
-- for every changes of curr_data with the previous value of curr_data.
old_data <= curr_data when (curr_data < to_unsigned(7,nbit)) 
                          else (others => '0');        

-- data_gen increases by 1 the value of curr_data every time that 
-- cnt_cycles is equal to data_cycles. This process simulates a flow of 
-- input data with a given frequency (different from the clock frequency)        
data_gen: process(clk)
    begin 
    if rising_edge(clk) then
        if (reset = '1') then 
           curr_data <= (others => '0');
        elsif (cnt_cycles = data_cycles) then 
            curr_data <= old_data + to_unsigned(1,nbit); 
        end if;
    end if; 
end process data_gen;
i_data <= std_logic_vector(curr_data);

end Behavioral;