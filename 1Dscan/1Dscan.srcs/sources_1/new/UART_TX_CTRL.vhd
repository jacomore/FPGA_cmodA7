----------------------------------------------------------------------------
--	UART_TX_CTRL.vhd -- UART Data Transfer Component
----------------------------------------------------------------------------
-- Author:  Sam Bobrowicz
--          Copyright 2011 Digilent, Inc.
-- EDITED BY GIACOMO RIZZI on the 28th of January, 2023. 
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--	This component may be used to transfer data over a UART device. It will
-- serialize a byte of data and transmit it over a TXD line. The serialized
-- data has the following characteristics:
--         *921600 Baud Rate
--         *8 data bits, LSB first
--         *1 stop bit
--         *no parity
--         				
-- Port Descriptions:
--
--    SEND - Used to trigger a send operation. The upper layer logic should 
--           set this signal high for a single clock cycle to trigger a 
--           send. When this signal is set high DATA must be valid . Should 
--           not be asserted unless READY is high.
--    DATA - The parallel data to be sent. Must be valid the clock cycle
--           that SEND has gone high.
--    CLK  - A 100 MHz clock is expected
--   READY - This signal goes low once a send operation has begun and
--           remains low until it has completed and the module is ready to
--           send another byte.
-- UART_TX - This signal should be routed to the appropriate TX pin of the 
--           external UART device.
--   
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Revision History:
--  Giacomo Rizzi, 28/01/23 : edited using Vivado 2022.2.
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity UART_TX_CTRL is
    Port ( SEND : in  STD_LOGIC;
           DATA : in  STD_LOGIC_VECTOR (11 downto 0);
           CLK : in  STD_LOGIC;
           BITDONE: out STD_LOGIC;
           READY : out  STD_LOGIC;
           UART_TX : out  STD_LOGIC);
end UART_TX_CTRL;

architecture Behavioral of UART_TX_CTRL is
--------------------------------------------
-- DECLARATIONS
--------------------------------------------
type TX_STATE_TYPE is (RDY, LOAD_BIT, SEND_BIT);


    -- CONSTANTS
constant BIT_TMR_MAX : std_logic_vector(6 downto 0) := "1101011"; --107 = (round(100MHz / 921600)) - 1
constant BIT_INDEX_MAX : natural := 14;

    -- COUNTER AND TRASMISSION LOGIC 
--Counter that keeps track of the number of clock cycles the current bit has been held stable over the
--UART TX line. It is used to signal when the new bit must be erogated
signal bitTmr : std_logic_vector(6 downto 0) := (others => '0');
--combinatorial logic that goes high when bitTmr has counted to the proper value to ensure
--a 9600 baud rate
signal bitEnd : std_logic;
--Contains the index of the next bit in txData that needs to be transferred 
signal bitIndex : natural;
--a register that holds the current data being sent over the UART TX line
signal txBit : std_logic := '1';

    -- DATA TO BE TRASMITTED
--A register that contains the whole data packet to be sent, including start and stop bits. 
signal txData : std_logic_vector(BIT_INDEX_MAX - 1 downto 0);
signal txState : TX_STATE_TYPE := RDY;

begin
---------------------------------------------
-- PROCESSES
---------------------------------------------

-- evaluate the logic of the next state, depending on the current status
-- of txState
next_txState_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		case txState is 
		    when RDY =>
			    if (SEND = '1') then
				    txState <= LOAD_BIT;
			    end if;
		    when LOAD_BIT =>
			    txState <= SEND_BIT;
		    when SEND_BIT =>
			    if (bitEnd = '1') then
				    if (bitIndex = BIT_INDEX_MAX) then
					    txState <= RDY;
				    else
					    txState <= LOAD_BIT;
				    end if;
			    end if;
		    when others=> --should never be reached
			    txState <= RDY;
		end case;
	end if;
end process;

-- counter (bitTmr) that keeps track of the number of clock cycles for the 
-- trasmission of each bit. Assuming txState is different from RDY, 
-- bitTmr is increases by 1 for every clock cycles, until bitEnd is reached.   
bit_timing_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (txState = RDY) then
			bitTmr <= (others => '0');
		else
			if (bitEnd = '1') then
				bitTmr <= (others => '0');
			else
				bitTmr <= bitTmr + 1;
			end if;
		end if;
	end if;
end process;

-- bitEnd goes high whenever BIT_TRM_MAX is reached by bitTmr 
bitEnd <= '1' when (bitTmr = BIT_TMR_MAX) else
				'0';

-- count the number of bit that are sent over the UART line. 
-- the counter (bitIndex) is set back to 0 whenever RDY is reached.
bit_counting_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (txState = RDY) then
			bitIndex <= 0;
		elsif (txState = LOAD_BIT) then
			bitIndex <= bitIndex + 1;
		end if;
	end if;
end process;

-- Merges the data DATA with the ending bit (1) and the
-- starting bit (0 (note that the txData will be sent from
-- the least to the most significant bit.
tx_data_latch_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (SEND = '1') then
			txData <= '1' & DATA & '0';
		end if;
	end if;
end process;

-- return the bit to be sent over the line depending 
-- on the value of txState.
tx_bit_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (txState = RDY) then
			txBit <= '1';
		elsif (txState = LOAD_BIT) then
			txBit <= txData(bitIndex);
		end if;
	end if;
end process;

BITDONE <= bitEnd;
UART_TX <= txBit;
READY <= '1' when (txState = RDY) else
			'0';

end Behavioral;