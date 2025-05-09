// Project F: FPGA Graphics - Simple 640x480p60 Display Timings
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module simple_display_timings_480p (
    input  wire clk_pix,           // pixel clock
    input  wire rst,               // reset
    output reg [9:0] sx,           // horizontal screen position
    output reg [9:0] sy,           // vertical screen position
    output reg hsync,              // horizontal sync
    output reg vsync,              // vertical sync
    output reg de                  // data enable (low in blanking interval)
    );

`ifdef SMALL
    parameter HA_END = 20;
    parameter HS_STA = HA_END + 16;
    parameter HS_END = HS_STA + 6;
    parameter LINE = 40;

    parameter VA_END = 18;
    parameter VS_STA = VA_END + 6;
    parameter VS_END = VS_STA + 2;
    parameter SCREEN = 28;
`else
    // horizontal timings
    parameter HA_END = 639;           // end of active pixels
    parameter HS_STA = HA_END + 16;   // sync starts after front porch
    parameter HS_END = HS_STA + 96;   // sync ends
    parameter LINE   = 799;           // last pixel on line (after back porch)

    // vertical timings
    parameter VA_END = 479;           // end of active pixels
    parameter VS_STA = VA_END + 10;   // sync starts after front porch
    parameter VS_END = VS_STA + 2;    // sync ends
    parameter SCREEN = 524;           // last line on screen (after back porch)
`endif

    always @(*) begin
        hsync = ~(sx >= HS_STA && sx < HS_END);  // invert: negative polarity
        vsync = ~(sy >= VS_STA && sy < VS_END);  // invert: negative polarity
        de = (sx <= HA_END && sy <= VA_END);
    end

    // calculate horizontal and vertical screen position
    always @(posedge clk_pix or posedge rst) begin
        if (rst) begin
            sx <= 0;
            sy <= 0;
        end else begin
            if (sx == LINE) begin  // last pixel on line?
                sx <= 0;
                sy <= (sy == SCREEN) ? 0 : sy + 1;  // last line on screen?
            end else begin
                sx <= sx + 1;
            end
        end
    end
endmodule
 
