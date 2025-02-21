# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# SCREEN_WIDTH = 640;
# SCREEN_HEIGHT = 480;
# BALL_SIZE = 10;
# PADDLE_WIDTH = 10;
# PADDLE_HEIGHT = 60;
# BALL_SPEED = 2;
# PADDLE_SPEED = 2;
# ball_dir_x = 1
# ball_dir_y = 1
# ball_x = SCREEN_WIDTH/2
# ball_y = SCREEN_HEIGHT/2






@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 40 ns (25 MHz)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    # await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    f = open('test_vga_output.txt', 'w').close()
    f = open("test_vga_output.txt", "a")

    
    for i in range((800*525)+10): # 30 clock cycles
    #for i in range(10): # 30 clock cycles

        
        
        # assert pow(2,ball_dir_x)+ball_dir_y == dut.uo_out
        #await ClockCycles(dut.clk, 65540)
        await ClockCycles(dut.clk, 1)

        time = i * 40
        
        hsync = dut.uo_out[7].value
        
        vsync = dut.uo_out[6].value
        
        red_1 = dut.uo_out[5].value
        red_0 = dut.uo_out[4].value
        
        blue_1 = dut.uo_out[3].value
        blue_0 = dut.uo_out[2].value
        
        green_1 = dut.uo_out[1].value
        green_0 = dut.uo_out[0].value
        

        dut._log.info(f"{time} ns: {hsync} {vsync} 0{red_1}{red_0} 0{blue_1}{blue_0} {green_1}{green_0}\n")
        f.write(f"{time} ns: {hsync} {vsync} 0{red_1}{red_0} 0{blue_1}{blue_0} {green_1}{green_0}\n")
    f.close()


