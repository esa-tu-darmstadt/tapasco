//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file 	oled_pc.v
//! @brief	Controller IP to visually represent counters on zedboard OLED.
//!		Simple IP core with configurable number of interrupt inputs.
//!		Interrupts are counted with wrap-around and displayed as bars
//!		on the zedboard OLED display which is connected via SPI.
//!		This is debug IP and no attempts at optimization have been made.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
module oled_pc #(
    parameter C_COUNTER_N = 64,      // number of counters
    parameter C_COUNTER_W = 6,       // counter bit width
    parameter C_COLS      = 128,     // display columns
    parameter C_ROWS      = 32,      // display rows
    parameter C_DELAY_1MS = 32'd4000 // delay of 1ms in clock cycles
  ) (
    input wire clk,
    input wire rst_n,
    input wire [C_COUNTER_N - 1 : 0] intr,
    output wire oled_vdd,
    output wire oled_vbat,
    output wire oled_res,
    output reg oled_sclk,
    output reg oled_dc,
    output reg oled_sdin,
    output wire initialized,
    output wire heartbeat
  );

  wire oled_sclk_init, oled_dc_init, oled_sdin_init;
  wire oled_sclk_data, oled_dc_data, oled_sdin_data;

  reg [1:0] synchronizer [C_COUNTER_N - 1 : 0];
  wire [C_COUNTER_N - 1 : 0] s_intr;

  genvar i;
  generate for (i = 0; i < C_COUNTER_N; i = i + 1) begin
    always @(posedge clk) begin
      synchronizer[i][0] <= intr[i];
      synchronizer[i][1] <= synchronizer[i][0];
    end
    assign s_intr[i] = synchronizer[i][1];
  end
  endgenerate

  // after initialization, switch to oled_performance_counters module
  always @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      oled_sclk <= 1'b0;
      oled_dc   <= 1'b0;
      oled_sdin <= 1'b0;
    end else begin
      oled_sclk <= initialized == 1'b1 ? oled_sclk_data : oled_sclk_init;
      oled_dc   <= initialized == 1'b1 ? oled_dc_data   : oled_dc_init;
      oled_sdin <= initialized == 1'b1 ? oled_sdin_data : oled_sdin_init;
    end
  end

  oled_init #(
    .C_DELAY_1MS ( C_DELAY_1MS )
  ) oled_init_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .initialized ( initialized ),
    .oled_vdd ( oled_vdd ),
    .oled_vbat ( oled_vbat ),
    .oled_res ( oled_res ),
    .oled_sclk ( oled_sclk_init ),
    .oled_dc ( oled_dc_init ),
    .oled_sdin ( oled_sdin_init ),
    .heartbeat ( heartbeat )
  );

  oled_performance_counters #(
    .C_COUNTER_N ( C_COUNTER_N ),
    .C_COUNTER_W ( C_COUNTER_W ),
    .C_COLS ( C_COLS ),
    .C_ROWS ( C_ROWS )
  ) oled_pc_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .intr ( s_intr ),
    .ready ( initialized ),
    .oled_sclk ( oled_sclk_data ),
    .oled_dc ( oled_dc_data ),
    .oled_sdin ( oled_sdin_data )
  );

endmodule
