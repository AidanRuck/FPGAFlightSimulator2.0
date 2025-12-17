library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_draw is
    port(
        X_bin     : in  signed(4 downto 0);
        Y_bin     : in  signed(4 downto 0);

        -- vga pixel position from timing module
        pixel_row : in  std_logic_vector(10 downto 0);
        pixel_col : in  std_logic_vector(10 downto 0);

        -- target circle in pixel coordinates
        ring_on   : in  std_logic;
        ring_x    : in  unsigned(9 downto 0);  -- 0..799
        ring_y    : in  unsigned(9 downto 0);  -- 0..599

         -- vga color outputs
        R         : out std_logic_vector(3 downto 0);
        G         : out std_logic_vector(3 downto 0);
        B         : out std_logic_vector(3 downto 0)
    );
end entity;

architecture Behavioral of vga_draw is
    -- target ring size
    constant CIRCLE_R  : integer := 24;
    constant CIRCLE_R2 : integer := CIRCLE_R * CIRCLE_R;
begin

    process(pixel_row, pixel_col, X_bin, Y_bin, ring_on, ring_x, ring_y)
        variable hx, hy : integer;  -- current pixel location
        variable cx, cy : integer;  -- plane center position
        variable dx, dy : integer;  -- offset from plane center

        -- circle math
        variable tx_i, ty_i : integer; -- circle center
        variable tdx, tdy   : integer; -- offset from center
        variable d2         : integer; -- squared dist for circle test

        variable circle_pixel : boolean; -- T if pixel is inside circle
        variable plane_pixel  : boolean; -- T is pixel is part of the plane
    begin
        -- default: black background
        R <= (others => '0');
        G <= (others => '0');
        B <= (others => '0');

        -- convert the current pixel coordinates to integers
        hx := to_integer(unsigned(pixel_col)); 
        hy := to_integer(unsigned(pixel_row));

        -- only draw inside the active screen area
        if (hx < 800) and (hy < 600) then

            -- convert aircraft bins into pixel coordinates
            cx := 400 + to_integer(X_bin) * 50;
            cy := 300 - to_integer(Y_bin) * 37;

            -- clamp plane center
            if cx < 0 then cx := 0; elsif cx > 799 then cx := 799; end if;
            if cy < 0 then cy := 0; elsif cy > 599 then cy := 599; end if;

            dx := hx - cx;
            dy := hy - cy;

            -- check if the current pixel is inside the target ring
            circle_pixel := false;
            if ring_on = '1' then
                tx_i := to_integer(ring_x);
                ty_i := to_integer(ring_y);

                tdx := hx - tx_i;
                tdy := hy - ty_i;

                d2 := tdx*tdx + tdy*tdy;

                if d2 <= CIRCLE_R2 then
                    circle_pixel := true;
                end if;
            end if;

            -- plane shape
            plane_pixel := false;

            -- fuselage (main body)
            if (abs(dx) <= 8) and (abs(dy) <= 4) then
                plane_pixel := true;

            -- nose (triangle pointing up)
            elsif (dy < -4) and (dy >= -12) and
                  (abs(dx) <= (-dy - 4)) then
                plane_pixel := true;

            -- left wing
            elsif (dx >= -18) and (dx <= -8) and
                  (abs(dy) <= 2) then
                plane_pixel := true;

            -- right wing
            elsif (dx >= 8) and (dx <= 18) and
                  (abs(dy) <= 2) then
                plane_pixel := true;
            end if;

            -- draw ring first, then draw plane on top
            if circle_pixel then
                R <= (others => '0');
                G <= (others => '1');
                B <= (others => '1');
            end if;

            if plane_pixel then
                R <= (others => '1');
                G <= (others => '1');
                B <= (others => '0');
            end if;

        end if;
    end process;

end architecture Behavioral;
