library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- pragma translate_off
library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
-- pragma translate_on

entity fx3 is
    port(
        -- Board Support
        rst_n_in : in std_logic;    -- Sync Reset
        clk_in  : in std_logic;     -- Input Clock (50 MHz)
        
        -- FX3
        fx3_pclk_out    : out std_logic;    -- FX3 Clock (100 MHz)

        fx3_slcs_n_out  : out std_logic;    -- Chip Select (Active Low)
        fx3_slrd_n_out  : out std_logic;    -- Read (Active Low)
        fx3_slwr_n_out  : out std_logic;    -- Write (Active Low)
        fx3_sloe_n_out  : out std_logic;    -- Output Enable (Active Low)
        
        fx3_fifo_address_out    : out std_logic_vector(1 downto 0); -- FIFO Address Select

        fx3_flaga_in    : in std_logic;   -- Address 00 DMA Ready (Active Low)
        fx3_flagb_in    : in std_logic;   -- Address 00 DMA Watermark (Active Low)
        fx3_flagc_in    : in std_logic;   -- Address 11 DMA Ready (Active Low)
        fx3_flagd_in    : in std_logic;   -- Address 11 DMA Watermark (Active Low)

        fx3_pktend_n_out   : out std_logic;    -- End of Packet or Zero Length Packet Signal (Active Low)

        fx3_fdata_inout    : inout std_logic_vector(31 downto 0); -- The bidirectional data bus

        fx3_pmode_out      : out std_logic_vector(1 downto 0);  -- Boot-mode Selector
        fx3_reset_out      : out std_logic;                     -- FX3 Reset

        -- RX FIFO
        rx_ready_in        : in std_logic;
        rx_data_out        : out std_logic_vector(31 downto 0);
        rx_valid_out       : out std_logic;

        -- TX FIFO
        tx_ready_out       : out std_logic;
        tx_data_in         : in std_logic_vector(31 downto 0);
        tx_valid_in        : in std_logic;

        -- Test Siganls -- Consider wrapping in synthesis_off/on
        rx_fifo_data_count_out : out std_logic_vector(9 downto 0);
        tx_fifo_data_count_out : out std_logic_vector(9 downto 0)
    );

end entity fx3;

architecture rtl of fx3 is

    -- State Machine Signals
    type state_type is (
        state_reset,
        state_idle,
        state_idle_2,
        state_read,
        state_oe_delay,
        state_oe_delay_2,
        state_oe_delay_3,
        state_flaga_wait,
        state_flagb_wait,
        state_write,
        state_write_fx3_backpressure,
        state_end_of_packet,
        state_end_of_packet_hold_0,
        state_end_of_packet_hold_1,
        state_end_of_packet_hold_2
    );

    signal state, next_state   : STATE_TYPE;
    signal rst      : std_logic;
    signal data, data_0, data_1             : std_logic_vector(31 downto 0);
    signal c_0, c_1                         : std_logic;
     
    signal msg_buffer   : std_logic_vector(31 downto 0);
    signal led_buffer   : std_logic_vector(7 downto 0);

    signal cpu_to_fpga_buffer_empty         : std_logic;
    signal cpu_to_fpga_buffer_full          : std_logic;
    signal cpu_to_fpga_buffer_almost_empty  : std_logic;
    signal cpu_to_fpga_buffer_almost_full   : std_logic;

    signal fpga_to_cpu_buffer_empty         : std_logic;
    signal fpga_to_cpu_buffer_full          : std_logic;
    signal fpga_to_cpu_buffer_almost_empty  : std_logic;
    signal fpga_to_cpu_buffer_almost_full   : std_logic;

    signal data_valid_from_fx3              : std_logic;
    signal data_valid_from_fpga             : std_logic;
    signal data_valid_from_fpga_watermark   : std_logic;
    signal data_ready_from_fpga             : std_logic;
    signal data_in_from_fx3                 : std_logic_vector(31 downto 0);
    signal data_out_to_fx3                  : std_logic_vector(31 downto 0);
    signal RX_VAILD                         : std_logic;

begin

    fpga_to_cpu_fifo : entity work.fifo
    port map (
        clock    => clk_in,
        rst     => rst,

        -- FPGA to CPU (TX)
        data_in     => tx_data_in,
        write_ena   => tx_valid_in,
        
        -- Internal FX3 Block Signals
        read_ena    => data_ready_from_fpga,
        data_out    => data_out_to_fx3,
        
        -- Flags
        almost_empty => fpga_to_cpu_buffer_almost_empty,
        almost_full  => fpga_to_cpu_buffer_almost_full,
        empty    => fpga_to_cpu_buffer_empty,
        full     => fpga_to_cpu_buffer_full,

        -- Debug
        usedw    => tx_fifo_data_count_out
    );

    tx_ready_out <= '1' when (fpga_to_cpu_buffer_full /= '1') else '0';
    data_valid_from_fpga <= '1' when (fpga_to_cpu_buffer_empty /= '1') else '0';
    data_valid_from_fpga_watermark <= '1' when (fpga_to_cpu_buffer_almost_empty /= '1') else '0';


    cpu_to_fpga_fifo : entity work.fifo 
    port map (
        clock    => clk_in,
        rst     => rst,

        -- CPU to FPGA (RX)
        read_ena    => rx_ready_in,
        data_out    => rx_data_out,
        
        -- Internal FX3 Block Signals
        data_in     => data_in_from_fx3,
        write_ena   => data_valid_from_fx3,
        
        -- Flags
        almost_empty => cpu_to_fpga_buffer_almost_empty,
        --almost_full  => cpu_to_fpga_buffer_almost_full,
        empty    => cpu_to_fpga_buffer_empty,
        full     => cpu_to_fpga_buffer_full,

        -- Debug
        usedw    => rx_fifo_data_count_out
    );

    -- Stateless Signals (because we can't invert in the port map)
    rx_valid_out <= '1' when (cpu_to_fpga_buffer_empty /= '1') else '0';

    rst <= not rst_n_in;

    -- State machine control block - reset and next state indexing
    state_machine_ctrl: process (rst_n_in, clk_in) begin
        if (rst_n_in = '0') then
            state <= state_reset;       -- default state on reset
        elsif (rising_edge(clk_in)) then
            state <= next_state;        -- clocked change of state
        end if;
    end process state_machine_ctrl;
     
    data_latch: process (rst_n_in, fx3_fdata_inout, clk_in) begin
        if (rst_n_in = '0') then
            data <= (Others => '0');       -- default state on reset
        elsif (rising_edge(clk_in)) then
            data <= fx3_fdata_inout;
        end if;
    end process data_latch;

    deal_with_delayed_flag_c: process (all) begin
        if (rst_n_in = '0') then
            data_valid_from_fx3 <= '0';
            data_in_from_fx3 <= (Others => '0');
        elsif (rising_edge(clk_in)) then
            if (state = state_read or state = state_oe_delay) then
                data_0 <= fx3_fdata_inout;
                data_1 <= data_0;

                c_0 <= '1';
                c_1 <= c_0;

                data_valid_from_fx3 <= c_1;
                data_in_from_fx3 <= data_1;
            else
                c_0 <= '0';
                c_1 <= '0';
                data_valid_from_fx3 <= '0';

                data_0 <= (Others => '0');
                data_1 <= (Others => '0');
                data_in_from_fx3 <= (Others => '0');
            end if;
        end if;
    end process deal_with_delayed_flag_c;

    -- rst_n_in, state, fx3_flaga_in, fx3_flagb_in, fx3_flagc_in, fx3_flagd_in, cpu_to_fpga_buffer_full, data_valid_from_fpga 
    state_machine: process (all) begin
     if(rst_n_in = '0') then
	     fx3_slcs_n_out <= '1';
        fx3_pktend_n_out <= '1';
        fx3_sloe_n_out <= '1';
        fx3_slrd_n_out <= '1';
        fx3_slwr_n_out <= '1';
        fx3_fifo_address_out <= "11";
        fx3_fdata_inout <= (Others => 'Z');
        data_ready_from_fpga <= '0';
        next_state <= state_reset;
    else
        case( state ) is
            when state_reset =>
                fx3_slcs_n_out <= '1';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                -- Do we have data to read and the fifo has space?
                if(fx3_flagc_in = '1') and (cpu_to_fpga_buffer_full = '0') then
                    next_state <= state_idle;
                -- Do we have data to send to the CPU?
                elsif (fx3_flaga_in = '1') and (data_valid_from_fpga = '1') then
                    next_state <= state_flaga_wait;
                else
                    next_state <= state_reset;
                end if;

            -- Reading Data from FX3
            -- Two cycle latency from SLRDn to Data Valid
            when state_idle =>
                fx3_slcs_n_out <= '1';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '0';
                fx3_slrd_n_out <= '0';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');

                data_ready_from_fpga <= '0';

                next_state <= state_idle_2;

            when state_idle_2 =>
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '0';
                fx3_slrd_n_out <= '0';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');

                data_ready_from_fpga <= '0';

                next_state <= state_read;
                
            when state_read =>
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '0';
                fx3_slrd_n_out <= '0';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');

                -- writing from FX3
                --data_valid_from_fx3 <= '1';
                --data_in_from_fx3 <= fx3_fdata_inout;

                -- reading from FX3
                data_ready_from_fpga <= '0';

                -- next state control
                if(fx3_flagc_in = '1') and (cpu_to_fpga_buffer_full = '0') then
                    next_state <= state_read;
                else
                    next_state <= state_oe_delay;
                end if;
                
            when state_oe_delay =>
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '0';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');

                data_ready_from_fpga <= '0';

                next_state <= state_oe_delay_2;

            when state_oe_delay_2 =>
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '0';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                next_state <= state_oe_delay_3;

            when state_oe_delay_3 =>
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '0';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                if (fx3_flaga_in = '1') and (data_valid_from_fpga = '1') then -- Do we have data to send to the CPU?
                    next_state <= state_flaga_wait;
                else
                    next_state <= state_reset;
                end if;
                     
            -- Writing Data to the FX3
            when state_flaga_wait =>
                
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "00";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                next_state <= state_flagb_wait;
                                     
            when state_flagb_wait =>
                
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "00";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '1';
                
                next_state <= state_write;
                     
            when state_write =>
                
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '0';
                fx3_fifo_address_out <= "00";
                
                fx3_fdata_inout <= data_out_to_fx3;
                data_ready_from_fpga <= '1';

                -- If we see the back pressure watermark flag, stop sending data
                if(fx3_flagb_in = '1') and (data_valid_from_fpga_watermark = '1') then
                    next_state <= state_write;
                elsif (fx3_flagb_in = '0') then
                    next_state <= state_write_fx3_backpressure;
                else
                    next_state <= state_end_of_packet;
                end if;

            when state_write_fx3_backpressure =>
                
					 fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '0';
                fx3_fifo_address_out <= "00";
                
                fx3_fdata_inout <= data_out_to_fx3;
                data_ready_from_fpga <= '1';

                next_state <= state_end_of_packet;

            when state_end_of_packet =>
                
                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '0';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '0';
                fx3_fifo_address_out <= "00";
                
                fx3_fdata_inout <= data_out_to_fx3;
                data_ready_from_fpga <= '1';

                next_state <= state_end_of_packet_hold_0;

            when state_end_of_packet_hold_0 =>

                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "00";
                
                fx3_fdata_inout <= (Others => '0');
                data_ready_from_fpga <= '0';

                next_state <= state_end_of_packet_hold_1;

            when state_end_of_packet_hold_1 =>

                fx3_slcs_n_out <= '0';
					 fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "00";
                
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                next_state <= state_end_of_packet_hold_2;

            when state_end_of_packet_hold_2 =>
					 fx3_slcs_n_out <= '0';
                fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "00";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                next_state <= state_reset;
                         
            when others =>
					 fx3_slcs_n_out <= '1';
                fx3_pktend_n_out <= '1';
                fx3_sloe_n_out <= '1';
                fx3_slrd_n_out <= '1';
                fx3_slwr_n_out <= '1';
                fx3_fifo_address_out <= "11";
                fx3_fdata_inout <= (Others => 'Z');
                data_ready_from_fpga <= '0';

                next_state <= state_reset;
        end case;
    end if;
    end process state_machine;
        
    ---- Stateless Signals ----

    
    fx3_pmode_out<= "11";    
    fx3_reset_out <= '1';
    fx3_pclk_out <= clk_in;

end architecture;
