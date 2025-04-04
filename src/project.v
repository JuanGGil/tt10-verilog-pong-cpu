`default_nettype none
`timescale 1us / 1ns

// this module is responsible for vsync and hsync timings for VGA signal. This is set to assume that the clock speed is 100MHz,
// which is then converted into a 25MHz signal for VGA use.

// adapted from https://embeddedthoughts.com/2016/07/29/driving-a-vga-monitor-using-an-fpga/
module vga_sync
	(
		input wire clk, rst_n,
		output wire hsync, vsync, video_on, p_tick,
		output wire [9:0] x, y
	);
	
	// constant declarations for VGA sync parameters
	localparam H_DISPLAY       = 640; // horizontal display area
	localparam H_L_BORDER      =  48; // horizontal left border
	localparam H_R_BORDER      =  16; // horizontal right border
	localparam H_RETRACE       =  96; // horizontal retrace
	localparam H_MAX           = H_DISPLAY + H_L_BORDER + H_R_BORDER + H_RETRACE - 1;
	localparam START_H_RETRACE = H_DISPLAY + H_R_BORDER;
	localparam END_H_RETRACE   = H_DISPLAY + H_R_BORDER + H_RETRACE - 1;
	
	localparam V_DISPLAY       = 480; // vertical display area
	localparam V_T_BORDER      =  10; // vertical top border
	localparam V_B_BORDER      =  33; // vertical bottom border
	localparam V_RETRACE       =   2; // vertical retrace
	localparam V_MAX           = V_DISPLAY + V_T_BORDER + V_B_BORDER + V_RETRACE - 1;
    localparam START_V_RETRACE = V_DISPLAY + V_B_BORDER;
	localparam END_V_RETRACE   = V_DISPLAY + V_B_BORDER + V_RETRACE - 1;
	
	// mod-4 counter to generate 25 MHz pixel tick
	reg [1:0] pixel_reg;
	wire [1:0] pixel_next;
	wire pixel_tick;
	
	always @(posedge clk, posedge rst_n)
        if(!rst_n)
		  pixel_reg <= 0;
		else
		  pixel_reg <= pixel_next;
	
	assign pixel_next = pixel_reg + 1; // increment pixel_reg 
	
	assign pixel_tick = (pixel_reg == 0); // assert tick 1/4 of the time
	
	// registers to keep track of current pixel location
	reg [9:0] h_count_reg, h_count_next, v_count_reg, v_count_next;
	
	// register to keep track of vsync and hsync signal states
	reg vsync_reg, hsync_reg;
	wire vsync_next, hsync_next;
 
	// infer registers
    always @(posedge clk, negedge rst_n)
        if(!rst_n)
		    begin
                    v_count_reg <= 0;
                    h_count_reg <= 0;
                    vsync_reg   <= 0;
                    hsync_reg   <= 0;
		    end
		else
		    begin
                    v_count_reg <= v_count_next;
                    h_count_reg <= h_count_next;
                    vsync_reg   <= vsync_next;
                    hsync_reg   <= hsync_next;
		    end
			
	// next-state logic of horizontal vertical sync counters
	always @*
		begin
		h_count_next = pixel_tick ? 
		               h_count_reg == H_MAX ? 0 : h_count_reg + 1
			       : h_count_reg;
		
		v_count_next = pixel_tick && h_count_reg == H_MAX ? 
		               (v_count_reg == V_MAX ? 0 : v_count_reg + 1) 
			       : v_count_reg;
		end
		
        // hsync and vsync are active low signals
        // hsync signal asserted during horizontal retrace
        assign hsync_next = h_count_reg >= START_H_RETRACE
                            && h_count_reg <= END_H_RETRACE;
   
        // vsync signal asserted during vertical retrace
        assign vsync_next = v_count_reg >= START_V_RETRACE 
                            && v_count_reg <= END_V_RETRACE;

        // video only on when pixels are in both horizontal and vertical display region
        assign video_on = (h_count_reg < H_DISPLAY) 
                          && (v_count_reg < V_DISPLAY);

        // output signals
        assign hsync  = hsync_reg;
        assign vsync  = vsync_reg;
        assign x      = h_count_reg;
        assign y      = v_count_reg;
        assign p_tick = pixel_tick;
endmodule

module tt_um_PongGame (
    input  wire [7:0] ui_in,    // The value could be zero or one, indicating up or down movement, or something similar
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in, rst_n, 1'b0};
    
    // Features to add:
    // maybe a winning or losing animation
    // maybe more color?
    // ball speed varies with game score
    // paddle size varies with game score
    	
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter BALL_SIZE = 3;
    parameter PADDLE_WIDTH = 3;
    parameter PADDLE_HEIGHT = 40;
    parameter BALL_SPEED = 6; // ORIGINALLY 2
    parameter PADDLE_SPEED = 10;
    parameter OPP_PADDLE_X_POS = 30;
    parameter PLAYER_PADDLE_X_POS = 610;
    parameter MIDDLE_LINE_WIDTH = 8;
    parameter SUPER_PIXEL_SIZE = 10;
	
    reg [6:0] rgb_reg;
	
	// registers for current rendered pixels
	wire [9:0] rendered_x;
	wire [9:0] rendered_y;
	
	// Ball position
    reg [9:0] ball_x = 320;
    reg [9:0] ball_y = 240; // 10-bit positions for the ball (up to 640 for x and 480 for y)

    // Paddle position
    reg [9:0] paddle_y = SCREEN_HEIGHT / 2; // 10-bit position for the paddle (up to 480 for y)

    // Opponent Paddle position
    reg [9:0] op_paddle_y = SCREEN_HEIGHT / 2; // 10-bit position for the opposing paddle (up to 480 for y)

	// Ball direction
    reg ball_dir_x = 0; // 1 for right, 0 for left
    reg ball_dir_y = 1; // 1 for down, 0 for up

    // Game Score
    reg [7:0] game_score = 0; // 8'bxxxx0000 is opp score, 8'b0000xxxx is player score
    
	reg [5:0] clk_div = 0;
    
    // Ball movement
    always @(posedge clk_div[0]) begin
        if (!rst_n) begin
            ball_x <= SCREEN_WIDTH / 2;
            ball_y <= SCREEN_HEIGHT / 2;
        end else if ( (rst_n) && ball_dir_x == 1 && ball_dir_y == 1) begin
            // Update ball position
            ball_x <= ball_x + BALL_SPEED; 
            ball_y <= ball_y + BALL_SPEED;
        end else if ( (rst_n) && ball_dir_x == 0 && ball_dir_y == 1) begin
            ball_x <= ball_x - BALL_SPEED; 
            ball_y <= ball_y + BALL_SPEED; 
        end else if ((rst_n) && ball_dir_x == 1 && ball_dir_y == 0) begin
            ball_x <= ball_x + BALL_SPEED; 
            ball_y <= ball_y - BALL_SPEED;  
        end else if ((rst_n) && ball_dir_x == 0 && ball_dir_y == 0) begin
            ball_x <= ball_x - BALL_SPEED; 
            ball_y <= ball_y - BALL_SPEED; 
        end
        
        if (ball_y <= 20) begin
			ball_dir_y <= 1;
		end else if ((ball_y+BALL_SIZE) >= SCREEN_HEIGHT) begin
			ball_dir_y <= 0;
		end
	
        if (((ball_x - BALL_SIZE) <= (OPP_PADDLE_X_POS)) && ((ball_y + BALL_SIZE) >= (op_paddle_y - PADDLE_HEIGHT)) && (ball_y <= (op_paddle_y + PADDLE_HEIGHT))) begin
			// ball collides with opponent's paddle
			ball_dir_x <= 1;
		end else if (((ball_x) >= (PLAYER_PADDLE_X_POS - PADDLE_WIDTH)) && ((ball_y + BALL_SIZE) >= (paddle_y - PADDLE_HEIGHT)) && (ball_y <= (paddle_y + PADDLE_HEIGHT))) begin
			// ball collides with player's paddle
			ball_dir_x <= 0;
        end
        if (ball_x <= 3) begin
            // ball collides with opponent's wall (+1 score to player) // NEED TO IMPLEMENT A DELAY WHERE BALL RESPAWNS

            game_score <= game_score + 1; // NEED TO IMPLEMENT A CHECK IF THE PLAYER HAS WON (+9 score)
			if(game_score%16 == 9) begin
				game_score <= 0;
			end
            ball_x <= SCREEN_WIDTH / 2;
            ball_y <= SCREEN_HEIGHT / 2;
            ball_dir_x = 0;
            
        end else if (ball_x >= SCREEN_WIDTH) begin
            // ball collides with player's wall (+1 score to opponent) // NEED TO IMPLEMENT A DELAY WHERE BALL RESPAWNS
            game_score <= game_score + 16; // NEED TO IMPLEMENT A CHECK IF THE OPPONENT HAS WON (+9 score)
			if(game_score > 144) begin
				game_score <= 0;
			end
            ball_x <= SCREEN_WIDTH / 2;
            ball_y <= SCREEN_HEIGHT / 2; 
            ball_dir_x = 0;
        end
    end
    
    // Paddle movement
    reg btn_up = 0;
    reg btn_down = 0;
    
    always @(ui_in) begin
        if (ui_in[0] == 1) begin // Assuming `ui_in[0]` for up, and `ui_in[1]` for down
            btn_up = 1;
            btn_down = 0;
        end else if (ui_in[1] == 1) begin
            btn_up = 0;
            btn_down = 1;
        end else begin
            btn_up = 0;
            btn_down = 0;
        end
    end
    
    
    // NEED FIX HERE, PADDLE DISAPPEARS AT THE TOP OF THE SCREEN
     always @(posedge clk_div[2]) begin
         if (!rst_n) begin
            op_paddle_y <= (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
        end else begin
            // this is for upper bound of the screen
            if (ball_y > op_paddle_y) begin
            	if ((op_paddle_y+PADDLE_SPEED+PADDLE_HEIGHT) > SCREEN_HEIGHT)
            		op_paddle_y <= SCREEN_HEIGHT-PADDLE_HEIGHT;
            	else
                	op_paddle_y <= op_paddle_y + PADDLE_SPEED;
                
            // this is for lower bound of screen
            end else if (ball_y < op_paddle_y) begin
                if ((op_paddle_y-PADDLE_SPEED-PADDLE_HEIGHT) <= 0)
            		op_paddle_y <= 40;
            	else
                	op_paddle_y <= op_paddle_y - PADDLE_SPEED;
            end
        end
    end
    
    always @(posedge clk_div[1]) begin
        if (!rst_n) begin
                paddle_y <= (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
            end else begin
                // Move paddle up, check lower bound
                if (btn_up && (paddle_y < SCREEN_HEIGHT - 20)) begin
                    if ((paddle_y+PADDLE_SPEED+PADDLE_HEIGHT) > SCREEN_HEIGHT)
                        paddle_y <= SCREEN_HEIGHT-PADDLE_HEIGHT;
                    else
                        paddle_y <= paddle_y + PADDLE_SPEED;
                end else if (btn_down && (paddle_y > 8)) begin
                   if ((paddle_y-PADDLE_SPEED-PADDLE_HEIGHT) < 0)
                        paddle_y <= PADDLE_HEIGHT;
                    else
                	paddle_y <= paddle_y - PADDLE_SPEED;
                end
            end
    end
    
    	// video status output from vga_sync to tell when to route out rgb signal to DAC
	wire video_on;
	wire pix_clk;
	reg hsync = 0;
	reg vsync = 0;

        // instantiate vga_sync
    vga_sync vga_sync_unit (.clk(clk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync),
                                .video_on(video_on), .p_tick(pix_clk), .x(rendered_x), .y(rendered_y));
   
    
    always @(posedge pix_clk) begin
        // logic for rendering one video line (currently rendering only for paddles and ball)
        if (video_on) begin

    // Render Opponent Score
    
    // make a 3x5 super pixel grid which, depending on the current score, changes the rendering to match the number
    // 1 super pixel = 10x10 pixels

    // Opp Super Pixel[0][0] : {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered
    if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 && rendered_y < 83)
        rgb_reg <= 6'b111111; // display a white super pixel

    // Opp Super Pixel[1][0]: {0,1,2,3,5,6,7,8,9} rendered, {4} not rendered
    else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE && rendered_y > 72 && rendered_y < 83 &&
             ~((game_score & 8'b11110000) == 8'b01000000))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[2][0]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
    else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 && rendered_y < 83 &&
             ~((game_score & 8'b11110000) == 8'b00010000))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[0][1]: {0,4,5,6,8,9} rendered, {1,2,3,7} not rendered
    else if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE &&
             ~(((game_score & 8'b11110000) == 8'b00010000) ||
               ((game_score & 8'b11110000) == 8'b00100000) ||
               ((game_score & 8'b11110000) == 8'b00110000) ||
               ((game_score & 8'b11110000) == 8'b01110000)))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[1][1]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
    else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE &&
             ((game_score & 8'b11110000) == 8'b00010000))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[2][1]: {0,2,3,4,7,8,9} rendered, {1,5,6} not rendered
    else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE &&
             ~(((game_score & 8'b11110000) == 8'b00010000) ||
               ((game_score & 8'b11110000) == 8'b01010000) ||
               ((game_score & 8'b11110000) == 8'b01100000)))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[0][2]: {0,2,3,4,5,6,8,9} rendered, {1,7} not rendered
    else if (rendered_x > 158 && rendered_x < 169 &&
             rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b11110000) == 8'b00010000) ||
               ((game_score & 8'b11110000) == 8'b01110000)))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[1][2]: {1,2,3,4,5,6,7,8,9} rendered, {0} not rendered
    else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) &&
             ~((game_score & 8'b11110000) == 8'b00000000))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[2][2]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
    else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) &&
             ~((game_score & 8'b11110000) == 8'b00010000))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[0][3]: {0,2,6,8} rendered, {1,3,4,5,7,9} not rendered
    else if ((rendered_x > 158 && rendered_x < 169 &&
              rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE)) &&
             ( ((game_score & 8'b11110000) == 8'b00000000) ||
               ((game_score & 8'b11110000) == 8'b00100000) ||
               ((game_score & 8'b11110000) == 8'b01100000) ||
               ((game_score & 8'b11110000) == 8'b10000000) ))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[1][3]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
    else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) &&
             ((game_score & 8'b11110000) == 8'b00010000))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[2][3]: {0,3,4,5,6,7,8,9} rendered, {1,2} not rendered
    else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b11110000) == 8'b00010000) ||
               ((game_score & 8'b11110000) == 8'b00100000)))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[0][4]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
    else if (rendered_x > 158 && rendered_x < 169 &&
             rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b11110000) == 8'b01000000) ||
               ((game_score & 8'b11110000) == 8'b01110000) ||
               ((game_score & 8'b11110000) == 8'b10010000)))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[1][4]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
    else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b11110000) == 8'b01000000) ||
               ((game_score & 8'b11110000) == 8'b01110000) ||
               ((game_score & 8'b11110000) == 8'b10010000)))
        rgb_reg <= 6'b111111;

    // Opp Super Pixel[2][4]: {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered 
    else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE))
        rgb_reg <= 6'b111111;

    // Render Player Score

    // make a 3x5 super pixel grid which, depending on the current score, changes the rendering to match the number
    // 1 super pixel = 10x10 pixels

    // Player Super Pixel[0][0] : {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered
    else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 && rendered_y < 83)
        rgb_reg <= 6'b111111;

    // Player Super Pixel[1][0]: {0,1,2,3,5,6,7,8,9} rendered, {4} not rendered
    else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE && rendered_y > 72 && rendered_y < 83 &&
             ~((game_score & 8'b00001111) == 8'b00000100))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[2][0]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
    else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 && rendered_y < 83 &&
             ~((game_score & 8'b00001111) == 8'b00000001))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[0][1]: {0,4,5,6,8,9} rendered, {1,2,3,7} not rendered
    else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE &&
             ~(((game_score & 8'b00001111) == 8'b00000001) ||
               ((game_score & 8'b00001111) == 8'b00000010) ||
               ((game_score & 8'b00001111) == 8'b00000011) ||
               ((game_score & 8'b00001111) == 8'b00000111)))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[1][1]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
    else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE &&
             ((game_score & 8'b00001111) == 8'b00000001))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[2][1]: {0,2,3,4,7,8,9} rendered, {1,5,6} not rendered
    else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE &&
             ~(((game_score & 8'b00001111) == 8'b00000001) ||
               ((game_score & 8'b00001111) == 8'b00000101) ||
               ((game_score & 8'b00001111) == 8'b00000110)))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[0][2]: {0,2,3,4,5,6,8,9} rendered, {1,7} not rendered
    else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b00001111) == 8'b00000001) ||
               ((game_score & 8'b00001111) == 8'b00000111)))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[1][2]: {1,2,3,4,5,6,7,8,9} rendered, {0} not rendered
    else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) &&
             ~((game_score & 8'b00001111) == 8'b00000000))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[2][2]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
    else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) &&
             ~((game_score & 8'b00001111) == 8'b00000001))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[0][3]: {0,2,6,8} rendered, {1,3,4,5,7,9} not rendered
    else if ((rendered_x > 478 && rendered_x < 489 &&
              rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE)) &&
             ( ((game_score & 8'b00001111) == 8'b00000000) ||
               ((game_score & 8'b00001111) == 8'b00000010) ||
               ((game_score & 8'b00001111) == 8'b00000110) ||
               ((game_score & 8'b00001111) == 8'b00001000) ))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[1][3]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
    else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) &&
             ((game_score & 8'b00001111) == 8'b00000001))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[2][3]: {0,3,4,5,6,7,8,9} rendered, {1,2} not rendered
    else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b00001111) == 8'b00000001) ||
               ((game_score & 8'b00001111) == 8'b00000010)))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[0][4]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
    else if (rendered_x > 478 && rendered_x < 489 &&
             rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b00001111) == 8'b00000100) ||
               ((game_score & 8'b00001111) == 8'b00000111) ||
               ((game_score & 8'b00001111) == 8'b00001001)))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[1][4]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
    else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE &&
             rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) &&
             ~(((game_score & 8'b00001111) == 8'b00000100) ||
               ((game_score & 8'b00001111) == 8'b00000111) ||
               ((game_score & 8'b00001111) == 8'b00001001)))
        rgb_reg <= 6'b111111;

    // Player Super Pixel[2][4]: {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered 
    else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) &&
             rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE))
        rgb_reg <= 6'b111111;

    // Opponent paddle render logic
    else if (rendered_x >= (OPP_PADDLE_X_POS - PADDLE_WIDTH) && rendered_x <= (OPP_PADDLE_X_POS + PADDLE_WIDTH) &&
             rendered_y >= (op_paddle_y - PADDLE_HEIGHT) && rendered_y <= (op_paddle_y + PADDLE_HEIGHT) &&
             ~(rendered_y > 489 && rendered_y < 492))
        rgb_reg <= 6'b111111;

    // Player paddle render logic
    else if (rendered_x >= (PLAYER_PADDLE_X_POS - PADDLE_WIDTH) && rendered_x <= (PLAYER_PADDLE_X_POS + PADDLE_WIDTH) &&
             rendered_y >= (paddle_y - PADDLE_HEIGHT) && rendered_y <= (paddle_y + PADDLE_HEIGHT) &&
             ~(rendered_y > 489 && rendered_y < 492))
        rgb_reg <= 6'b111111;

    // Ball render logic
    else if (rendered_x >= (ball_x - BALL_SIZE) && rendered_x <= (ball_x + BALL_SIZE) &&
             rendered_y >= (ball_y - BALL_SIZE) && rendered_y <= (ball_y + BALL_SIZE) &&
             ~(rendered_y > 489 && rendered_y < 492))
        rgb_reg <= 6'b111111;

    // Render middle line
    else if (rendered_x < (327 + MIDDLE_LINE_WIDTH) && rendered_x > (328 - MIDDLE_LINE_WIDTH) &&
             ~(rendered_y > 489 && rendered_y < 492))
        rgb_reg <= 6'b110011; // display vertical purple line

    // Empty space render logic
    else begin
        // could insert a bg color/animation here if desired
        if (~(rendered_y > 489 && rendered_y < 492))
            rgb_reg <= 6'b000000; // display a black pixel for empty space
    end

end
        if (rendered_x == 799 && rendered_y == 524) begin // finished rendering one line of video, move onto the next line
                clk_div <= clk_div + 1;  
                // 60 screens get generated per second (60Hz), therefore we need to have a way to slow the game down for 
                // human readability and this is one method available to us (+1 clk_div per screen reset every 60 screens)
                if (clk_div > 59) begin
                    clk_div <= 0;
        	end
        end
    end
	assign uo_out = (video_on) ? {h_sync, v_sync, rgb_reg} : 8'b0;
	assign uio_out = 0;
	assign uio_oe = 0;
endmodule
