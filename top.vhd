LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY top IS
    PORT(
        CLK_100MHZ : IN  STD_LOGIC; -- 100 MHz clock
        ACL_MISO   : IN  STD_LOGIC; -- SPI data from accel
        ACL_MOSI   : OUT STD_LOGIC; -- SPI data to accel
        ACL_SCLK   : OUT STD_LOGIC; -- SPI clk
        ACL_SS     : OUT STD_LOGIC; -- SPI chip select
        LED        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- score
        SEG7_seg   : OUT STD_LOGIC_VECTOR(6 DOWNTO 0); -- 7 seg outputs
        DP         : OUT STD_LOGIC; -- 7 seg decimal pt
        PWM_OUT    : OUT STD_LOGIC; --PWM output
        SEG7_anode : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- 7 seg digit enable lines
        SW         : IN  STD_LOGIC_VECTOR (1 DOWNTO 0); -- user switches for display select

        VGA_R      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- vga red
        VGA_G      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- vga green
        VGA_B      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- vga blue
        VGA_HS     : OUT STD_LOGIC; -- vga horiz sync
        VGA_VS     : OUT STD_LOGIC -- vga vert sync
    );
END ENTITY;

ARCHITECTURE Behavioral OF top IS

    SIGNAL w_4MHz      : STD_LOGIC; -- 4MHz clock for SPI
    SIGNAL acl_dataALL : STD_LOGIC_VECTOR(14 DOWNTO 0); -- accel data for bins
    SIGNAL acl_dataX   : STD_LOGIC_VECTOR(15 DOWNTO 0); -- accel x raw
    SIGNAL acl_dataY   : STD_LOGIC_VECTOR(15 DOWNTO 0); -- accel y raw
    SIGNAL acl_dataZ   : STD_LOGIC_VECTOR(15 DOWNTO 0); -- accel z raw

    -- scan counter for selecting which 7-seg digit is active
    SIGNAL scan_cnt  : UNSIGNED(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dig       : STD_LOGIC_VECTOR(2 DOWNTO 0);

    -- 4-bit bins for display (0..15), from acl_dataALL
    SIGNAL X_bin, Y_bin, Z_bin : UNSIGNED(3 DOWNTO 0);

    -- digits for each axis
    SIGNAL X_tens, X_ones : UNSIGNED(3 DOWNTO 0);
    SIGNAL Y_tens, Y_ones : UNSIGNED(3 DOWNTO 0);
    SIGNAL Z_tens, Z_ones : UNSIGNED(3 DOWNTO 0);

    -- whole vector of 8 nibbles (4 sections)
    SIGNAL bcd32 : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL bcd_x_only : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL bcd_y_only : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL bcd_z_only : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL bcd_all    : STD_LOGIC_VECTOR(31 DOWNTO 0);

    --------------------------------------------------------------------
    -- VGA signals
    --------------------------------------------------------------------
    SIGNAL pix_clk      : STD_LOGIC; -- 25 MHz pixel clock
    SIGNAL pix_div_cnt  : UNSIGNED(1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL pixel_row    : STD_LOGIC_VECTOR(10 DOWNTO 0);
    SIGNAL pixel_col    : STD_LOGIC_VECTOR(10 DOWNTO 0);

    -- color from vga_draw
    SIGNAL r_draw       : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL g_draw       : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL b_draw       : STD_LOGIC_VECTOR(3 DOWNTO 0);

    -- signed accel and aircraft position bins for VGA
    SIGNAL x_raw, y_raw       : SIGNED(15 DOWNTO 0);
    SIGNAL x_pos_bin, y_pos_bin : SIGNED(4 DOWNTO 0);
    
    -- 60 Hz game tick and ring/score signals
    SIGNAL game_tick : std_logic := '0';

    SIGNAL ring_on_s : std_logic;
    SIGNAL ring_x_s  : unsigned(9 downto 0);
    SIGNAL ring_y_s  : unsigned(9 downto 0);

    SIGNAL ring_score : unsigned(15 downto 0);
    SIGNAL ring_hit   : std_logic;
    
    SIGNAL tick_cnt : unsigned(21 downto 0) := (others => '0'); -- counter for 60 Hz tick
    constant TICK_MAX : unsigned(21 downto 0) := to_unsigned(1666666-1, 22);

    COMPONENT clk_gen
        PORT (
            clk_100MHz : IN  STD_LOGIC;
            clk_4MHz   : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT spi_master
        PORT (
            clk_4MHz     : IN  STD_LOGIC;
            acl_data_ALL : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
            acl_data_X   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            acl_data_Y   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            acl_data_Z   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            SCLK         : OUT STD_LOGIC;
            MOSI         : OUT STD_LOGIC;
            MISO         : IN  STD_LOGIC;
            SS           : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT leddec16
        PORT(
            CLK_100MHZ : IN  STD_LOGIC;
            dig        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
            bcd32      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            anode      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            seg        : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
            dp         : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT controller
        PORT(
            CLK_100MHZ : IN  STD_LOGIC;
            acl_dataX  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            pwm_out    : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN

    -- 25 MHz pixel clock from 100 MHz
    PROCESS(CLK_100MHZ)
    BEGIN
        IF rising_edge(CLK_100MHZ) THEN
            pix_div_cnt <= pix_div_cnt + 1;
            pix_clk     <= pix_div_cnt(1);
        END IF;
    END PROCESS;
    
    -- 60 Hz tick pulse for the game logic
    tick_proc : process(CLK_100MHZ)
    begin
        if rising_edge(CLK_100MHZ) then
            if tick_cnt = TICK_MAX then
                tick_cnt  <= (others => '0');
                game_tick <= '1';          -- one-cycle pulse
            else
                tick_cnt  <= tick_cnt + 1;
                game_tick <= '0';
            end if;
        end if;
    end process;

    clock_gen : clk_gen
        PORT MAP (
            clk_100MHz => CLK_100MHZ,
            clk_4MHz   => w_4MHz
        );

    SPI : spi_master
        PORT MAP (
            clk_4MHz     => w_4MHz,
            acl_data_ALL => acl_dataALL,
            acl_data_X   => acl_dataX,
            acl_data_Y   => acl_dataY,
            acl_data_Z   => acl_dataZ,
            SCLK         => ACL_SCLK,
            MOSI         => ACL_MOSI,
            MISO         => ACL_MISO,
            SS           => ACL_SS
        );

    display : leddec16
        PORT MAP(
            CLK_100MHZ => CLK_100MHZ,
            dig        => dig,
            bcd32      => bcd32,
            anode      => SEG7_anode,
            seg        => SEG7_seg,
            dp         => DP
        );

    control : controller
        PORT MAP (
            CLK_100MHZ => CLK_100MHZ,
            acl_dataX  => acl_dataX,
            pwm_out    => PWM_OUT
        );

    -- LED show the current score value
    LED <= std_logic_vector(ring_score);

    -- select which axis data is shown on the 7-seg display
    WITH SW SELECT
        bcd32 <= bcd_x_only WHEN "00",
                 bcd_y_only WHEN "01",
                 bcd_z_only WHEN "10",
                 bcd_all    WHEN OTHERS;  -- "11"

    -- extract 4-bit bins from packed accelerometer data
    X_bin <= UNSIGNED(acl_dataALL(13 DOWNTO 10));
    Y_bin <= UNSIGNED(acl_dataALL( 8 DOWNTO  5));
    Z_bin <= UNSIGNED(acl_dataALL( 3 DOWNTO  0));

    -- 7-seg BCD conversion
    X_tens <= TO_UNSIGNED(TO_INTEGER(X_bin) / 10, 4);
    X_ones <= TO_UNSIGNED(TO_INTEGER(X_bin) MOD 10, 4);

    Y_tens <= TO_UNSIGNED(TO_INTEGER(Y_bin) / 10, 4);
    Y_ones <= TO_UNSIGNED(TO_INTEGER(Y_bin) MOD 10, 4);

    Z_tens <= TO_UNSIGNED(TO_INTEGER(Z_bin) / 10, 4);
    Z_ones <= TO_UNSIGNED(TO_INTEGER(Z_bin) MOD 10, 4);


    -- build BCD patterns for each display mode
    bcd_all <= STD_LOGIC_VECTOR(X_tens) &
               STD_LOGIC_VECTOR(X_ones) &
               "1111" &
               STD_LOGIC_VECTOR(Y_tens) &
               STD_LOGIC_VECTOR(Y_ones) &
               "1111" &
               STD_LOGIC_VECTOR(Z_tens) &
               STD_LOGIC_VECTOR(Z_ones);

    bcd_x_only <=
        "1111" & "1111" & "1111" & "1111" & "1111" & "1111" &
        STD_LOGIC_VECTOR(X_tens) &
        STD_LOGIC_VECTOR(X_ones);

    bcd_y_only <=
        "1111" & "1111" & "1111" & "1111" & "1111" & "1111" &
        STD_LOGIC_VECTOR(Y_tens) &
        STD_LOGIC_VECTOR(Y_ones);

    bcd_z_only <=
        "1111" & "1111" & "1111" & "1111" & "1111" & "1111" &
        STD_LOGIC_VECTOR(Z_tens) &
        STD_LOGIC_VECTOR(Z_ones);

    scan_proc : PROCESS(w_4MHz)
    BEGIN
        IF rising_edge(w_4MHz) THEN
            scan_cnt <= scan_cnt + 1;
            dig      <= STD_LOGIC_VECTOR(scan_cnt(11 DOWNTO 9));
        END IF;
    END PROCESS;

    -- feed accel into flight sim
    x_raw <= SIGNED(acl_dataX);
    y_raw <= SIGNED(acl_dataY);

    u_sim : ENTITY work.vga_flight_sim
        PORT MAP(
            clk       => CLK_100MHZ,
            x_raw     => x_raw,
            y_raw     => y_raw,
            x_pos_bin => x_pos_bin,
            y_pos_bin => y_pos_bin
        );

    -- VGA sync and draw
    u_sync : ENTITY work.vga_sync
        PORT MAP(
            pixel_clk => pix_clk,
            red_in    => r_draw,
            green_in  => g_draw,
            blue_in   => b_draw,
            red_out   => VGA_R,
            green_out => VGA_G,
            blue_out  => VGA_B,
            hsync     => VGA_HS,
            vsync     => VGA_VS,
            pixel_row => pixel_row,
            pixel_col => pixel_col
        );

    u_draw : ENTITY work.vga_draw
        PORT MAP(
            X_bin     => x_pos_bin,
            Y_bin     => y_pos_bin,
            pixel_row => pixel_row,
            pixel_col => pixel_col,

            ring_on   => ring_on_s,
            ring_x    => ring_x_s,
            ring_y    => ring_y_s,

            R         => r_draw,
            G         => g_draw,
            B         => b_draw
        );

     -- game logic: updates ring position and score on each game tick 
     u_path : entity work.vga_flight_path
        port map(
            clk   => CLK_100MHZ,
            rst   => '0',        
            tick  => game_tick,

            X_bin => x_pos_bin,
            Y_bin => y_pos_bin,

            ring_on => ring_on_s,
            ring_x  => ring_x_s,
            ring_y  => ring_y_s,

            collected_pulse => ring_hit,
            score           => ring_score
        );


END ARCHITECTURE;
