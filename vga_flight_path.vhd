library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_flight_path is
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;
        
        -- One-cycle enable signal at the game update rate
        tick  : in  std_logic;

        -- player position in bins
        X_bin : in  signed(4 downto 0);
        Y_bin : in  signed(4 downto 0);

        -- target outputs (pixel coords)
        ring_on : out std_logic;
        ring_x  : out unsigned(9 downto 0);  -- 0..799
        ring_y  : out unsigned(9 downto 0);  -- 0..599

        -- game outputs
        collected_pulse : out std_logic;
        score           : out unsigned(15 downto 0)
    );
end entity;

architecture Behavioral of vga_flight_path is

    -- convert bin position into pixel position
    constant CX0      : integer := 400;
    constant CY0      : integer := 300;
    constant X_STEP   : integer := 50;
    constant Y_STEP   : integer := 37;

    -- target ring size in pixels
    constant CIRCLE_R  : integer := 24;
    constant CIRCLE_R2 : integer := CIRCLE_R * CIRCLE_R;

    -- keep targets away from the screen edges
    constant MARGIN_X : integer := 40;
    constant MARGIN_Y : integer := 40;

    -- bounding box used for aircraft collision checks
    constant PLANE_X_HALF : integer := 18; -- left/right extent
    constant PLANE_Y_UP   : integer := 12; -- how far up (nose)
    constant PLANE_Y_DOWN : integer := 4;  -- how far down (body)

    -- stored target position and score
    signal ring_x_r  : unsigned(9 downto 0) := to_unsigned(600, 10);
    signal ring_y_r  : unsigned(9 downto 0) := to_unsigned(300, 10);
    signal ring_on_r : std_logic := '1';
    signal score_r   : unsigned(15 downto 0) := (others => '0');

    -- 16-bit LFSR for pseudo-random
    signal lfsr      : unsigned(15 downto 0) := x"ACE1";

    -- clamp a value to stay within a min/max range
    function clamp(val, lo, hi : integer) return integer is
    begin
        if val < lo then return lo;
        elsif val > hi then return hi;
        else return val;
        end if;
    end function;

    -- compute the next LFSR value
    function lfsr_next(s : unsigned(15 downto 0)) return unsigned is
        variable fb : std_logic;
        variable t  : unsigned(15 downto 0);
    begin
        fb := s(15) xor s(13) xor s(12) xor s(10);
        t  := s(14 downto 0) & fb;
        return t;
    end function;

begin

    ring_x  <= ring_x_r;
    ring_y  <= ring_y_r;
    ring_on <= ring_on_r;
    score   <= score_r;

    process(clk)
        variable px, py : integer; -- plane center in pixels
        variable cx, cy : integer; -- circle center in pixels

        -- plane bounding box
        variable left_x, right_x : integer;
        variable top_y, bot_y    : integer;

        -- closest point on rect to circle center
        variable closest_x, closest_y : integer;

        variable dx, dy : integer;
        variable d2     : integer;

        variable new_x  : integer;
        variable new_y  : integer;
        variable raw_x  : integer;
        variable raw_y  : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- reset ring, score, and RNG state
                ring_x_r <= to_unsigned(600, 10);
                ring_y_r <= to_unsigned(300, 10);
                ring_on_r <= '1';
                score_r <= (others => '0');
                lfsr <= x"ACE1";
                collected_pulse <= '0';

            else
                -- default
                collected_pulse <= '0';

                if tick = '1' then
                    -- advance RNG
                    lfsr <= lfsr_next(lfsr);

                    -- convert aircraft bins into pixel coordinates
                    px := CX0 + to_integer(X_bin) * X_STEP;
                    py := CY0 - to_integer(Y_bin) * Y_STEP;

                    px := clamp(px, 0, 799);
                    py := clamp(py, 0, 599);

                    -- circle center
                    cx := to_integer(ring_x_r);
                    cy := to_integer(ring_y_r);

                    -- plane bounding box
                    left_x  := px - PLANE_X_HALF;
                    right_x := px + PLANE_X_HALF;
                    top_y   := py - PLANE_Y_UP;
                    bot_y   := py + PLANE_Y_DOWN;

                    -- closest point on rect to circle center
                    closest_x := clamp(cx, left_x, right_x);
                    closest_y := clamp(cy, top_y,  bot_y);

                    -- circle vs box collision test
                    dx := cx - closest_x;
                    dy := cy - closest_y;
                    d2 := dx*dx + dy*dy;

                    -- if hit, increment score and move the ring
                    if (ring_on_r = '1') and (d2 <= CIRCLE_R2) then
                        collected_pulse <= '1';
                        score_r <= score_r + 1;

                        -- spawn next circle using the LFSR state
                        raw_x := to_integer(unsigned(lfsr(9 downto 0)));
                        raw_y := to_integer(unsigned(lfsr(15 downto 10)));
                        raw_y := raw_y * 9 + to_integer(unsigned(lfsr(7 downto 0)));

                        new_x := MARGIN_X + (raw_x mod (800 - 2*MARGIN_X));
                        new_y := MARGIN_Y + (raw_y mod (600 - 2*MARGIN_Y));

                        ring_x_r <= to_unsigned(new_x, 10);
                        ring_y_r <= to_unsigned(new_y, 10);
                        ring_on_r <= '1';
                    end if;

                end if;
            end if;
        end if;
    end process;

end architecture Behavioral;
