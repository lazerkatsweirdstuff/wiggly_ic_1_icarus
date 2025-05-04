`default_nettype none
`timescale 1ns / 1ps

module ps2tx
   (
    input wire        clk, reset,
    input wire        wr_ps2, rx_idle,
    input wire [7:0]  din,
    output reg        tx_idle, tx_done_tick,

    // was `inout tri ps2c, ps2d`
    input wire        ps2c,
    output reg        ps2c_out, ps2d_out,
    output wire       tri_c, tri_d // HIGH when we're transmitting
   );

   // fsm state type 
   typedef enum {idle, waitr, rts, start, data, stop} state_type;

   // declaration
   state_type state_reg, state_next;
   reg [7:0] filter_reg;
   reg [7:0] filter_next;
   reg f_ps2c_reg;
   reg f_ps2c_next;
   reg [3:0] n_reg, n_next;
   reg [8:0] b_reg, b_next;
   reg [12:0] c_reg, c_next;
   wire par, fall_edge;

   // body
   //*****************************************************************
   // filter and falling-edge tick generation for ps2c
   //*****************************************************************
   always @(posedge clk or posedge reset) begin
      if (reset) begin
         filter_reg <= 8'b0;
         f_ps2c_reg <= 1'b0;
      end
      else begin
         filter_reg <= filter_next;
         f_ps2c_reg <= f_ps2c_next;
      end
   end

   assign filter_next = {ps2c, filter_reg[7:1]};
   assign f_ps2c_next = (filter_reg == 8'b11111111) ? 1'b1 :
                        (filter_reg == 8'b00000000) ? 1'b0 :
                         f_ps2c_reg;
   assign fall_edge = f_ps2c_reg & ~f_ps2c_next;

   //*****************************************************************
   // FSMD
   //*****************************************************************
   // state & data registers
   always @(posedge clk or posedge reset) begin
      if (reset) begin
         state_reg <= idle;
         c_reg <= 13'b0;
         n_reg <= 4'b0;
         b_reg <= 9'b0;
      end
      else begin
         state_reg <= state_next;
         c_reg <= c_next;
         n_reg <= n_next;
         b_reg <= b_next;
      end
   end

   // odd parity bit
   assign par = ~(^din);

   // next-state logic
   always @(*) begin
      state_next = state_reg;
      c_next = c_reg;
      n_next = n_reg;
      b_next = b_reg;
      tx_done_tick = 1'b0;
      ps2c_out = 1'b1;
      ps2d_out = 1'b1;
      tri_c = 1'b0;
      tri_d = 1'b0;
      tx_idle = 1'b0;

      case (state_reg)
         idle: begin
            tx_idle = 1'b1;
            if (wr_ps2) begin
               b_next = {par, din};
               c_next = 13'h1fff; // 2^13-1
               state_next = waitr;
            end
         end
         waitr: begin
            if (rx_idle)
               state_next = rts;         
         end
         rts: begin  // request to send
            ps2c_out = 1'b0;
            tri_c = 1'b1;
            c_next = c_reg - 1;
            if (c_reg == 0)
               state_next = start;
         end
         start: begin // assert start bit
            ps2d_out = 1'b0;
            tri_d = 1'b1;
            if (fall_edge) begin
               n_next = 4'h8;
               state_next = data;
            end
         end
         data: begin  //  8 data + 1 parity        
            ps2d_out = b_reg[0];
            tri_d = 1'b1;
            if (fall_edge) begin
               b_next = {1'b0, b_reg[8:1]};
               if (n_reg == 0)
                  state_next = stop;
               else
                  n_next = n_reg - 1;
            end
         end
         default: begin   // assume floating high for ps2d
            if (fall_edge) begin
               state_next = idle;
               tx_done_tick = 1'b1;
            end
         end
      endcase
   end

   // tristate buffers
   assign tri_c = (ps2c_out) ? 1'b1 : 1'bz;
   assign tri_d = (ps2d_out) ? 1'b1 : 1'bz;

endmodule // ps2tx
