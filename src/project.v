`default_nettype none
`timescale 1ns / 1ps
/*
// Function to check if pixel is within the paddle area
function in_paddle(input [9:0] i, input [9:0] j, input [9:0] current, input [9:0] op_current);
    begin
        if ((i >= op_current && i < op_current + PADDLE_HEIGHT && j >= 0 && j < PADDLE_WIDTH) || 
            (i >= current && i < current + PADDLE_HEIGHT && j >= SCREEN_WIDTH - PADDLE_WIDTH && j < SCREEN_WIDTH)) 
            in_paddle = 1;
        else
            in_paddle = 0;
    end
endfunction

// Function to check if pixel is within the ball area
function in_ball(input [9:0] i, input [9:0] j, input [9:0] ball_x, input [9:0] ball_y);
    begin
        if (j >= ball_x && j <= ball_x + BALL_SIZE && i >= ball_y && i <= ball_y + BALL_SIZE)
            in_ball = 1;
        else
            in_ball = 0;
    end
endfunction
*/

module tt_um_PongGame (
    input  wire [7:0] ui_in,    // The value could be zero or one, indicating up or down movement, or something similar
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset

    //----- Since this is just the pong portion of the entire TTO design, these should be our IO instead
    //input wire [2:0] ui_in,
    //input wire clk,
    //output wire [9:0] player_paddle_y,
    //output wire [9:0] opponent_paddle_y,
    //output wire [9:0] current_ball_x,
    //output wire [9:0] current_ball_y,
    //output wire [7:0] score //(top half opponent score, bottom half player score)

);

  // List all unused inputs to prevent warnings
    wire _unused = &{ena, rst_n, uio_in, 1'b0};
    

    // Parameters
    // these might be better to import into the module instead of instantiating this here (for more variable control)
    
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter BALL_SIZE = 10;
    parameter PADDLE_WIDTH = 10;
    parameter PADDLE_HEIGHT = 60;
    parameter BALL_SPEED = 2;
    parameter PADDLE_SPEED = 2;
    parameter OPP_PADDLE_X_POS = 30;
    parameter PLAYER_PADDLE_X_POS = 610;
    parameter MIDDLE_LINE_WIDTH = 4;
    parameter SUPER_PIXEL_SIZE = 8;

    // VGA output
    reg [7:0] vga_out = 0;

    // Ball direction
    reg ball_dir_x = 1; // 1 for right, 0 for left
    reg ball_dir_y = 1; // 1 for down, 0 for up

    // Game Score
    reg [7:0] game_score = (2 + 15) + 2; // 0'bxxxx0000 is opp score, 0'b0000xxxx is player score
    

    // Ball position
    reg [9:0] ball_x = 320;
    reg [9:0] ball_y = 240; // 10-bit positions for the ball (up to 640 for x and 480 for y)

    // Paddle position
    reg [9:0] paddle_y = SCREEN_HEIGHT / 2; // 10-bit position for the paddle (up to 480 for y)

    // Opponent Paddle position
    reg [9:0] op_paddle_y = SCREEN_HEIGHT / 2; // 10-bit position for the opposing paddle (up to 480 for y)

    // screen rendering register for VGA output
    reg [9:0] rendered_x = 0; // this register holds the current pixel's x-position that is being rendered via VGA (0-800 industry standard)
    reg [9:0] rendered_y = 0; // this register holds the current pixel's y-position that is being rendered via VGA (0-525 industry standard)
    
    // Clock divider to make game run at readable speeds, this is incremented on each game frame being generated
    reg [5:0] clk_div = 0;
    
    // Ball movement
    always @(posedge clk_div[1]) begin // on the 32nd out of 60 frames generated per second (happens once per second)
        if (!rst_n) begin
            ball_x <= SCREEN_WIDTH / 2;
            ball_y <= SCREEN_HEIGHT / 2;
        end else begin
            // Update ball position
            if (ball_dir_x)
                ball_x <= ball_x + BALL_SPEED;
            else
                ball_x <= ball_x - BALL_SPEED;

            if (ball_dir_y)
                ball_y <= ball_y + BALL_SPEED;
            else
                ball_y <= ball_y - BALL_SPEED;

            // Ball collision with screen edges
            if (ball_x <= BALL_SIZE) // Here, player scores
                game_score <= game_score + 1; // equivalent to + 1'b1 (bottom half of score is player)
                ball_x <= SCREEN_WIDTH / 2;
                ball_y <= SCREEN_HEIGHT / 2;
            
            if (ball_x >= SCREEN_WIDTH - BALL_SIZE) // Here, opponent scores
                game_score <= game_score + 16; // equivalent to + 1'b10000 (top half of score is opponent)
                ball_x <= SCREEN_WIDTH / 2;
                ball_y <= SCREEN_HEIGHT / 2;
            
            if (ball_y <= BALL_SIZE || ball_y >= SCREEN_HEIGHT - BALL_SIZE)
                ball_dir_y <= ~ball_dir_y;
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

    always @(posedge clk_div[4]) begin
        if (!rst_n) begin
            paddle_y <= (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
        end else begin
            // Move paddle up, check lower bound
            if (btn_up && paddle_y > 0)
                paddle_y <= paddle_y - PADDLE_SPEED;
            // Move paddle down, check upper bound
            else if (btn_down && paddle_y < SCREEN_HEIGHT - PADDLE_HEIGHT)
                paddle_y <= paddle_y + PADDLE_SPEED;
        end
    end

    // Ball collision with paddle (simple example)
    always @(posedge clk_div[4]) begin
        if ((ball_x <= PADDLE_WIDTH && ball_y >= op_paddle_y && ball_y <= op_paddle_y + PADDLE_HEIGHT) || ball_x >= SCREEN_WIDTH-PADDLE_WIDTH && ball_y >= paddle_y && ball_y <= paddle_y)
            ball_dir_x <= ~ball_dir_x; // Ball bounces off the paddle
    end

    // Opponent Paddle simple AI
    always @(posedge clk_div[4]) begin
        if (ball_y <= op_paddle_y)
            op_paddle_y <= op_paddle_y - PADDLE_SPEED;
        else if (ball_y >= op_paddle_y)
            op_paddle_y <= op_paddle_y + PADDLE_SPEED;
    end
    
    always @(posedge clk) begin // this timing needs to be tweaked, essentially should occur once every 10ns or 25MHz

        // logic for left border render
        
        if (rendered_x < 8) begin // left border, RBG does not matter therefore set to black for now
            if (rendered_y > 489 && rendered_y < 492 ) // 8 line top border + 480 line video + 2 line front porch
                vga_out <= 8'b10000000; // keep Vsync Low
            else
                vga_out <= 8'b11000000; // keep Vsync High
        end

        
        // logic for rendering one video line (currently rendering only for paddles and ball)
        // FOR FUTURE: render score and middle dotted line
        if (rendered_x > 7 && rendered_x < 648) begin

            // Render Opponent Score
            
            // make a 3x5 super pixel grid which depending on the current score changes the rendering to match the number
            // 1 super pixel = 10x10 pixels
            
            // Opp Super Pixel[0][0] : {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered
            if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 && rendered_y < 83)
                vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Opp Super Pixel[1][0]: {0,1,2,3,5,6,7,8,9} rendered, {4} not rendered
            else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE && rendered_y > 72 && rendered_y < 83 && ~((game_score & 8'b11110000) && 8'b01000000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[2][0]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
            else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 && rendered_y < 83 && ~((game_score & 8'b11110000) && 8'b00010000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[0][1]: {0,4,5,6,8,9} rendered, {1,2,3,7} not rendered
            else if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE && ~(((game_score & 8'b11110000) && 8'b00010000) || ((game_score & 8'b11110000) && 8'b00100000) || ((game_score & 8'b11110000) && 8'b00110000) || ((game_score & 8'b11110000) && 8'b01110000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Opp Super Pixel[1][1]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
            else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE && ((game_score & 8'b11110000) && 8'b00010000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[2][1]: {0,2,3,4,7,8,9} rendered, {1,5,6} not rendered
            else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE && ~(((game_score & 8'b11110000) && 8'b00010000) || ((game_score & 8'b11110000) && 8'b01010000) || ((game_score & 8'b11110000) && 8'b01100000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[0][2]: {0,2,3,4,5,6,8,9} rendered, {1,7} not rendered
            else if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b11110000) && 8'b00010000) || ((game_score & 8'b11110000) && 8'b01110000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Opp Super Pixel[1][2]: {1,2,3,4,5,6,7,8,9} rendered, {0} not rendered
            else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) && ~((game_score & 8'b11110000) && 8'b00000000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[2][2]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
            else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) && ~((game_score & 8'b11110000) && 8'b00010000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[0][3]: {0,2,6,8} rendered, {1,3,4,5,7,9} not rendered
            else if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) && ((game_score & 8'b11110000) && 8'b00000000) || ((game_score & 8'b11110000) && 8'b00100000) || ((game_score & 8'b11110000) && 8'b01100000) || ((game_score & 8'b11110000) && 8'b10000000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Opp Super Pixel[1][3]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
            else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE && rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) && (game_score & 8'b11110000) && 8'b00010000)
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[2][3]: {0,3,4,5,6,7,8,9} rendered, {1,2} not rendered
            else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b11110000) && 8'b00010000) || ((game_score & 8'b11110000) && 8'b00100000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[0][3]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
            else if (rendered_x > 158 && rendered_x < 169 && rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b11110000) && 8'b01000000) || ((game_score & 8'b11110000) && 8'b01110000) || ((game_score & 8'b11110000) && 8'b10010000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Opp Super Pixel[1][3]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
            else if (rendered_x > 158 + SUPER_PIXEL_SIZE && rendered_x < 169 + SUPER_PIXEL_SIZE && rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b11110000) && 8'b01000000) || ((game_score & 8'b11110000) && 8'b01110000) || ((game_score & 8'b11110000) && 8'b10010000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Opp Super Pixel[2][3]: {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered 
            else if (rendered_x > 158 + (2*SUPER_PIXEL_SIZE) && rendered_x < 169 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE))
                vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            
            // Render Player Score

            // make a 3x5 super pixel grid which depending on the current score changes the rendering to match the number
            // 1 super pixel = 10x10 pixels
            
            // Player Super Pixel[0][0] : {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered
            else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 && rendered_y < 83)
                vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Player Super Pixel[1][0]: {0,1,2,3,5,6,7,8,9} rendered, {4} not rendered
            else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE && rendered_y > 72 && rendered_y < 83 && ~((game_score & 8'b00001111) && 8'b01000000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[2][0]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
            else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 && rendered_y < 83 && ~((game_score & 8'b00001111) && 8'b00010000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[0][1]: {0,4,5,6,8,9} rendered, {1,2,3,7} not rendered
            else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE && ~(((game_score & 8'b00001111) && 8'b00010000) || ((game_score & 8'b00001111) && 8'b00100000) || ((game_score & 8'b00001111) && 8'b00110000) || ((game_score & 8'b00001111) && 8'b01110000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Player Super Pixel[1][1]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
            else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE && ((game_score & 8'b00001111) && 8'b00010000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[2][1]: {0,2,3,4,7,8,9} rendered, {1,5,6} not rendered
            else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + SUPER_PIXEL_SIZE && rendered_y < 83 + SUPER_PIXEL_SIZE && ~(((game_score & 8'b00001111) && 8'b00010000) || ((game_score & 8'b00001111) && 8'b01010000) || ((game_score & 8'b00001111) && 8'b01100000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[0][2]: {0,2,3,4,5,6,8,9} rendered, {1,7} not rendered
            else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b00001111) && 8'b00010000) || ((game_score & 8'b00001111) && 8'b01110000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Player Super Pixel[1][2]: {1,2,3,4,5,6,7,8,9} rendered, {0} not rendered
            else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) && ~((game_score & 8'b00001111) && 8'b00000000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[2][2]: {0,2,3,4,5,6,7,8,9} rendered, {1} not rendered
            else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + (2*SUPER_PIXEL_SIZE) && rendered_y < 83 + (2*SUPER_PIXEL_SIZE) && ~((game_score & 8'b00001111) && 8'b00010000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[0][3]: {0,2,6,8} rendered, {1,3,4,5,7,9} not rendered
            else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) && ((game_score & 8'b00001111) && 8'b00000000) || ((game_score & 8'b00001111) && 8'b00100000) || ((game_score & 8'b00001111) && 8'b01100000) || ((game_score & 8'b11110000) && 8'b10000000))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Player Super Pixel[1][3]: {1} rendered, {0,2,3,4,5,6,7,8,9} not rendered
            else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE && rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) && (game_score & 8'b00001111) && 8'b00010000)
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[2][3]: {0,3,4,5,6,7,8,9} rendered, {1,2} not rendered
            else if (rendered_x > 478 + (2*SUPER_PIXEL_SIZE) && rendered_x < 489 + (2*SUPER_PIXEL_SIZE) && rendered_y > 72 + (3*SUPER_PIXEL_SIZE) && rendered_y < 83 + (3*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b00001111) && 8'b00010000) || ((game_score & 8'b00001111) && 8'b00100000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[0][3]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
            else if (rendered_x > 478 && rendered_x < 489 && rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b00001111) && 8'b01000000) || ((game_score & 8'b00001111) && 8'b01110000) || ((game_score & 8'b00001111) && 8'b10010000)))
                    vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel
            
            // Player Super Pixel[1][3]: {0,1,2,3,5,6,8} rendered, {4,7,9} not rendered
            else if (rendered_x > 478 + SUPER_PIXEL_SIZE && rendered_x < 489 + SUPER_PIXEL_SIZE && rendered_y > 72 + (4*SUPER_PIXEL_SIZE) && rendered_y < 83 + (4*SUPER_PIXEL_SIZE) && ~(((game_score & 8'b00001111) && 8'b01000000) || ((game_score & 8'b00001111) && 8'b01110000) || ((game_score & 8'b00001111) && 8'b10010000)))
                vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel

            // Player Super Pixel[2][3]: {0,1,2,3,4,5,6,7,8,9} rendered, {} not rendered 
            else if (rendered_x < (489 + (2*SUPER_PIXEL_SIZE)) && rendered_x > (478 + (2*SUPER_PIXEL_SIZE)) && rendered_y > (72 + (4*SUPER_PIXEL_SIZE)) && rendered_y < (83 + (4*SUPER_PIXEL_SIZE)))
                vga_out <= 8'b11111111; //vsync is invariant within this range, display a white super pixel            


            // Opponent paddle render logic
            
            else if (rendered_x >= (OPP_PADDLE_X_POS - PADDLE_WIDTH) && rendered_x <= (OPP_PADDLE_X_POS + PADDLE_WIDTH) && rendered_y >= (op_paddle_y - PADDLE_HEIGHT) && rendered_y <= (op_paddle_y + PADDLE_HEIGHT) && rendered_y > 489 && rendered_y < 492)
                vga_out <= 8'b10111111; // keep Vsync Low, display a white pixel for opponent paddle
            else if (rendered_x >= (OPP_PADDLE_X_POS - PADDLE_WIDTH) && rendered_x <= (OPP_PADDLE_X_POS + PADDLE_WIDTH) && rendered_y >= (op_paddle_y - PADDLE_HEIGHT) && rendered_y <= (op_paddle_y + PADDLE_HEIGHT) && ~(rendered_y > 489 && rendered_y < 492))
                vga_out <= 8'b11111111; // keep Vsync High, display a white pixel for opponent paddle 

            // Player paddle render logic
            
            else if (rendered_x >= (PLAYER_PADDLE_X_POS - PADDLE_WIDTH) && rendered_x <= (PLAYER_PADDLE_X_POS + PADDLE_WIDTH) && rendered_y >= (paddle_y - PADDLE_HEIGHT) && rendered_y <= (paddle_y + PADDLE_HEIGHT) && rendered_y > 489 && rendered_y < 492)
                vga_out <= 8'b10111111; // keep Vsync Low, display a white pixel for player paddle
            else if (rendered_x >= (PLAYER_PADDLE_X_POS - PADDLE_WIDTH) && rendered_x <= (PLAYER_PADDLE_X_POS + PADDLE_WIDTH) && rendered_y >= (paddle_y - PADDLE_HEIGHT) && rendered_y <= (paddle_y + PADDLE_HEIGHT) && ~(rendered_y > 489 && rendered_y < 492))
                vga_out <= 8'b11111111; // keep Vsync High, display a white pixel for player paddle

            // Ball render logic
            
            else if (rendered_x >= (ball_x - BALL_SIZE) && rendered_x <= (ball_x + BALL_SIZE) && rendered_y >= (ball_y - BALL_SIZE) && rendered_y <= (ball_y + BALL_SIZE) && rendered_y > 489 && rendered_y < 492) 
                vga_out <= 8'b10111111; // keep Vsync Low, display a white pixel for the ball 
            else if (rendered_x >= (ball_x - BALL_SIZE) && rendered_x <= (ball_x + BALL_SIZE) && rendered_y >= (ball_y - BALL_SIZE) && rendered_y <= (ball_y + BALL_SIZE) && ~(rendered_y > 489 && rendered_y < 492)) 
                vga_out <= 8'b11111111; // keep Vsync High, display a white pixel for the ball

            // Render middle line
            
            else if (rendered_x < (327 + MIDDLE_LINE_WIDTH) && rendered_x > (328 - MIDDLE_LINE_WIDTH) && rendered_y > 489 && rendered_y < 492)
                vga_out <= 8'b10110011; // keep Vsync Low, display vertical purple line
            else if (rendered_x < (327 + MIDDLE_LINE_WIDTH) && rendered_x > (328 - MIDDLE_LINE_WIDTH) && ~(rendered_y > 489 && rendered_y < 492))
                vga_out <= 8'b11110011; // keep Vsync High, display vertical purple line

            // Empty space render logic
            
            else begin
                if (rendered_y > 489 && rendered_y < 492)
                    vga_out <= 8'b10000000; // Vsync Low, display a black pixel for empty space
                else
                    vga_out <= 8'b11000000; // Vsync High, display a black pixel for empty space
            end
        end

        // Front Porch Logic
        if (rendered_x > 647 && rendered_x < 656) begin
            if (rendered_y > 489 && rendered_y < 492)
                vga_out <= 8'b10000000; // Vsync Low, RGB doesnt matter, therefore outputing a black pixel
            else
                vga_out <= 8'b11000000; // Vsync High, RGB doesnt matter, therefore outputing a black pixel
        end

        // V-Sync Render Logic
        if (rendered_x > 655 && rendered_x < 752) begin
            if (rendered_y > 489 && rendered_y < 492)
                vga_out <= 8'b00000000; // Vsync Low, RGB doesnt matter, therefore outputing a black pixel
            else
                vga_out <= 8'b01000000; // Vsync High, RGB doesnt matter, therefore outputing a black pixel
        end

        // Back-Porch Logic
        if (rendered_x > 751 && rendered_x < 800) begin
            if (rendered_y > 489 && rendered_y < 492)
                vga_out <= 8'b10000000; // Vsync Low, RGB doesnt matter, therefore outputing a black pixel
            else
                vga_out <= 8'b11000000; // Vsync High, RGB doesnt matter, therefore outputing a black pixel
        end
        
        rendered_x <= rendered_x + 1;

        if (rendered_x > 799) begin // finished rendering one line of video, move onto the next line
            rendered_x <= 0;
            rendered_y <= rendered_y + 1;
            if (rendered_y > 524) begin // finished rendering one screen of video, begin rendering the next screen
                rendered_y <= 0;
                clk_div <= clk_div + 1;  
                // 60 screens get generated per second (60Hz), therefore we need to have a way to slow the game down for 
                // human readability and this is one method available to us (+1 clk_div per screen reset every 60 screens)
                if (clk_div > 59) begin
                    clk_div <= 0;
                end
            end
        end
    end

    assign uo_out = vga_out;  // Second to last bit
    assign uio_out = 0;
    assign uio_oe = 0;


    
endmodule
