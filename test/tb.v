`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // temp wires to test pong game outputs
   wire [9:0] ball_x_pos;
   wire [9:0] ball_y_pos;
   wire [9:0] player_paddle_y;
   wire [9:0] opponent_paddle_y;
   wire [7:0] score; //(top half opponent score, bottom half player score)


   
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  tt_um_PongGame user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
     .rst_n  (rst_n),     // not reset
     .current_ball_x(ball_x_pos), // TEMP FOR TESTING
     .current_ball_y(ball_y_pos), // TEMP FOR TESTING
     .player_paddle_y(player_paddle_y), // TEMP FOR TESTING
     .opponent_paddle_y(opponent_paddle_y), // TEMP FOR TESTING
     .score(score) // TEMP FOR TESTING
  );

endmodule
