-- Testbench for FX3-FPGA

-- Load Altera libraries for this device
Library ieee;
Library cycloneive;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use cycloneive.cycloneive_components.all;
library vunit_lib;
context vunit_lib.vunit_context;

-- Setup this testbench as an entity
entity fx3_tb is
  generic (runner_cfg : string);
end fx3_tb;

-- Create an implementation of this entity
architecture testbench1 of fx3_tb is

  constant FX3_WATERMARK : natural := 3;
  constant AWESOME_TEST_HEX : std_logic_vector(31 downto 0) := X"A0_C0FFEE";
  constant AWESOME_BULK_HEX : std_logic_vector(31 downto 0) := X"00_C0FFEE";

  -- Setup the signals on the fx3 block
  signal  rst_n_in  : std_logic;   -- Sync Reset
  signal  clk_in    : std_logic;   -- Input Clock (50 MHz)

  -- FX3
  signal  fx3_pclk_out  :  std_logic;  -- FX3 Clock (100 MHz)

  signal  fx3_slcs_n_out  :  std_logic;  -- Chip Select (Active Low)
  signal  fx3_slrd_n_out  :  std_logic;  -- Read (Active Low)
  signal  fx3_slwr_n_out  :  std_logic;  -- Write (Active Low)
  signal  fx3_sloe_n_out  :  std_logic;  -- Output Enable (Active Low)

  signal  fx3_fifo_address_out  :  std_logic_vector(1 downto 0); -- FIFO Address Select

  signal  fx3_flaga_in  :  std_logic;   -- Address 00 DMA Ready (Active Low)
  signal  fx3_flagb_in  :  std_logic;   -- Address 00 DMA Watermark (Active Low)
  signal  fx3_flagc_in  :  std_logic;   -- Address 11 DMA Ready (Active Low)
  signal  fx3_flagd_in  :  std_logic;   -- Address 11 DMA Watermark (Active Low)

  signal  fx3_pktend_n_out  :  std_logic;  -- End of Packet or Zero Length Packet Signal (Active Low)

  signal  fx3_fdata_inout :  std_logic_vector(31 downto 0);  -- The bidirectional data bus

  signal  fx3_pmode_out :  std_logic_vector(1 downto 0); -- Bootmode Selector
  signal  fx3_reset_out :  std_logic;         -- FX3 Reset

  -- RX FIFO
  signal rx_ready_in  : std_logic;
  signal rx_data_out  : std_logic_vector(31 downto 0);
  signal rx_valid_out : std_logic;

  -- TX FIFO
  signal tx_ready_out : std_logic;
  signal tx_data_in   : std_logic_vector(31 downto 0);
  signal tx_valid_in  : std_logic;

  -- Test signals
  signal rx_fifo_data_count_out : std_logic_vector(8 downto 0);
  signal tx_fifo_data_count_out : std_logic_vector(8 downto 0);
  
  -- Setup the vcc signal as 1
  signal vcc : std_logic := '1';
  
begin
    -- The device unter test
    dut: entity work.fx3
    port map (
      rst_n_in => rst_n_in,
      clk_in => clk_in,
      fx3_pclk_out => fx3_pclk_out,
      fx3_slcs_n_out => fx3_slcs_n_out,
      fx3_slrd_n_out => fx3_slrd_n_out,
      fx3_slwr_n_out => fx3_slwr_n_out,
      fx3_sloe_n_out => fx3_sloe_n_out,
      fx3_fifo_address_out => fx3_fifo_address_out,
      fx3_flaga_in => fx3_flaga_in,
      fx3_flagb_in => fx3_flagb_in,
      fx3_flagc_in => fx3_flagc_in,
      fx3_flagd_in => fx3_flagd_in,
      fx3_pktend_n_out => fx3_pktend_n_out,
      fx3_fdata_inout => fx3_fdata_inout,
      fx3_pmode_out => fx3_pmode_out,
      fx3_reset_out => fx3_reset_out,

      -- RX Fifo
      rx_ready_in => rx_ready_in,
      rx_data_out => rx_data_out,
      rx_valid_out => rx_valid_out,

      -- RX Fifo
      tx_ready_out => tx_ready_out,
      tx_data_in => tx_data_in,
      tx_valid_in => tx_valid_in,

      -- Test Signals
      rx_fifo_data_count_out => rx_fifo_data_count_out,
      tx_fifo_data_count_out => tx_fifo_data_count_out
      );
    
    -- Setup the 50 MHz clock
    clock : process is begin
      loop
        clk_in <= '0'; wait for 10 ns;
        clk_in <= '1'; wait for 10 ns;
      end loop;
    end process clock;

    -- Let's check our work!
    main : process

      -- ***** -- Supporting Proceudres -- ***** --
      
      procedure sleep(constant delay : in natural) is 
        variable I : integer range 0 to 2048; 
        begin
          I := 0;
          while (I < delay) loop
            wait until rising_edge(fx3_pclk_out);
            I := I + 1;
          end loop; 
      end procedure sleep;

      -- ***** -- Housekeeping Procedures -- ***** --

      procedure clear_flags is begin  
        fx3_flaga_in <= '0';
        fx3_flagb_in <= '0';
        fx3_flagc_in <= '0';
        fx3_flagd_in <= '0';
        sleep(1);
      end procedure clear_flags;

      procedure clear_rx_buffer is begin
        rx_ready_in <= '1';
        sleep(512);
        rx_ready_in <= '0';
      end procedure clear_rx_buffer;

      procedure read_setup(constant length : in natural) is begin
        
        clear_rx_buffer;
        
        -- Setup Flags --
        fx3_flaga_in <= '0';            -- FX3 not ready to read
        fx3_flagb_in <= '0';            -- FX3 not ready to read
        fx3_flagc_in <= '1';            -- Set ready flag (Flag C)
        if(length > FX3_WATERMARK) then -- Set watermark flag (Flag D)
          fx3_flagd_in <= '1';          -- Higher than watermark
        else
          fx3_flagd_in <= '0';          -- Less than watermark
        end if;

        wait until not fx3_slrd_n_out;  -- Wait for the FPGA to request data
        sleep(2);                       -- 2 cycle latency from SLRDn to data

      end procedure read_setup;

      -- FX3 is outta' data. Clear the flags.
      procedure read_done is begin
        
        fx3_flagd_in <= '0';  -- Clear the watermark, it's ahead of the game
        sleep(1);             -- FX3 Ready (Flag C) delayed by 2 clock cycles
        clear_flags;
        sleep(5);             -- Allow time to propigate through the FPGA

      end procedure read_done;

      procedure send_data_from_fx3(constant data : in std_logic_vector(31 downto 0)) is begin
        fx3_fdata_inout <= data;
      end procedure send_data_from_fx3;

      procedure load_tx_fifo(constant value : in std_logic_vector(31 downto 0)) is begin
        tx_data_in <= value;
        tx_valid_in <= '1';
        sleep(1);
        tx_valid_in <= '0';
      end procedure load_tx_fifo;

      -- ***** -- Test Procedures -- ***** --

      procedure check_fx3_bulk_read(constant length : in natural) is
        variable data_position : std_logic_vector(7 downto 0) := X"00"; 
        begin

        read_setup(length);
        
        for I in 1 to length-1 loop
          if(fx3_slrd_n_out = '0') then
            send_data_from_fx3(data_position & X"C0FFEE");
            data_position := data_position + '1';
            sleep(1);
          else
            sleep(30);
            rx_ready_in <= '1';
            wait until fx3_slrd_n_out = '0';
          end if;
        end loop;

        read_done;

        -- Check output against expected result.
        assert rx_data_out = X"00C0FFEE"
          report "Mismatch in FX3 to FPGA Bulk Read Test: " &
            "FX3 Data = " & integer'image(to_integer(unsigned(AWESOME_BULK_HEX))) & "; " &
            "FIFO Data = " & integer'image(to_integer(unsigned(rx_data_out))) & "; " &
            "FX3 RX FIFO Size = " & integer'image(to_integer(unsigned(rx_fifo_data_count_out)))
          severity error;

        -- Verify the FIFO size
        assert rx_fifo_data_count_out = length
          report "FPGA FIFO Size is wrong: " &
                  "Expected Size = " & integer'image(length) & "; Reported Size = " & 
                  integer'image(to_integer(unsigned(rx_fifo_data_count_out)))
          severity error;

      end procedure check_fx3_bulk_read;

      procedure check_fx3_single_read is begin

        read_setup(1);
        send_data_from_fx3(AWESOME_TEST_HEX);
        read_done;

        -- Check output against expected result.
        assert rx_data_out = AWESOME_TEST_HEX
          report "Mismatch in FX3 to FPGA Single Read Test: " &
                  "FX3 Data = " & integer'image(to_integer(unsigned(AWESOME_TEST_HEX))) & "; " &
                  "FIFO Data = " & integer'image(to_integer(unsigned(rx_data_out))) & "; " &
                  "FX3 RX FIFO Size = " & integer'image(to_integer(unsigned(rx_fifo_data_count_out)))
          severity error;

        -- Verify the FIFO size
        assert rx_fifo_data_count_out = 1
          report "FPGA FIFO Size is wrong: " &
                  "Expected Size = 1; Reported Size = " & 
                  integer'image(to_integer(unsigned(rx_fifo_data_count_out)))
          severity error;
        
      end procedure check_fx3_single_read;

      procedure check_fx3_single_write(constant in1 : in std_logic_vector(31 downto 0)) is begin

        -- FX3 is empty at power on!
        fx3_flaga_in <= '1';
        fx3_flagb_in <= '1';
        fx3_flagc_in <= '0';
        fx3_flagd_in <= '0';

        load_tx_fifo(in1);
        
        -- Wait until we send the first chunk
        wait until fx3_slwr_n_out <= '0';

        assert fx3_fdata_inout = in1
        report "Unexpected Result in FIFO to FX3 Check: " &
        "FIFO Data = " & integer'image(to_integer(unsigned(in1))) & "; " &
        "FX3 Data = " & integer'image(to_integer(unsigned(fx3_fdata_inout))) & "; " &
        "FX3 Data Expected = " & integer'image(to_integer(unsigned(in1)))
        severity error;

      end procedure check_fx3_single_write;

    begin
      test_runner_setup(runner, runner_cfg); -- Required for vunit

      -- Set inputs & inouts or live in the land of U
      -- Set-up the FX3 to power on default state
      rst_n_in <= '0';
      rx_ready_in <= '0';
      tx_data_in <= X"0000_0000";
      tx_valid_in <= '0';
      fx3_flaga_in <= '1';
      fx3_flagb_in <= '0';
      fx3_flagc_in <= '0';
      fx3_flagd_in <= '0';
      fx3_fdata_inout <= (Others => 'Z');

      wait for 1 ns;
      rst_n_in <= '1';
      wait for 1 ns;
      
      while test_suite loop
        if run("Single FX3 Read Test") then
          check_fx3_single_read;
        elsif run("Bulk FX3 Read Test") then
          check_fx3_bulk_read(100);
        elsif run("FX3 to FIFO") then
          check_fx3_single_write(X"2345_6789");
        end if;
      end loop;

      test_runner_cleanup(runner);  -- Required for vunit
    end process main;
end architecture testbench1;
