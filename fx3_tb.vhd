-- Testbench for fx3
-- @author Shaun

-- Load Altera libraries for this device
Library ieee;
Library cycloneive;
use ieee.std_logic_1164.all;
use cycloneive.cycloneive_components.all;

-- Setup this testbench as an entity
entity fx3_tb is
end fx3_tb;

-- create an implementation of this entity
architecture testbench1 of fx3_tb is
  
  -- Setup the signals on the fx3 block
  signal  rst_n_in  : std_logic;   -- Sync Reset
  signal  clk_in    : std_logic;   -- Input Clock (50 MHz)
  signal  LED     : std_logic_vector(7 downto 0);
  signal  switches  : std_logic_vector(1 downto 0);

  -- FX3
  signal  fx3_pclk_out  :  std_logic;  -- FX3 Clock (100 MHz)

  signal  fx3_slcs_n_out  :  std_logic;  -- Chip Select (Active Low)
  signal  fx3_slrd_n_out  :  std_logic;  -- Read (Active Low)
  signal  fx3_slwr_n_out  :  std_logic;  -- Write (Active Low)
  signal  fx3_sloe_n_out  :  std_logic;  -- Output Enable (Active Low)

  signal  fx3_fifo_address_out  :  std_logic_vector(1 downto 0); -- FIFO Address Select

  signal  fx3_flaga_in  :  std_logic;   -- FIFO Address 0 Empty=0
  signal  fx3_flagb_in  :  std_logic;   -- FIFO Address 1 Empty=0

  signal  fx3_pktend_n_out  :  std_logic;  -- End of Packet or Zero Length Packet Signal (Active Low)

  signal  fx3_fdata_inout :  std_logic_vector(31 downto 0);  -- The bidirectional data bus

  signal  fx3_pmode_out :  std_logic_vector(1 downto 0); -- Bootmode Selector
  signal  fx3_reset_out :  std_logic;         -- FX3 Reset

  -- Test signals
  
  -- Setup the vcc signal as 1
  signal vcc : std_logic := '1';
  
begin
  -- the device unter test is the top level file
  dut: entity work.fx3
  port map (
    rst_n_in => rst_n_in,
    clk_in => clk_in,
    LED => LED,
    switches => switches,
    fx3_pclk_out => fx3_pclk_out,
    fx3_slcs_n_out => fx3_slcs_n_out,
    fx3_slrd_n_out => fx3_slrd_n_out,
    fx3_slwr_n_out => fx3_slwr_n_out,
    fx3_sloe_n_out => fx3_sloe_n_out,
    fx3_fifo_address_out => fx3_fifo_address_out,
    fx3_flaga_in => fx3_flaga_in,
    fx3_flagb_in => fx3_flagb_in,
    fx3_pktend_n_out => fx3_pktend_n_out,
    fx3_fdata_inout => fx3_fdata_inout,
    fx3_pmode_out => fx3_pmode_out,
    fx3_reset_out => fx3_reset_out
    );
  
  -- Setup the 50 MHz clock
  clock : process is begin
    loop
      clk_in <= '0'; wait for 10 ns;
      clk_in <= '1'; wait for 10 ns;
    end loop;
  end process clock;
  
  -- Setup the signals
  stimulus : process is begin
    -- set up the clock
    fx3_flaga_in <= '1';  -- Address 0 Empty
    fx3_flagb_in <= '1';  -- Address 1 Empty
    fx3_fdata_inout <= (Others => 'Z');

    wait for 10 ns;
    rst_n_in <= '0';
    wait for 30 ns;
    rst_n_in <= '1';
    wait for 20 ns;
    fx3_flaga_in <= '0';
    wait for 20 ns;
    fx3_flaga_in <= '0';
    wait for 200 ns;
    fx3_flaga_in <= '1';
    
  end process stimulus;
end architecture testbench1;