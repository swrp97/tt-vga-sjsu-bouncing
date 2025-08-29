/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * VGA demo with bitmap symbol overlay
 * Shows how to add a simple bitmap symbol to the flowing patterns
 */
`default_nettype none
module tt_um_sjsu(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);
  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  
  // TinyVGA PMOD https://github.com/mole99/tiny-vga
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  
  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;
  

 
  
  // Generate VGA signal, x and y coordinates
  wire [9:0] x;
  wire [9:0] y;
  wire video_active;  
  
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(x),
    .vpos(y)
  );

  // ===== BOUNCING SJSU BITMAP =====
  // Dynamic symbol position and velocity for bouncing effect
  reg [9:0] symbol_x;
  reg [9:0] symbol_y;
  reg vel_x;  // 1 = moving right, 0 = moving left
  reg vel_y;  // 1 = moving down, 0 = moving up
  reg [3:0] collision_counter;  // Increments on each collision for pattern switching
  
  // Screen boundaries (640x480 screen, 64x32 symbol - 2x bigger!)
  parameter MAX_X = 576;  // 640 - 64
  parameter MAX_Y = 448;  // 480 - 32
  
  // Update position once per frame (when x=0, y=0)
  always @(posedge clk,  negedge rst_n) begin
    if (~rst_n) begin
      symbol_x <= 10'd50;   // Start near top-left
      symbol_y <= 10'd50;
      vel_x <= 1'b1;        // Start moving right
      vel_y <= 1'b1;        // Start moving down
      collision_counter <= 4'b0;
    end else if (x == 0 && y == 0) begin
      // Update X position and handle horizontal bouncing
      if (vel_x) begin
        if (symbol_x >= MAX_X) begin
          symbol_x <= MAX_X;
          vel_x <= 1'b0;  // Bounce left
          collision_counter <= collision_counter + 1;  // Pattern change on collision!
        end else begin
          symbol_x <= symbol_x + 1;
        end
      end else begin
        if (symbol_x == 0) begin
          symbol_x <= 0;
          vel_x <= 1'b1;  // Bounce right
          collision_counter <= collision_counter + 1;  // Pattern change on collision!
        end else begin
          symbol_x <= symbol_x - 1;
        end
      end
      
      // Update Y position and handle vertical bouncing
      if (vel_y) begin
        if (symbol_y >= MAX_Y) begin
          symbol_y <= MAX_Y;
          vel_y <= 1'b0;  // Bounce up
          collision_counter <= collision_counter + 1;  // Pattern change on collision!
        end else begin
          symbol_y <= symbol_y + 1;
        end
      end else begin
        if (symbol_y == 0) begin
          symbol_y <= 0;
          vel_y <= 1'b1;  // Bounce down
          collision_counter <= collision_counter + 1;  // Pattern change on collision!
        end else begin
          symbol_y <= symbol_y - 1;
        end
      end
    end
  end
  
  // Check if current pixel is within symbol bounds (using dynamic position, 2x bigger)
  wire in_symbol_x = (x >= symbol_x) && (x < symbol_x + 64);
  wire in_symbol_y = (y >= symbol_y) && (y < symbol_y + 32);
  wire in_symbol = in_symbol_x && in_symbol_y;
  
  // Get the specific pixel from the bitmap (scale down by 2 for 2x bigger display)
  wire [3:0] symbol_row = (y[4:1] - symbol_y[4:1]);    // Row within symbol (0-15), scaled
  wire [4:0] symbol_col = (x[5:1] - symbol_x[5:1]);    // Column within symbol (0-31), scaled
  
  // Synthesizable SJSU bitmap lookup using case statement
  // Each letter is 8 pixels wide: S(0-7), J(8-15), S(16-23), U(24-31)
  reg [31:0] bitmap_row;
  always @(*) begin
    case (symbol_row)
      //                      S       J       S       U
      //                    ||||||||||||||||||||||||||||||||
      4'd0:  bitmap_row = 32'b01111110_01111110_01111110_11000011;
      4'd1:  bitmap_row = 32'b11111111_11111111_11111111_11000011;
      4'd2:  bitmap_row = 32'b11000000_00001100_11000000_11000011;
      4'd3:  bitmap_row = 32'b11000000_00001100_11000000_11000011;
      4'd4:  bitmap_row = 32'b01111100_00001100_01111100_11000011;
      4'd5:  bitmap_row = 32'b00111110_00001100_00111110_11000011;
      4'd6:  bitmap_row = 32'b00000011_00001100_00000011_11000011;
      4'd7:  bitmap_row = 32'b00000011_00001100_00000011_11000011;
      4'd8:  bitmap_row = 32'b10000011_00001100_10000011_11000011;
      4'd9:  bitmap_row = 32'b11000011_00001100_11000011_11000011;
      4'd10: bitmap_row = 32'b11000011_11001100_11000011_11000011;
      4'd11: bitmap_row = 32'b11111111_11111000_11111111_11000011;
      4'd12: bitmap_row = 32'b01111110_01111000_01111110_11000011;
      4'd13: bitmap_row = 32'b00000000_00000000_00000000_01111110;
      4'd14: bitmap_row = 32'b00000000_00000000_00000000_00000000;
      4'd15: bitmap_row = 32'b00000000_00000000_00000000_00000000;
    endcase
  end
  
  wire symbol_pixel = bitmap_row[31 - symbol_col];  // Get pixel (MSB is leftmost)
  
  // ===== BACKGROUND PATTERNS (your original code) =====
  reg [15:0] frame_counter;
  always @(posedge clk,  negedge rst_n) begin
    if (~rst_n) begin
      frame_counter <= 0;
    end else begin
      if (x == 0 && y == 0) begin
        frame_counter <= frame_counter + 1;
      end
    end
  end
  
  // Simple artistic patterns with moderate speed
  wire [7:0] time_slow = frame_counter[9:2];   // A bit faster
  wire [7:0] time_med = frame_counter[7:0];    // More noticeable movement
  
  // Simple flowing patterns
  wire [7:0] pattern1 = x[7:0] + y[7:0] + time_slow;
  wire [7:0] pattern2 = x[7:0] ^ y[7:0] ^ time_med;
  wire [7:0] pattern3 = (x[6:0] + time_slow) ^ (y[6:0] - time_slow);
  
  // Scene selection - changes on each collision!
  wire [1:0] scene = collision_counter[1:0];  // Use collision counter instead of time
  
  wire [7:0] output_pattern;
  assign output_pattern = 
    (scene == 2'b00) ? pattern1 :
    (scene == 2'b01) ? pattern2 :
    (scene == 2'b10) ? pattern3 :
                       pattern1 ^ pattern2;
  
  
  wire unused_ok = &{ena, ui_in[7:1], uio_in, output_pattern[6:0]};  
  // ===== COLOR INVERSION CONTROL =====
  wire invert_colors = ui_in[0];  // First input pin controls color inversion
  
  // Background color selection with inversion
  wire use_gold_bg = output_pattern[7] ^ invert_colors;  // XOR with invert signal
  wire [5:0] background_color = use_gold_bg ? 6'b11_10_00 :     // SJSU Gold
                                             6'b00_01_11;       // SJSU Navy Blue
  
  // ===== FINAL COLOR OUTPUT WITH BLACK BORDER =====
  // Check for border pixels (adjacent to letter pixels)
  wire [3:0] check_row_up = (symbol_row > 0) ? (symbol_row - 1) : symbol_row;
  wire [3:0] check_row_down = (symbol_row < 15) ? (symbol_row + 1) : symbol_row;
  wire [4:0] check_col_left = (symbol_col > 0) ? (symbol_col - 1) : symbol_col;
  wire [4:0] check_col_right = (symbol_col < 31) ? (symbol_col + 1) : symbol_col;
  
  // Sample bitmap at adjacent positions for border detection
  reg [31:0] check_bitmap_row_up, check_bitmap_row_down, check_bitmap_row_current;
  always @(*) begin
    // Current row
    case (symbol_row)
      4'd0:  check_bitmap_row_current = 32'b01111110_01111110_01111110_11000011;
      4'd1:  check_bitmap_row_current = 32'b11111111_11111111_11111111_11000011;
      4'd2:  check_bitmap_row_current = 32'b11000000_00001100_11000000_11000011;
      4'd3:  check_bitmap_row_current = 32'b11000000_00001100_11000000_11000011;
      4'd4:  check_bitmap_row_current = 32'b01111100_00001100_01111100_11000011;
      4'd5:  check_bitmap_row_current = 32'b00111110_00001100_00111110_11000011;
      4'd6:  check_bitmap_row_current = 32'b00000011_00001100_00000011_11000011;
      4'd7:  check_bitmap_row_current = 32'b00000011_00001100_00000011_11000011;
      4'd8:  check_bitmap_row_current = 32'b10000011_00001100_10000011_11000011;
      4'd9:  check_bitmap_row_current = 32'b11000011_00001100_11000011_11000011;
      4'd10: check_bitmap_row_current = 32'b11000011_11001100_11000011_11000011;
      4'd11: check_bitmap_row_current = 32'b11111111_11111000_11111111_11000011;
      4'd12: check_bitmap_row_current = 32'b01111110_01111000_01111110_11000011;
      4'd13: check_bitmap_row_current = 32'b00000000_00000000_00000000_01111110;
      4'd14: check_bitmap_row_current = 32'b00000000_00000000_00000000_00000000;
      4'd15: check_bitmap_row_current = 32'b00000000_00000000_00000000_00000000;
    endcase
    
    // Row above
    case (check_row_up)
      4'd0:  check_bitmap_row_up = 32'b01111110_01111110_01111110_11000011;
      4'd1:  check_bitmap_row_up = 32'b11111111_11111111_11111111_11000011;
      4'd2:  check_bitmap_row_up = 32'b11000000_00001100_11000000_11000011;
      4'd3:  check_bitmap_row_up = 32'b11000000_00001100_11000000_11000011;
      4'd4:  check_bitmap_row_up = 32'b01111100_00001100_01111100_11000011;
      4'd5:  check_bitmap_row_up = 32'b00111110_00001100_00111110_11000011;
      4'd6:  check_bitmap_row_up = 32'b00000011_00001100_00000011_11000011;
      4'd7:  check_bitmap_row_up = 32'b00000011_00001100_00000011_11000011;
      4'd8:  check_bitmap_row_up = 32'b10000011_00001100_10000011_11000011;
      4'd9:  check_bitmap_row_up = 32'b11000011_00001100_11000011_11000011;
      4'd10: check_bitmap_row_up = 32'b11000011_11001100_11000011_11000011;
      4'd11: check_bitmap_row_up = 32'b11111111_11111000_11111111_11000011;
      4'd12: check_bitmap_row_up = 32'b01111110_01111000_01111110_11000011;
      4'd13: check_bitmap_row_up = 32'b00000000_00000000_00000000_01111110;
      4'd14: check_bitmap_row_up = 32'b00000000_00000000_00000000_00000000;
      4'd15: check_bitmap_row_up = 32'b00000000_00000000_00000000_00000000;
    endcase
    
    // Row below  
    case (check_row_down)
      4'd0:  check_bitmap_row_down = 32'b01111110_01111110_01111110_11000011;
      4'd1:  check_bitmap_row_down = 32'b11111111_11111111_11111111_11000011;
      4'd2:  check_bitmap_row_down = 32'b11000000_00001100_11000000_11000011;
      4'd3:  check_bitmap_row_down = 32'b11000000_00001100_11000000_11000011;
      4'd4:  check_bitmap_row_down = 32'b01111100_00001100_01111100_11000011;
      4'd5:  check_bitmap_row_down = 32'b00111110_00001100_00111110_11000011;
      4'd6:  check_bitmap_row_down = 32'b00000011_00001100_00000011_11000011;
      4'd7:  check_bitmap_row_down = 32'b00000011_00001100_00000011_11000011;
      4'd8:  check_bitmap_row_down = 32'b10000011_00001100_10000011_11000011;
      4'd9:  check_bitmap_row_down = 32'b11000011_00001100_11000011_11000011;
      4'd10: check_bitmap_row_down = 32'b11000011_11001100_11000011_11000011;
      4'd11: check_bitmap_row_down = 32'b11111111_11111000_11111111_11000011;
      4'd12: check_bitmap_row_down = 32'b01111110_01111000_01111110_11000011;
      4'd13: check_bitmap_row_down = 32'b00000000_00000000_00000000_01111110;
      4'd14: check_bitmap_row_down = 32'b00000000_00000000_00000000_00000000;
      4'd15: check_bitmap_row_down = 32'b00000000_00000000_00000000_00000000;
    endcase
  end
  
  // Check adjacent pixels for border detection
  wire pixel_up = check_bitmap_row_up[31 - symbol_col];
  wire pixel_down = check_bitmap_row_down[31 - symbol_col];
  wire pixel_left = (symbol_col > 0) ? check_bitmap_row_current[31 - check_col_left] : 1'b0;
  wire pixel_right = (symbol_col < 31) ? check_bitmap_row_current[31 - check_col_right] : 1'b0;
  
  // Border detection: not a letter pixel but adjacent to one
  wire is_border = ~symbol_pixel && (pixel_up || pixel_down || pixel_left || pixel_right);
  
  // SJSU letter colors with inversion: S=Blue, J=Gold, S=Blue, U=Gold
  wire [1:0] letter_index = symbol_col[4:3];  // Which letter (0=S, 1=J, 2=S, 3=U)
  wire letter_is_S = (letter_index == 2'b00) || (letter_index == 2'b10);  // S letters
  wire use_blue_letter = letter_is_S ^ invert_colors;  // XOR with invert signal  
  wire [5:0] sjsu_letter_color = use_blue_letter ? 6'b00_01_11 :      // SJSU Navy Blue
                                                   6'b11_10_00;       // SJSU Gold
  
  assign {R,G,B} =
    (~video_active) ? 6'b00_00_00 :                    // Black during blanking
    (in_symbol && is_border) ? 6'b00_00_00 :           // Black border around letters
    (in_symbol && symbol_pixel) ? sjsu_letter_color :  // Blue and Gold letters (with inversion)
    background_color;                                   // Background pattern (with inversion)

endmodule
