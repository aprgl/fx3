library ieee;
use ieee.std_logic_1164.all;

entity fx3 is
	port(
		-- Board Support
		rst_n_in 	: in std_logic; 	-- Sync Reset
		clk_in 		: in std_logic; 	-- Input Clock (50 MHz)
		LED 		: out std_logic_vector(7 downto 0);
		switches	: in std_logic_vector(1 downto 0);
		
		-- FX3
		fx3_pclk_out 	: out std_logic;	-- FX3 Clock (100 MHz)

		fx3_slcs_n_out	: out std_logic;	-- Chip Select (Active Low)
		fx3_slrd_n_out	: out std_logic;	-- Read (Active Low)
		fx3_slwr_n_out	: out std_logic;	-- Write (Active Low)
		fx3_sloe_n_out	: out std_logic; 	-- Output Enable (Active Low)
		
		fx3_fifo_address_out 	: out std_logic_vector(1 downto 0); -- FIFO Address Select

		fx3_flaga_in 	: in std_logic; 	-- FIFO Address 0 Empty=0
		fx3_flagb_in 	: in std_logic; 	-- FIFO Address 1 Empty=0

		fx3_pktend_n_out 	: out std_logic; 	-- End of Packet or Zero Length Packet Signal (Active Low)

		fx3_fdata_inout 	: inout std_logic_vector(31 downto 0);	-- The bidirectional data bus

		fx3_pmode_out	: out std_logic_vector(1 downto 0);	-- Bootmode Selector
		fx3_reset_out 	: out std_logic					-- FX3 Reset
	);

end entity fx3;

architecture rtl of fx3 is

	-- State Machine Signals
	type state_type is (
		state_reset,
		state_idle,
		state_read
	);
	signal state, next_state   : STATE_TYPE;

begin

	-- State machine control block - reset and next state indexing
    state_machine_ctrl: process (rst_n_in, clk_in) begin
		if (rst_n_in = '0') then
			state <= state_reset;       -- default state on reset
	    elsif (rising_edge(clk_in)) then
			state <= next_state;        -- clocked change of state
		end if;
    end process state_machine_ctrl;

    state_machine: process (state) 
    	variable counter: integer := 0;
    begin
    	case( state ) is
    	
    		when state_reset =>
    			fx3_sloe_n_out <= '1';
    			fx3_slrd_n_out <= '1';
    			fx3_slwr_n_out <= '1';
    			fx3_fifo_address_out <= "00";
    			next_state <= state_idle;
    		when state_idle =>
    			fx3_sloe_n_out <= '0';
    			fx3_slrd_n_out <= '1';
    			fx3_slwr_n_out <= '1';
    			fx3_fifo_address_out <= "00";
    			next_state <= state_read;
    		when state_read =>
    			if(rising_edge(clk_in)) then
    				if(counter < 10) then
    					counter := counter + 1;
    				else
    					counter := 0;
    					next_state <= state_reset;
    				end if;
    			end if;
    			fx3_sloe_n_out <= '0';
    			fx3_slrd_n_out <= '0';
    			fx3_slwr_n_out <= '1';
    			fx3_fifo_address_out <= "00";
    		when others =>
    			next_state <= state_reset;
    	end case;
    end process state_machine;
    	
    -- Stateless Signals
    fx3_slcs_n_out <= '0';
    fx3_pktend_n_out <= '1';
    clk_out <= clk_in;

end architecture;
