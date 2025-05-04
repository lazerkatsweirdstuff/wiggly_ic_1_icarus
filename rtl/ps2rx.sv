`default_nettype none
`timescale 1ns / 1ps

module ps2rx
   (
    input clk, reset,
    input ps2d, ps2c, rx_en,
    output reg rx_idle, rx_done_tick,
    output reg [7:0] dout
   );

   // FSM state type using parameters for state encoding
   parameter idle = 2'b00, dps = 2'b01, load = 2'b10;
   reg [1:0] state_reg, state_next;
   reg [1:0] n_reg, n_next;
   reg [10:0] b_reg, b_next;
   reg [7:0] filter_reg, filter_next;
   reg f_ps2c_reg, f_ps2c_next;
   reg fall_edge;

   // Filter and falling-edge tick generation for ps2c
   always @ (posedge clk or posedge reset)
   if (reset) begin
      filter_reg <= 8'b0;
      f_ps2c_reg <= 1'b0;
   end
   else begin
      filter_reg <= filter_next;
      f_ps2c_reg <= f_ps2c_next;
   end

   assign filter_next = {ps2c, filter_reg[7:1]};
   assign f_ps2c_next = (filter_reg == 8'b11111111) ? 1'b1 :
                        (filter_reg == 8'b00000000) ? 1'b0 :
                         f_ps2c_reg;
   assign fall_edge = f_ps2c_reg & ~f_ps2c_next;

   // FSM: State & Data Registers
   always @ (posedge clk or posedge reset)
   if (reset) begin
      state_reg <= idle;
      n_reg <= 4'b0;
      b_reg <= 11'b0;
   end
   else begin
      state_reg <= state_next;
      n_reg <= n_next;
      b_reg <= b_next;
   end

   // FSM: Next-state logic
   always @ (*)
   begin
      state_next = state_reg;
      rx_idle = 1'b0;
      rx_done_tick = 1'b0;
      n_next = n_reg;
      b_next = b_reg;

      case (state_reg)
         idle: begin
            rx_idle = 1'b1;
            if (fall_edge & rx_en) begin
               // Shift in start bit
               b_next = {ps2d, b_reg[10:1]};
               n_next = 4'b1001;
               state_next = dps;
            end
         end
         dps: begin // 8 data + 1 parity + 1 stop
            if (fall_edge) begin
               b_next = {ps2d, b_reg[10:1]};
               if (n_reg == 0)
                  state_next = load;
               else
                  n_next = n_reg - 1;
            end
         end
         load: begin
            // 1 extra clock to complete last shift
            state_next = idle;
            rx_done_tick = 1'b1;
         end
         default: state_next = idle;
      endcase
   end

   // Output: data bits
   always @ (*) begin
      dout = b_reg[8:1];  // data bits (7 data bits + parity bit)
   end

endmodule // ps2rx
