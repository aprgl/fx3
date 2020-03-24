-------------------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
--
-- Description: Creates a Synchronous FIFO made out of registers.
--              Generic: g_WIDTH sets the width of the FIFO created.
--              Generic: g_DEPTH sets the depth of the FIFO created.
--
--              Total FIFO register usage will be width * depth
--              Note that this fifo should not be used to cross clock domains.
--              (Read and write clocks NEED TO BE the same clock domain)
--
--              FIFO Full Flag will assert as soon as last word is written.
--              FIFO Empty Flag will assert as soon as last word is read.
--
--              FIFO is 100% synthesizable.  It uses assert statements which do
--              not synthesize, but will cause your simulation to crash if you
--              are doing something you shouldn't be doing (reading from an
--              empty FIFO or writing to a full FIFO).
--
--              With Flags = Has Almost Full (AF)/Almost Empty (AE) Flags
--              These are settable via Generics: g_AF_LEVEL and g_AE_LEVEL
--              g_AF_LEVEL: Goes high when # words in FIFO is > this number.
--              g_AE_LEVEL: Goes high when # words in FIFO is < this number.
-------------------------------------------------------------------------------
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- pragma translate_off
library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
-- pragma translate_on
 
entity fifo is
  generic (
    g_WIDTH    : natural := 32;
    g_DEPTH    : integer := 1024;
    g_AF_LEVEL : integer := 3;
    g_AE_LEVEL : integer := 3
    );

  port (
    rst : in std_logic;
    clock      : in std_logic;
 
    -- FIFO Write Interface
    write_ena   : in  std_logic;
    data_in : in  std_logic_vector(g_WIDTH-1 downto 0);
    almost_full      : out std_logic;
    full    : out std_logic;
 
    -- FIFO Read Interface
    read_ena   : in  std_logic;
    data_out : out std_logic_vector(g_WIDTH-1 downto 0);
    almost_empty      : out std_logic;
    empty   : out std_logic;

    usedw : out std_logic_vector(9 downto 0)
    );
end fifo;
 
architecture rtl of fifo is
 
  type t_FIFO_DATA is array (0 to g_DEPTH-1) of std_logic_vector(g_WIDTH-1 downto 0);
  signal r_FIFO_DATA : t_FIFO_DATA := (others => (others => '0'));
 
  signal r_WR_INDEX   : integer range 0 to g_DEPTH-1 := 0;
  signal r_RD_INDEX   : integer range 0 to g_DEPTH-1 := 0;
 
  -- # Words in FIFO, has extra range to allow for assert conditions
  signal r_FIFO_COUNT : integer range -1 to g_DEPTH+1 := 0;
 
  signal w_FULL  : std_logic;
  signal w_EMPTY : std_logic;
   
begin
 
  p_CONTROL : process (clock) is
  begin
    if rising_edge(clock) then
      if rst = '1' then
        r_FIFO_COUNT <= 0;
        r_WR_INDEX   <= 0;
        r_RD_INDEX   <= 0;
      else
 
        -- Keeps track of the total number of words in the FIFO
        if (write_ena = '1' and read_ena = '0') then
          r_FIFO_COUNT <= r_FIFO_COUNT + 1;
        elsif (write_ena = '0' and read_ena = '1') then
          r_FIFO_COUNT <= r_FIFO_COUNT - 1;
        end if;
 
        -- Keeps track of the write index (and controls roll-over)
        if (write_ena = '1' and w_FULL = '0') then
          if r_WR_INDEX = g_DEPTH-1 then
            r_WR_INDEX <= 0;
          else
            r_WR_INDEX <= r_WR_INDEX + 1;
          end if;
        end if;
 
        -- Keeps track of the read index (and controls roll-over)        
        if (read_ena = '1' and w_EMPTY = '0') then
          if r_RD_INDEX = g_DEPTH-1 then
            r_RD_INDEX <= 0;
          else
            r_RD_INDEX <= r_RD_INDEX + 1;
          end if;
        end if;
 
        -- Registers the input data when there is a write
        if write_ena = '1' then
          r_FIFO_DATA(r_WR_INDEX) <= data_in;
        end if;
         
      end if;                           -- sync reset
    end if;                             -- rising_edge(clock)
  end process p_CONTROL;
 
   
  data_out <= r_FIFO_DATA(r_RD_INDEX);
 
  w_FULL  <= '1' when r_FIFO_COUNT = g_DEPTH else '0';
  w_EMPTY <= '1' when r_FIFO_COUNT = 0       else '0';
 
  almost_full <= '1' when r_FIFO_COUNT > g_AF_LEVEL else '0';
  almost_empty <= '1' when r_FIFO_COUNT < g_AE_LEVEL else '0';
   
  full  <= w_FULL;
  empty <= w_EMPTY;
  usedw <= STD_LOGIC_VECTOR(TO_UNSIGNED(r_FIFO_COUNT,10));
   
 
  -----------------------------------------------------------------------------
  -- ASSERTION LOGIC - Not synthesized
  -----------------------------------------------------------------------------
  -- synthesis translate_off
 
  p_ASSERT : process (clock) is
  begin
    if rising_edge(clock) then
      if write_ena = '1' and w_FULL = '1' then
        report "ASSERT FAILURE - MODULE_REGISTER_FIFO: FIFO IS FULL AND BEING WRITTEN " severity failure;
      end if;
 
      if read_ena = '1' and w_EMPTY = '1' then
        report "ASSERT FAILURE - MODULE_REGISTER_FIFO: FIFO IS EMPTY AND BEING READ " severity failure;
      end if;
    end if;
  end process p_ASSERT;
 
  -- synthesis translate_on
     
   
end rtl;