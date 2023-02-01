--------------------------------------------------------------------
-- author: Giacomo Rizzi
-- date: 28/01/23
-- project name: 1D scan
-- top module name: top
-- module name: averager
-- module description: this module processes the data obtained by an external module 
--                     (input_data_gen), which are called "i_data". Data are acquired when "trig" variable is 'low'
--                     for a total of 2^pow samples. 'trig' is supposed to be provided by the PI controller 663.13, i.e, 
--                     the time spent in the 'low' position is always greater than 100 ms;
--                     Eventually, output data are given as output as the average of the sampled i_data within within a 'trig' cycles.
--                     it is required that  

-- I/Os description: 
--                     - nbit: number of bits for the i_data.   
--                     - pow: defines the number of sampling points (2^pow) for the input data    
--                     - clk: input clock of for the processes.  
--                     - reset: if reset goes high, i_data are set to vector of zeros. 
--                     - trig: trig is erogated by PI Controller C663.12 for each movme
--                     - o_enable: goes high when trig is low. o_enable is obtained by a flip-flop to avoid metastable issues. 
--                     - o_data: average data is returned every time the 32th sampling has been performed. 
--------------------------------------------------------------------  
library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY averager is
    GENERIC (
        nbit: integer :=12;         
        pow : integer := 5         
        );
    PORT (
        clk: in std_logic;         
        reset: in std_logic;        
		trig: in std_logic;       
		anal_p: in std_logic; 
		anal_n: in std_logic; 
		o_enable: out std_logic;
		i_data_out : out std_logic_vector(11 downto 0);
        o_data: out std_logic_vector(nbit-1 downto 0) 
        );
END averager;

architecture Behavioral of averager is
--------------------------------------------
-- DECLARATIONS
--------------------------------------------
--COMPONENT input_data_gen
--   GENERIC (
--        nbit: integer := 12      
--    );
--    PORT ( 
--	clk: in std_logic; 
--	reset: in std_logic;
--    i_data : out std_logic_vector(nbit - 1 downto 0)
--    );
--END COMPONENT;

COMPONENT i_data_adc
    PORT (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        i_data : out STD_LOGIC_VECTOR (11 downto 0);
        anal_p: in std_logic; 
        anal_n: in std_logic
        );
END COMPONENT; 

    -- CONSTANTS
constant data_cycles: integer := 10000; -- 1 kHz          -- ratio of the clock frequency and the output frequency of 
                                                        -- of the external device (the frequency of update of i_data).
constant n_samples: integer := 32;                      -- 2^pow; it is written in this way to save resources. 

    -- MOTION SIGNALS
signal stable: std_logic;                               -- trig signal is erogated by PI controller when the axis is in motion, i.e, 
                                                        -- stable is the inverse of trig signal and is high when the axis is stationary.
signal notrig1: std_logic;                              -- intermediate flip-flop to avoid metastable issues 
signal notrig2: std_logic;                              -- intermediate flip-flop to avoid metastable issues

    -- INPUT SIGNALS
signal i_datavec: std_logic_vector(nbit-1 downto 0);    -- std_logic_vector that reads the data from the instance of Input_data_gen
signal i_datauns: unsigned(nbit-1 downto 0);            -- unsigned vector to which std_logic_vector writes

    -- UNLOADING SIGNALS 
signal sload: std_logic;                                -- sload goes high when the accumulator (which accumulates input data for the average)
                                                        -- must be emptied
signal cnt_clk: integer range 0 to 65535 := 0;               -- counter for the number of clock cycles
signal cnt_smpl: integer range 0 to 32 := 0;                 -- counter for the number of samplings

    -- ADDER SIGNALS
signal add: std_logic;                                  -- add goes high when i_data must be sampled
signal old_acc: unsigned(nbit-1 downto 0);              -- previous value of the accumulator
signal acc: unsigned(nbit-1 downto 0);                  -- accumulator: stored the sum of all the previous i_data;
-- AVERAGE DATA
signal average: unsigned(nbit-1 downto 0);              -- average of the 32 sampled i_data (rightward shift)

begin
-----------------------------------------------------
-- COMPONENT INSTANTIATION
-----------------------------------------------------

-----------------------------------------------------
---- INPUT DATA: using either built-in data or ADC input
--Inst_input_data_gen: input_data_gen port map (clk => clk,
--										      reset => reset,
--										      i_data => i_datavec);

Inst_i_data_adc: i_data_adc port map ( clk => clk, 
                                               reset => reset, 
                                               i_data => i_datavec, 
                                               anal_p => anal_p,
                                               anal_n => anal_n);
										      
-- conversion of the i_data into an unsigned std_uvector
i_datauns <= unsigned(i_datavec);										      
i_data_out <= i_datavec;
-- 1 bit shift register for storing the inverted value of trig 
-- avoiding metastable issues
notrig1 <= not trig;
is_stable: process(clk,reset)
    begin
    -- synchronous design
    if rising_edge(clk) then
        if (reset = '1') then
            stable <= '0';
        else
            notrig2 <= notrig1;
            stable <= notrig2;
        end if;
    end if; 
end process is_stable;
o_enable <= stable; 
-----------------------------------------------------
-- PROCESSES
-----------------------------------------------------
-- If the axis is stationary (i.e, stable is high), count 
-- the number of clock cycles until data data_cycles is reached.
-- Hence, the counter (cnt_clk) is set back to 1. 
count_clock : process (clk) is
begin
    if rising_edge(clk) then
		if (stable = '1') then 
            if (cnt_clk = data_cycles) then
                cnt_clk <= 1;
            else 
                cnt_clk <= cnt_clk + 1;
            end if;
        else
			cnt_clk <= 0;
        end if;
    end if;
end process count_clock;

-- count the number of samplings of the i_data. i_data are sampled accordingly with
-- the output frequency of the data; when data_cycles is reached, add goes high so that 
-- sampling occurs. 
count_sampling: process (clk)
begin
    if rising_edge(clk) then
       if (stable= '1') then
            if (cnt_clk = data_cycles) then
                cnt_smpl <= cnt_smpl + 1;
		        if (cnt_smpl < n_samples) then 
		             add <= '1';
		        end if;
		    else
		      add <= '0';
			end if;
		else
		  cnt_smpl <= 0;
		  add <= '0';
		end if; 
    end if;
end process count_sampling;

-- initialises the value of sload: if cnt is in between 1 and 32, then 
-- acc is loaded with old value, sload is low (acc is loaded). Else, is 
-- high (acc is unloaded). 
is_load: process (clk)
begin 
    if rising_edge(clk) then 
        case cnt_smpl is
            when 1 to 32 => sload <= '0';
            when others => sload <= '1';    
        end case;
     end if; 
end process is_load;

-- loads the old_acc signal with the previous value of accumulator. Note that
-- this is the only asynchronous process. Even though asynchrous design should 
-- be averted whenever possible, in this condition it is necessary to avoid 
-- a delay of 1 clock cycles between acc and old_acc, which would cause the failure
-- of a proper accumulation. 
load_old_acc: process (sload,acc)
begin
        if (sload = '1') then
--	    Clear the accumulated data
            old_acc <= (others => '0');
        else
            old_acc <= acc;
        end if;
end process load_old_acc;

-- loads the accumulator (acc) with its previous value (old_acc) and the newly sampled value
-- of i_data. Note that the process relies on the strong assumption that i_datauns,  
-- old_acc and acc share the SAME DIMENSIONS (NBIT) and TYPE (UNSIGNED) !
load_acc: process (clk,reset)
begin
    if rising_edge(clk) then
        if (reset = '1') then 
            acc <= (others => '0');
        elsif (add = '1') then
			acc <= old_acc + i_datauns; -- WARNING: assuming that the type and the format of i_data is the same of acc
		end if;
    end if;
end process load_acc;

-- returns the averaged value, i.e, acc divided by 2^pow (32). Note that output data
-- is uploaded only when cnt_smpl reaches 32, so that a single output is provided for each trig cycles. 
o_data <= std_logic_vector(average);
return_average: process (clk)
begin 
	if rising_edge(clk) then
	   if (reset = '1') then 
	       average <= (others => '0');
	   elsif (cnt_smpl = 32) then
	       average(nbit-1-pow downto 0) <= acc(nbit-1 downto pow);
           average(nbit-1 downto nbit-pow) <= (others => '0');
        end if;
    end if; 
end process return_average;

end Behavioral;
