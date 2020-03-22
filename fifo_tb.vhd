-------------------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
-------------------------------------------------------------------------------
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
-- Load VUnit Lib
library vunit_lib;
context vunit_lib.vunit_context;

entity fifo_tb is
  generic (runner_cfg : string);
end fifo_tb;
 
architecture behave of fifo_tb is
 
  constant c_DEPTH    : integer := 4;
  constant c_WIDTH    : integer := 8;
  constant c_AF_LEVEL : integer := 2;
  constant c_AE_LEVEL : integer := 2;
 
  signal r_RESET   : std_logic := '0';
  signal r_CLOCK   : std_logic := '0';
  signal r_WR_EN   : std_logic := '0';
  signal r_WR_DATA : std_logic_vector(c_WIDTH-1 downto 0) := X"A5";
  signal w_AF      : std_logic;
  signal w_FULL    : std_logic;
  signal r_RD_EN   : std_logic := '0';
  signal w_RD_DATA : std_logic_vector(c_WIDTH-1 downto 0);
  signal w_AE      : std_logic;
  signal w_EMPTY   : std_logic;
   
  component fifo is
    generic (
      g_WIDTH    : natural := 8;
      g_DEPTH    : integer := 32;
      g_AF_LEVEL : integer := 28;
      g_AE_LEVEL : integer := 4
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
      empty   : out std_logic
      );
  end component fifo;
 
   
begin
 
  MODULE_FIFO_REGS_WITH_FLAGS_INST : fifo
    generic map (
      g_WIDTH    => c_WIDTH,
      g_DEPTH    => c_DEPTH,
      g_AF_LEVEL => c_AF_LEVEL,
      g_AE_LEVEL => c_AE_LEVEL
      )
    port map (
      rst => r_RESET,
      clock      => r_CLOCK,
      write_ena    => r_WR_EN,
      data_in  => r_WR_DATA,
      almost_full       => w_AF,
      full     => w_FULL,
      read_ena    => r_RD_EN,
      data_out  => w_RD_DATA,
      almost_empty       => w_AE,
      empty    => w_EMPTY
      );
 
  r_CLOCK <= not r_CLOCK after 5 ns;
  
  -- Let's check our work!
  main : process

  -- Write Test
  procedure fifo_write_test is
  begin

    --Ahh, single cycle delay?
    r_WR_DATA <= X"33";
    wait until rising_edge(r_CLOCK);
    r_WR_EN <= '1';
    wait until rising_edge(r_CLOCK);
    r_WR_EN <= '0';
    r_RD_EN <= '1';
    wait until rising_edge(r_CLOCK);
    assert w_RD_DATA = X"33"
          report "Unexpected Result in FIFO Single Read Test: " &
          "FIFO Data = " & integer'image(to_integer(unsigned(w_RD_DATA))) & "; " &
          "FIFO Data Expected = " & integer'image(to_integer(unsigned'(X"33")))
          severity error;

  end procedure;

  begin
      test_runner_setup(runner, runner_cfg); -- Required for vunit

      while test_suite loop
        if run("FIFO Write Test") then
          fifo_write_test;
        end if;
      end loop;

      test_runner_cleanup(runner);  -- Required for vunit
  end process main;
   
end behave;