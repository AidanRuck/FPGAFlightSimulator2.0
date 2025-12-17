# FPGA Flight Simulator 2.0
*CPE 487 - Digital System Design*

Made by Nicholas Scirocco and Aidan Ruck

---

## Overview
Flight Simulator 2.0 expands upon the original servo-based design into a full VGA-rendered, hardware-only flight 'game' with smoothed motion, collision detection, and scoring. This project is an extension of the original [FPGA-based accelerometer interface and feedback control system](https://github.com/alionaheitz/CPE487Project), and represents a full hardware-only fight simulation implemented on the Nexys A7-100T. Using the onboard ADXL362 3-axis accelerometer, real-time tilt data is sampled, filtered, quantized, and finally translated into smooth motion rendered through the VGA display. Elements such as the targets (blue circles), collision detection, and scoring are all implemented directly in VHDL.

Compared to the original version, Flight Simulator 2.0 introduces:
- Smoothed and quantized accelerometer control
- VGA-based aircraft visualization
- Discrete movement bins instead of raw sensor values
- Game logic such as targets, collisions, and scoring
- Multiple clock domains for stability and realism

*insert visualization

---

## Demo:
- Board: Nexys A7-100T
- Input: Onboard ADXL362 Accelerometer
- Output: VGA display (640x480 at 60 Hz)
- Controls: Board tilt and onboard switches
- Scoring: LED[15:0]

*insert gif

---

## System Features
- Real-time accelerometer input via SPI
- Noise-resistant motion using quantized movement bins
- Smooth aircraft motion using clock-divided updates
- VGA graphics at 640x480 resolution
- Hardware-based pseudo-random target generation (LFSR)
- Collision detection and score tracking
- Debug visualization via LEDs and 7-segment display

---

## System Architecture
The system is fully synchronout to the 100 MHz FPGA clock, but internally divided into multiple functional time domains.
1. Sensor and Control Domain - Reads and processes accelerometer data
2. Movement Update Domain - Controls aircraft movement speed
3. Game Logic Domain (60 Hz) - Handles scoring and target updates
4. VGA Rendering Domain (~60 Hz) - Continuously redraws the screen

---

## How to Run
1. Open project files in Vivado
2. Select Nexys A7-100T board
3. Run Synthesis, then Implementation, then Generate Bitstream
4. Connect a VGA display and power to the board
5. Program FPGA via Hardware Manager

---

## File Hierarchy 
- top.vhd - Top-level module integrating all subsystems
- spi_master.vhd - SPI FSM for ADXL362 communication
- vga_flight_sim.vhd - Aircraft motion control and smoothing logic
- vga_flight_path.vhd - Game logic (targets, collisions, and scoring)
- vga_sync.vhd - VGA timing generator (640x480 at 60 Hz)
- vga_draw.vhd - Combinational VGA rendering logic
- leddec16.vhd - 7segment display multiplexing
- constraints.xdc - Pin mappings for VGA, switches, LEDs, and SPI

---

## Sensor Input (ADXL362 via SPI)
- Communicates with the onboard ADXL362 using SPI (Mode 0)
- SPI clock is derived from the 100 MHz system clock
- Burst reads retrieve the signed X, Y, and Z values
- Outputs:
  - acl_dataALL - Packed data for display and debug
  - acl_x, acl_y, acl_z - Signed axis values for control
 
The accelerometer provides high-resolution data, which we intentionally do *not* use for motion to avoid jitter.

---

## Input Smoothing and Quantization
Rather than using the raw values from the accelerometer, our ssytem:
- Applies thresholding to each axis
- Converts tilt into dicrete steps (-1, 0, and +1)
- Stores aircraft position in bounded bins (-8 to +8)
- Saturates movement to prevent wraparound

This is done to filter noise, stabilize the motion, and further simplify hardware logic.

---

## Aircraft Movement Control (vga_flight_sim.vhd)

- Uses a movement clock divider (`move_div`) to slow motion relative to 100 Mhz
- Position updates only occur when `move_div == MOVE_MAX`
- Converts the quantized tilt into incremental X/Y positional steps
- Outputs the aircraft position bins to the VGA renderer

This combines to produce a smooth, visible motion without jitter or speed far exceeding expected steps.

---

## Game Timing (60 Hz Tick)
A dedicated game tick is generated within `top.vhd`
- `TICK_MAX = 1666666` (100 Mhz / 60)
Which produces a single-cycle tick pulse for the game logic only, not for rendering or movement.

---

## Game Logic (vga_flight_path.vhd)
This runs exclusively on `game_tick` and handles:
- Target positioning
- Collision detection
- Score tracking

### Target Generation
- Uses a Linear Feedback Shift Register (LFSR)
- Starts from a fixed seed
- Advances on each successful collision
- Produces deterministic, pseudo-random positions

### Collision Detection
- Compares aircraft X / Y bins with target X / Y bins
- Detects overlap within a defined region
- Generates a `ring_hit` pulse on collision

On collision:
1. Score register increments
2. LFSR advances
3. Target position updates

---

## VGA Rendering

### VGA Timing (vga_sync.vhd)
- 640x480 resolution
- 25 Mhz pixel clock derived from 100 Mhz
- Generates HSYNC and VSYNC signals

### Drawing Logic (vga_draw.vhd)
- Purely combinational
- Draws:
  - Aircraft
  - Target Ring
- Uses current position bins and target registers

Rendering runs continuously and independently of game logic.

---

## Debug and User Controls
- 7-segment display:
  - SW[1:0] selects the X, Y, or Z axis
  - Accelerometer data is binned and converted to BCD
  - Multiplexed using `leddec16`
- LED[15:0]
  - Displays current score directly from the hardware register

These outputs are used strictly for visualization and debugging.

---
## Key Design Decisions

### Why Quantize Accelerometer Data?
Raw accelerometer data is incredibly noisy and constantly changing. Through quantization we can:
- Filter noise
- Prevent jitter
- Produce more predictable movement
- Simplify hardware Logic

### Why Separate Clock Domains?
All of the different clocks run at rates that are appropriate for their functions. This helps reduce screen taering and visual artifacting, which lead to unstable simulation.

---

## Results
- Smooth aircraft motion with no visible jitter
- Stable VGA output at 60 Hz
- Reliable collision detection and scoring
- Fully hardware-driven simulation with no outside software

---

## Known Limitations
- Aircraft motion uses discrete bins rather than continuous velocity
- Only planar (X / Y) motion is implemented (No Z-axis)
- Graphics are intentionaly minimal to prioritize timing correctness

---

## Future Improvements
- Implement velocity-based movement instead of fixed steps
- Add a Z-axis visualizer
- Add a visual representation of pitching and rolling on the aircraft
- Implement difficulty scaling with time
- Add multiple targets or obstacles
  - Change from blue circular targets to obstacles in flight path to avoid
- Display score on through VGA instead of the onboard LEDs

---

## Conclusion
FPGA Flight Simulator 2.0 successfully transforms raw sensor input into a stable, interactive hardware-based 'game.' ...

---

## Resources
- SPI / ADXL362/ NexysA7 logic [Youtube video](https://www.youtube.com/watch?v=7b3YwQWwvXM)
  - This was used by the previous group
- [ADXL362 Datasheet](adxl362.pdf)
- [Nexys A7 Reference Manual](https://digilent.com/reference/programmable-logic/nexys-a7/reference-manual)

---
---
---
---
This is all of the previous group's work, not yet deleted such that we may continue to add to our report.
## Getting Started
- The system takes input from the onboard ADXL362 3-axis accelerometer and the default 100 MHz clock signal. 
   -  Clock division was handled by a custom clk_gen.vhd module that divides the 100 MHz input clock down to 4 MHz using a simple counter-based divider.
   - SPI communication was implemented in spi_master.vhd via a hand-coded 92-state FSM, controlling every SPI timing signal (SCLK, MOSI, SS) and reading all 6 bytes (2 bytes per axis) using burst mode. No IP blocks were used for SPI, the FSM transitions were manually optimized for state latency and edge alignment with SCLK.
   - Each physical input/output was mapped using the .xdc file by matching get_ports constraints to pin numbers from the diligent master XDC.
   - Initial testing was done incrementally. The SPI state machine was validated by assigning output registers (acl_dataX) directly to LEDs for binary visualization.
   - Later, display multiplexing and logic were added in leddec16.vhd, and seven-segment digits were verified through the bcd32 packaging. The project was synthesized, implemented, and the bitstream was uploaded using Vivado Hardware Manager, with hardware testing performed live on the board using physical switch flips, servo response, and live LED.
- VHDL code was written from scratch, starting with research into SPI communication and the ADXL362 sensor's functionality. Found a helpful [Youtube video](https://www.youtube.com/watch?v=7b3YwQWwvXM) which provided insight into interfacing the ADXL362 with the Nexys A7. Core components like FSMs, clock division, LED control, and 7-segment display logic were implemented using skills learned in the course. Additional research was conducted to understand how to generate PWM signals for servo motor control.

---------
## Implementation

### Data Collection (spi_master)
- Communicates with ADXL362 via SPI Mode 0 at 1 MHz clock
- Performs burst reads: 2 bytes per axis (X, Y, Z), totaling 6 bytes
- Implements a 92‑state FSM to configure and read sensor data
- Output data rates is 100 Hz with an acceleration range of ±2g

 ![Alt text](FSM.png)


### Data Display
- **7‑Segment Display (leddec16)**
  - Converts each 5 bit axis value into two BCD digits via division/modulo.
  - Packs eight nibbles into a 32‑bit vector and time‑multiplexes across digits.
- **LED Array**
  - SW[2:0] chooses which axis to show: "001"→X, "010"→Y, "100"→Z.
  - Lights each LED bit high/low according to the raw binary data.

### Servo Control (controller)
- Compares X‑axis acceleration against ±threshold to decide left/center/right.
- Smoothly generates a PWM duty cycle corresponding to 1 ms, 1.5 ms, or 2 ms pulses at 50 Hz.
- Outputs `PWM_OUT` for hobby servo actuation.

---------
## Results
![servo.gif](v1-ezgif.com-optimize.gif)
- Servo motor responds to X-axis tilt by adjusting its position via PWM signal
  
![led.gif](v2-ezgif.com-optimize.gif)
- 16 onboard LEDs display X-axis data in binary; gradual rotation increases or decreases the LED pattern accordingly

![servo.gif](v3-ezgif.com-optimize.gif)
![servo.gif](v4-ezgif.com-optimize.gif)
- 7-segment display shows real-time X, Y, and Z accelerometer values, with visible shifts toward minimum or maximum values as the board is rotated
  







