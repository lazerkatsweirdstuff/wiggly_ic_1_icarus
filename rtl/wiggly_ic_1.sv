`default_nettype none
`timescale 1ns / 1ps

module wiggly_ic_1 (
  input wire        clk, rst,
                     
  input wire        vga_clk_pix, // pixel clock
  output wire       vga_hsync, vga_vsync,
  output wire [1:0] vga_r, vga_g, vga_b, // 2-bit VGA r/g/b
  // used by Verilator:
  output wire [9:0] vga_sx, vga_sy, // horiz/vert screen position
  output wire       vga_de,

  output wire [7:0] most_recent_kbd_data,
  
  input wire        kbd_clk, kbd_data,

  input wire        mouse_clk_in, mouse_data_in,
  output wire       mouse_clk_out, mouse_data_out,
  output wire       mouse_clk_oe, mouse_data_oe // HIGH when we want to output       
);

    // PS/2 keyboard input
    reg [7:0]      kbd_dout;
    reg            kbd_rx_done_tick;
    ps2rx kbd (
      .clk(clk), .reset(rst),
      .ps2d(kbd_data), .ps2c(kbd_clk),
      .rx_en(1'b1),
      .rx_idle(), .rx_done_tick(kbd_rx_done_tick),
      .dout(kbd_dout)
    );
    
    always @ (posedge clk) begin
        if (kbd_rx_done_tick)
            most_recent_kbd_data <= kbd_dout;
    end

    // PS/2 mouse
    reg [7:0] mouse_dout;
    reg       mouse_rx_done_tick;
    reg       mouse_rx_idle, mouse_tx_idle;
    ps2rx mouse_rx (
      .clk(clk), .reset(rst),
      .ps2d(mouse_data_in), .ps2c(mouse_clk_in),
      .rx_en(mouse_tx_idle),
      .rx_idle(mouse_rx_idle), .rx_done_tick(mouse_rx_done_tick),
      .dout(mouse_dout)
    );
    
    reg mouse_tx_done_tick;
    // outputs of the fsm
    reg       mouse_wr_ps2;
    reg [7:0] mouse_din;

    `ifdef SIM
        assign mouse_tx_idle = 1'b1;
    `else
        ps2tx mouse_tx (
          .clk(clk), .reset(rst),
          .wr_ps2(mouse_wr_ps2), .rx_idle(mouse_rx_idle),
          .din(mouse_din),
          .ps2c(mouse_clk_in),
          .ps2c_out(mouse_clk_out), .ps2d_out(mouse_data_out),
          .tri_c(mouse_clk_oe), .tri_d(mouse_data_oe),
          .tx_idle(mouse_tx_idle), .tx_done_tick(mouse_tx_done_tick)
        );
    `endif

    // Mouse operations
    parameter READ_EXPECT = 0, WRITE = 1, 
              READ_PACKET0 = 2, READ_PACKET1 = 3, 
              READ_PACKET2 = 4, DONE_PACKET = 5;
    reg [4:0] mouse_ops_idx;
    reg [4:0] mouse_ops_idx_next;
    
    always @ (posedge clk) begin
        if (rst)
            mouse_ops_idx <= 5'd06; // skip to reading packets
        else
            mouse_ops_idx <= mouse_ops_idx_next;
    end
    
    reg [7:0] mouse_op_code;
    always @ (*) begin
        mouse_ops_idx_next = mouse_ops_idx;
        case (mouse_ops_idx)
            5'd00: mouse_op_code = 8'hFF; 
            5'd01: mouse_op_code = 8'hFA; 
            5'd02: mouse_op_code = 8'hAA; 
            5'd03: mouse_op_code = 8'h00; 
            5'd04: mouse_op_code = 8'hF4;
            5'd05: mouse_op_code = 8'hFA;
            5'd06: mouse_op_code = 8'h00;
            5'd07: mouse_op_code = 8'h00;
            5'd08: mouse_op_code = 8'h00;
            5'd09: mouse_op_code = 8'h00;
            default: mouse_op_code = 8'hFF;
        endcase
    end

    reg [9:0] mouse_x, mouse_y;
    always @ (posedge clk) begin
        if (rst) begin
            mouse_x <= 10'd6;
            mouse_y <= 10'd6;
        end else if (mouse_ops_idx == DONE_PACKET) begin
            mouse_x <= mouse_x + mouse_dout;  // Simplified movement logic for Icarus Verilog
            mouse_y <= mouse_y + mouse_dout;  // Update with a proper formula for actual movement
        end
    end

    // VGA
    simple_display_timings_480p display_timings_inst (
        .clk_pix(vga_clk_pix), .rst(rst),
        .sx(vga_sx), .sy(vga_sy),
        .hsync(vga_hsync), .vsync(vga_vsync), .de(vga_de)
    );

    always @ (posedge vga_clk_pix) begin
        vga_r = 2'h0; vga_g = 2'h0; vga_b = 2'h0;
        if (vga_de) begin
            vga_r = 2'h3; vga_g = 2'h3; vga_b = 2'h3;
            if ((mouse_x <= vga_sx && vga_sx <= mouse_x + 10 &&
                 mouse_y <= vga_sy && vga_sy <= mouse_y + 10)) begin
                vga_r = 2'h0; vga_g = 2'h0; vga_b = 2'h3;
            end
        end
    end

endmodule
