----------------------------------------------------------------------------------
-- Author: Giacomo Rizzi 
-- 
-- Create Date: 24.01.2023 16:13:56
-- Design Name: top
-- Module Name: top
-- Project Name: 1D scan
-- module description: this top module uses the modules: "averager" and "UART_TX_CTRL". 
--                     note that in turn averager uses "input_gen_data" module.
--                     This design has the following aim: given a flow of data (obtained in input 
--                     through the input_data_gen module), the average over a trigger cycle (trig variable)
--                     must be performed. In this way this design can be interfaced with PI microcontrollers,
--                     (albait tested only with C663.12) to acquire data when the moving stage is in stationary
--                     conditions. Data are then averaged and returned through the module "averager". Eventually,
--                     "UART_TX_CTRL" module allows for data transfer through the on UART_USB bridge.
                       
-- I/Os description: 
--                     - clk: input clock of for the processes.  
--                     - reset: if reset goes high, i_data are set to vector of zeros. 
--                     - trig: trig is erogated by PI Controller C663.12 when the axis is in motion.
--                     - led: goes high (light is shining) when the axis is stable (i.e, acquisition is possibile
--                     - uartTX: bits that are sent over the UART to USB line for serial communication protocol
----------------------------------------------------------------------------------
library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.std_logic_unsigned.all;
USE IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        clk: in std_logic;
        reset : in std_logic;
    
        trig: in std_logic;
        anal_p: in std_logic; 
        anal_n: in std_logic;
    
        led : out std_logic;
        uartTX: out std_logic
          );
end top;

architecture behave of top is
--------------------------------------------
-- DECLARATIONS
--------------------------------------------

-- clocking wizard
-------------------------------------------
component clk_wiz_0
    Port ( clk_out1 : out    std_logic;
           reset : in     std_logic;
           clk_in1 : in     std_logic
          );
end component;
-------------------------------------------

-- ILA: integrated logical analyzer
-------------------------------------------
component ila_0
port (
	clk : in std_logic;
	probe0 : in std_logic_vector(0 downto 0); 
	probe1 : in std_logic_vector(0 downto 0); 
	probe2 : in std_logic_vector(11 downto 0); 
	probe3 : in std_logic_vector(0 downto 0);
	probe4: in std_logic_vector(11 downto 0)
);
end component;
-------------------------------------------

-- averager module: average input data
--------------------------------------------
component averager
    Generic (
        nbit: integer := 12;       -- number of bits for input and output data 
        pow : integer := 5         -- average is calculate for 2^pow samples
        );
    Port (
        clk: in std_logic;         -- 100 MHz clock
        reset: in std_logic;       -- button 
		trig: in std_logic;        -- trigger signal obtained from the PI controller
        anal_p: in std_logic; 
		anal_n: in std_logic; 
        o_enable: out std_logic;
        i_data_out: out std_logic_vector(11 downto 0);
        o_data: out std_logic_vector(nbit-1 downto 0) 
        );
end component;
--------------------------------------------

-- UART to USB serial data transfer protocol
--------------------------------------------
component UART_TX_CTRL
Port(
	SEND : in std_logic;
	DATA : in std_logic_vector(11 downto 0);
	CLK : in std_logic;
	BITDONE: out STD_LOGIC;
	READY : out std_logic;
	UART_TX : out std_logic
	);
end component;


    -- WIRES BETWEEN MODULES
signal o_enable: std_logic;        -- returned by averaged, is high when trig is low. 
signal o_data: std_logic_vector(11 downto 0);   -- returned by averager, contains the averaged data
signal clk100: std_logic;  -- clk signal from clocking wizard (at 100 MHz)

    -- LOGIC FOR THE UART TO USB TRASMISSIONS
type UART_STATE_TYPE is (RST_REG, LD_INIT, SEND, RDY_LOW, WAIT_RDY,WAIT_DIFF, WAIT_OUT, LD_VECTOR);
constant RESET_CNTR_MAX : integer := 100 ;-- 100,000,000 * 0.000001 = 100 = clk cycles per 1 us
constant MAX_LEN : integer := 12; -- this constant MUST be equal to "nbit" and represents the dimensions of transferred data
signal sendStd : std_logic_vector((MAX_LEN - 1) downto 0); -- contains the bits vector to be sent over the line
signal stdEnd : natural := MAX_LEN+2; --Contains the index of last bit being sent over uart.
signal stdIndex : natural; --Contains the index of the next bit to be sent over uart within the sendStd variable.
signal uartRdy : std_logic; --Used to determine when out is enabled
signal uartSend : std_logic := '0'; --is high if the bit has to be sent, else is low
signal uartData : std_logic_vector (11 downto 0):= (others => '0');   --contains the bits vector to be sent over the line
signal UART_TX : std_logic; --actual bit to be sent out
signal bitEnd: std_logic;  --takes as input the value of bitStop
signal uartState : UART_STATE_TYPE := RST_REG; -- STATE OF THE "FINITE STATE MACHINE" UART_TO_USB
signal reset_cntr : integer range 0 to RESET_CNTR_MAX := 0; --this counter counts the amount of time paused in the UART reset state

signal i_data_out: std_logic_vector(11 downto 0);
begin
-------------------------------------------
-- 1) GENERATE A 100 MHz CLOCK
---------------------------------------------
Inst_clock : clk_wiz_0
   port map ( 
  -- Clock out ports  
   clk_out1 => clk100,
  -- Status and control signals                
   reset => reset,
   -- Clock in ports
   clk_in1 => clk
 );
 -------------------------------------------
-- 2) GENERATE THE ILA FOR DEBUGGING
---------------------------------------------
Inst_ila_0: ila_0
    port map (
    	clk => clk100,
	probe0(0) => reset, 
	probe1(0) => o_enable, 
	probe2 => o_data,
	probe3(0) => UART_TX,
	probe4 => i_data_out
	);
 ----------------------------------------------
-- 2) 8-BIT VECTOR WITH THE AVERAGE VALUE OF THE ACQUIRED DATA
-------------------------------------------
Inst_averager : averager
   port map ( 
  -- Clock out ports  
   clk => clk100,
  -- Status and control signals                
   reset => reset,
   trig => trig,
   anal_p => anal_p,
   anal_n => anal_n,
   o_enable => o_enable,
   i_data_out => i_data_out,
   o_data => o_data
 );
led <= o_enable;

-----------------------------------------------
-- 3) UART to USB control out
-----------------------------------------------
process(clk100)
begin
  if (rising_edge(clk100)) then
    if ((reset_cntr = RESET_CNTR_MAX) or (uartState /= RST_REG)) then
      reset_cntr <= 0;
    else
      reset_cntr <= reset_cntr + 1;
    end if;
  end if;
end process;
-----------------------------------------------

---------------------------------------------
-- PROCESSES
---------------------------------------------

--Next Uart state logic (states described above)
-- evaluate the logic of the next state, depending on the current status
-- of txState
next_uartState_process : process (clk100)
begin
	if (rising_edge(clk100)) then
        case uartState is 
			when RST_REG =>
                if (reset_cntr = RESET_CNTR_MAX) then
                uartState <= LD_INIT;
                end if;
			when LD_INIT =>
				uartState <= SEND;
			when SEND =>
				uartState <= RDY_LOW;
			when RDY_LOW =>
				uartState <= WAIT_RDY;
			when WAIT_RDY =>
				if (bitEnd = '1') then
					if (stdEnd = stdIndex) then
						uartState <= WAIT_OUT;
					else
						uartState <= SEND;
					end if;
				end if;
			when WAIT_OUT =>
			     uartState <= LD_VECTOR;
	       	when LD_VECTOR =>
				 uartState <= SEND;
			when others=> --should never be reached
				 uartState <= RST_REG;
			end case;
		end if; 
end process;

--Load o_data in the sendStd signal whenever LD_VECTOR uartState is reached. 
-- else, if LD_INIT is reached (following RST_REG), sendStd is set to 0.
vector_load_process : process (clk100)
begin
	if (rising_edge(clk100)) then
		if (uartState = LD_INIT) then
			sendStd <= (others => '0');
		elsif (uartState = LD_VECTOR) then
			sendStd <= o_data;
		end if;
	end if;
end process;

--Controls the stdIndex signal so that it contains the index
--of the next bit that needs to be sent over uart
bit_count_process : process (clk100)
begin
	if (rising_edge(clk100)) then
		if (uartState = LD_INIT or uartState = LD_VECTOR) then
			stdIndex <= 0;
		elsif (uartState = SEND) then
			stdIndex <= stdIndex + 1;
		end if;
	end if;
end process;

--Controls the UART_TX_CTRL signals by setting the uartSend variable 
-- either high (SEND state is reached) or low (else) and uploading sendStd in uartData.
bit_load_process : process (clk100)
begin
	if (rising_edge(clk100)) then
		if (uartState = SEND) then
		    uartSend <= '1';
            uartData <= sendStd;
		else
			uartSend <= '0';
	    end if;
	end if;
end process;

Inst_UART_TX_CTRL: UART_TX_CTRL port map(
		SEND => uartSend,
		DATA => uartData,
		CLK => clk100,
		BITDONE => bitEnd,
		READY => uartRdy,
		UART_TX => UART_TX 
	);
	
uartTX <= UART_TX when (reset = '0') else
        				'0';

end behave;