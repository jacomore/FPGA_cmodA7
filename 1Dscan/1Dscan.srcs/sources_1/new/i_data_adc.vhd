library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity i_data_adc is
    Port( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        i_data : out STD_LOGIC_VECTOR (11 downto 0);
        anal_p: in std_logic; 
        anal_n: in std_logic
        );
end i_data_adc; 

architecture Behavioral of i_data_adc is

COMPONENT xadc_wiz_0
  PORT (
    di_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    daddr_in : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    den_in : IN STD_LOGIC;
    dwe_in : IN STD_LOGIC;
    drdy_out : OUT STD_LOGIC;
    do_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    dclk_in : IN STD_LOGIC;
    reset_in : IN STD_LOGIC;
    vp_in : IN STD_LOGIC;
    vn_in : IN STD_LOGIC;
    vauxp4 : IN STD_LOGIC;
    vauxn4 : IN STD_LOGIC;
    channel_out : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    eoc_out : OUT STD_LOGIC;
    alarm_out : OUT STD_LOGIC;
    eos_out : OUT STD_LOGIC;
    busy_out : OUT STD_LOGIC 
  );
END COMPONENT;

signal channel_out : std_logic_vector(4 downto 0);
signal daddr_in  : std_logic_vector(6 downto 0);
signal eoc_out : std_logic;
signal do_out  : std_logic_vector(15 downto 0);  
signal clk_out: std_logic;
signal ila_out: std_logic_vector(11 downto 0);

begin

i_data <= do_out(15 downto 4);

inst_xadc : xadc_wiz_0 
port map
(
  daddr_in        => "0010100",
  den_in          => eoc_out,
  di_in           => "0000000000000000",
  dwe_in          => '0',
  do_out          => do_out,
  drdy_out        => open,
  dclk_in         => clk,
  reset_in        => reset,
  busy_out        => open,
  channel_out     => channel_out,
  eoc_out         => eoc_out,
  eos_out         => open,
  alarm_out       => open,
  vp_in           => '0',
  vn_in           => '0',
  vauxp4 => anal_p,
  vauxn4 => anal_n);

end Behavioral;
