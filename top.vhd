library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity top is
    Port (
        clk: in std_logic;
        reset : in std_logic;
        o_trig : out std_logic;
        uartTX: out std_logic
          );
end top;

architecture behave of top is
-------------------------------------------
component o_data_gen
Port(
    clk: in std_logic;
    reset : in std_logic;
    o_trig: out std_logic;
    o_data: out std_logic_vector(7 downto 0)
);
end component;
--------------------------------------------
component UART_TX_CTRL
Port(
	SEND : in std_logic;
	DATA : in std_logic_vector(7 downto 0);
	CLK : in std_logic;          
	READY : out std_logic;
	UART_TX : out std_logic
	);
end component;
--------------------------------------------
component clk_wiz_0
port
 (-- Clock in ports
  -- Clock out ports
  clk_out1          : out    std_logic;
  -- Status and control signals
  reset             : in     std_logic;
  clk_in1           : in     std_logic
 );
 end component;
--------------------------------------------
-- signal for o_data_gen
signal o_data: std_logic_vector(7 downto 0);
-- signal for clk_wiz_0
signal clk100: std_logic;
-- signal for uart_tx_ctrl

--The type definition for the UART state machine type. Here is a description of what
--occurs during each state:
-- RST_REG     -- Do Nothing. This state is entered after configuration or a user reset.
--                The state is set to LD_INIT.
-- LD_INIT     -- A vector of 0's is loaded into the sendStd variable and the stdIndex
--                variable is set to zero. The length of the 0's vector is stored in the stdEnd
--                variable. The state is set to SEND.
-- SEND        -- uartSend is set high for a single clock cycle, signaling the bit data at 
--				  sendStd(stdIndex) to be registered by the UART_TX_CTRL at the next
--                cycle. Also, stdIndex is incremented (behaves as if it were post 
--                incremented after reading the sendStd data). The state is set to RDY_LOW.
-- RDY_LOW     -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go low, 
--                indicating a send operation has begun. State is set to WAIT_RDY.
-- WAIT_RDY    -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go high, 
--                indicating a send operation has finished. If READY is high and stdEnd = 
--                stdIndex then state is set to WAIT_OUT, else if READY is high and stdEnd /=
--                StdIndex then state is set to SEND.
-- WAIT_OUT    -- Do nothing. Wait for out_enable. If out_enable = '1', set the state to LD.
-- LD_VECTOR   -- The std vector is loaded into the sendStd variable and the stdIndex
--                variable is set to zero. The vector length is stored in the stdEnd
--                variable. The state is set to SEND.
type UART_STATE_TYPE is (RST_REG, LD_INIT, SEND, RDY_LOW, WAIT_RDY, WAIT_OUT, LD_VECTOR);


constant RESET_CNTR_MAX : std_logic_vector(17 downto 0) := "110000110101000000";-- 100,000,000 * 0.002 = 200,000 = clk cycles per 2 ms
constant MAX_LEN : integer := 8;

--Contains the current bits vector being sent over uart.
signal sendStd : std_logic_vector(0 to (MAX_LEN - 1));

--Contains the length of the current bits vector being sent over uart.
signal stdEnd : natural;

--Contains the index of the next bit to be sent over uart
--within the sendStd variable.
signal stdIndex : natural;

--Used to determine when out is enabled
signal out_enable: std_logic;

--UART_TX_CTRL control signals
signal uartRdy : std_logic;
signal uartSend : std_logic := '0';
signal uartData : std_logic_vector (7 downto 0):= "00000000";   --??
signal UART_TX : std_logic;

--Current uart state signal
signal uartState : UART_STATE_TYPE := RST_REG;

signal clk_cntr_reg : std_logic_vector (4 downto 0) := (others=>'0'); 

--this counter counts the amount of time paused in the UART reset state
signal reset_cntr : std_logic_vector (17 downto 0) := (others=>'0');

begin
---------------------------------------------
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
---------------------------------------------
-- 2) CREATE A 8-BIT DATA VECTOR TO BE DISPLAYED
---------------------------------------------
Inst_o_data_gen : o_data_gen
   port map ( 
  -- Clock out ports  
   clk => clk100,
  -- Status and control signals                
   reset => reset,
   o_trig => out_enable,
   o_data => o_data
 );
 
 o_trig <= out_enable;
---------------------------------------------
-- 3) UART CONTROL
---------------------------------------------

process(clk100)
begin
  if (rising_edge(clk100)) then
    if ((reset_cntr = RESET_CNTR_MAX) or (uartState /= RST_REG)) then
      reset_cntr <= (others=>'0');
    else
      reset_cntr <= reset_cntr + 1;
    end if;
  end if;
end process;

--Next Uart state logic (states described above)
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
				if (uartRdy = '1') then
					if (stdEnd = stdIndex) then
						uartState <= WAIT_OUT;
					else
						uartState <= SEND;
					end if;
				end if;
			when WAIT_OUT =>
				if (out_enable = '1') then
					uartState <= LD_VECTOR;
				end if;
			when LD_VECTOR =>
				uartState <= SEND;
			when others=> --should never be reached
				uartState <= RST_REG;
			end case;
		
	end if;
end process;

--Loads the sendStd and stdEnd signals when a LD state is
--is reached.
vector_load_process : process (clk100)
begin
	if (rising_edge(clk100)) then
		if (uartState = LD_INIT) then
			sendStd <= "00000000";
			stdEnd <= MAX_LEN;
		elsif (uartState = LD_VECTOR) then
			sendStd <= o_data;
			stdEnd <= MAX_LEN;
		end if;
	end if;
end process;

--Conrols the stdIndex signal so that it contains the index
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

--Controls the UART_TX_CTRL signals
bit_load_process : process (clk100)
begin
	if (rising_edge(clk100)) then
		if (uartState = SEND) then
			uartSend <= '1';
			uartData(stdIndex) <= sendStd(stdIndex);
		else
			uartSend <= '0';
		end if;
	end if;
end process;

--Component used to send a byte of data over a UART line.
Inst_UART_TX_CTRL: UART_TX_CTRL port map(
		SEND => uartSend,
		DATA => uartData,
		CLK => clk100,
		READY => uartRdy,
		UART_TX => UART_TX 
	);

uartTX <= UART_TX;






end behave;
