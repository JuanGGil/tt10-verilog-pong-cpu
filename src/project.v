`default_nettype none

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

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

    // Parameters
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter BALL_SIZE = 10;
    parameter PADDLE_WIDTH = 10;
    parameter PADDLE_HEIGHT = 60;
    parameter BALL_SPEED = 2;
    parameter PADDLE_SPEED = 2;

    // Ball direction
    reg ball_dir_x = 1; // 1 for right, 0 for left
    reg ball_dir_y = 1; // 1 for down, 0 for up

    // Clock divider for slower ball movement
    reg [15:0] clk_div;
    always @(posedge clk) begin
        if (!rst_n) begin
            clk_div <= 0;
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    // Ball movement
    always @(posedge clk_div[15]) begin
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
            if (ball_x <= BALL_SIZE || ball_x >= SCREEN_WIDTH - BALL_SIZE)
                ball_dir_x <= ~ball_dir_x;
            if (ball_y <= BALL_SIZE || ball_y >= SCREEN_HEIGHT - BALL_SIZE)
                ball_dir_y <= ~ball_dir_y;
        end
    end

    // Paddle movement
    reg btn_up;
    reg btn_down;

    always @(ui_in) begin
        if (ui_in == 1) begin
            btn_up = 1;
            btn_down = 0;
        end else begin
            btn_up = 0;
            btn_down = 1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            paddle_y <= (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
        end else begin
            if (btn_up && paddle_y > 0)
                paddle_y <= paddle_y - PADDLE_SPEED;
            else if (btn_down && paddle_y < SCREEN_HEIGHT - PADDLE_HEIGHT)
                paddle_y <= paddle_y + PADDLE_SPEED;
        end
    end

    // Ball collision with paddle (simple example)
    always @(posedge clk_div[15]) begin
        if (ball_x <= PADDLE_WIDTH && ball_y >= paddle_y && ball_y <= paddle_y + PADDLE_HEIGHT)
            ball_dir_x <= ~ball_dir_x;
    end

endmodule
