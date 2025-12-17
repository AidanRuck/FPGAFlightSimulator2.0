library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_flight_sim is
    port(
        clk        : in  std_logic;             -- 100 MHz
        x_raw      : in  signed(15 downto 0);   -- accel X
        y_raw      : in  signed(15 downto 0);   -- accel Y
        x_pos_bin  : out signed(4 downto 0);    -- X position bin output (-8 to +8)
        y_pos_bin  : out signed(4 downto 0)     -- Y position bin output (-8 to +8)
    );
end entity;

architecture Behavioral of vga_flight_sim is

    -- step direction
    signal X_step, Y_step : integer range -1 to 1 := 0;

    -- position in bins
    signal X_bin_vga_int, Y_bin_vga_int : integer range -8 to 8 := 0;

    -- counter used to slow down how often position updates happen
    signal move_div : unsigned(23 downto 0) := (others => '0');
    constant MOVE_MAX : unsigned(23 downto 0) := (others => '1');

begin

    -- convert accelerometer tilt into simple step directions using thresholds
    tilt_step_proc : process(x_raw, y_raw)
        constant THRESH_RIGHT : signed(15 downto 0) := to_signed(200, 16);
        constant THRESH_LEFT  : signed(15 downto 0) := to_signed(200, 16);
        constant THRESH_UP    : signed(15 downto 0) := to_signed(200, 16);
        constant THRESH_DOWN  : signed(15 downto 0) := to_signed(200, 16);
    begin
        -- X axis
        if x_raw > THRESH_RIGHT then
            X_step <= 1;
        elsif x_raw < -THRESH_LEFT then
            X_step <= -1;
        else
            X_step <= 0;
        end if;

        -- Y axis
        if y_raw > THRESH_DOWN then
            Y_step <= 1;
        elsif y_raw < -THRESH_UP then
            Y_step <= -1;
        else
            Y_step <= 0;
        end if;
    end process;

    -- Update position only when the counter reaches its max value
    vga_move_proc : process(clk)
        variable next_x, next_y : integer;  
    begin
        if rising_edge(clk) then

            if move_div = MOVE_MAX then
                move_div <= (others => '0');

                -- update X position and keep it within -8 to +8
                next_x := X_bin_vga_int + X_step;
                if next_x > 8 then
                    X_bin_vga_int <= 8;
                elsif next_x < -8 then
                    X_bin_vga_int <= -8;
                else
                    X_bin_vga_int <= next_x;
                end if;

                -- Update Y position and keep it within -8 to +8
                next_y := Y_bin_vga_int + Y_step;
                if next_y > 8 then
                    Y_bin_vga_int <= 8;
                elsif next_y < -8 then
                    Y_bin_vga_int <= -8;
                else
                    Y_bin_vga_int <= next_y;
                end if;

            else
                -- keep counting until it's time to move again
                move_div <= move_div + 1;
            end if;

        end if;
    end process;

    -- Output the current position bins
    x_pos_bin <= to_signed(X_bin_vga_int, 5);
    y_pos_bin <= to_signed(Y_bin_vga_int, 5);

end architecture;
