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
//! @file   oled_init.v
//! @brief  Controller for zedboard on-board OLED; initializes display.
//! @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
module oled_init (
    input wire clk,
    input wire rst_n,
    output reg initialized,
    output reg oled_vdd,
    output reg oled_vbat,
    output reg oled_res,
    output reg oled_sclk,
    output wire oled_dc,
    output reg oled_sdin,
    output reg heartbeat
  );

  parameter [31:0]
    C_DELAY_1MS   = 32'd4000;   // @ 4MHz -> 4000 cycles;

  parameter // [3:0]
    S_START    = 0,
    S_CONFIG_0 = 2,
    S_CONFIG_1 = 4,
    S_CONFIG_2 = 6,
    S_DONE     = 7;

  /***************************************************************************************/
  // CONFIG MICRO PROGRAM
  wire [144:0] CONFIG_DATA = {
      8'hAE,                    // display off
      // wait
      8'h8D,
      8'h14,
      8'hD9,
      8'hF1,
      // wait
      8'h81,                    // set contrast
      8'hDC,                    // 220/255
      8'hA0,                    // set left/right seg map
      8'hC8,                    // set COM output scan inverted
      8'hDA,                    // set COM pin config
      8'h22,                    // reset values,
      //8'h18,                    // reset values,
      8'hAF,                    // set display on
      8'h20,                    // vertical addressing
      8'h01,
      8'h22,                    // page config: 0-3
      8'h00,
      8'h03,
      8'hA5,                    // DEBUG: activate all pixels
      1'b0                      // dummy bit
    };
  wire [7:0] CONFIG_DATA_0_L = 8'd137;
  wire [7:0] CONFIG_DATA_1_L = 8'd105;
  wire [7:0] CONFIG_DATA_2_L = 8'd9;
  /***************************************************************************************/

  reg [3:0] r_state;            // state register
  reg [3:0] r_nstate;           // next state register
  reg [7:0] r_bit;              // current bit
  reg [31:0] r_delay;           // delay register (cycles)

  // true in SPI writing states
  wire spiwrite;
  assign spiwrite = (r_state == S_CONFIG_0) || (r_state == S_CONFIG_1) || (r_state == S_CONFIG_2);

  // oled_dc: always 0 -- command
  assign oled_dc = 1'b0;

  // oled_sdin and r_bit process (negative sclk edge)
  always @(negedge oled_sclk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      r_bit <= 'd144;
      oled_sdin <= CONFIG_DATA[144];
    end else begin
      oled_sdin <= CONFIG_DATA[r_bit];
      if (spiwrite && r_delay == 'd0 && r_bit != 'd0) r_bit <= r_bit - 'd1;
    end
  end

  // oled_sclk process
  always @(posedge clk) begin
    if (rst_n == 1'b1 && spiwrite && r_delay == 'd0) oled_sclk <= ~oled_sclk;
    else                                             oled_sclk <= 1'b1;
  end

  // vdd process
  always @(posedge clk) begin
    if (rst_n == 1'b0) oled_vdd <= 1'b1;
    else               oled_vdd <= 1'b0;
  end

  // vbat process
  always @(posedge clk) begin
    if (rst_n == 1'b0) oled_vbat <= 1'b1;
    else               oled_vbat <= !((r_state == S_CONFIG_1 && r_delay > 'd0) || r_state > S_CONFIG_1);
  end

  // res process
  always @(posedge clk) begin
    if (rst_n == 1'b0) oled_res <= 1'b1;
    else               oled_res <= !(r_delay > 'd0 && r_state == S_CONFIG_0);
  end

  // initialized process
  always @(posedge clk) begin
    if (rst_n == 1'b0) initialized <= 1'b0;
    else               initialized <= (r_state == S_DONE);
  end

  // delay process
  always @(posedge clk) begin
    if (rst_n == 1'b0) r_delay <= 'd0;
    else begin
      if (r_delay > 'd0)                                 r_delay <= r_delay - 'd1;
      else begin
      case (r_state)
        S_START    :                                     r_delay <= C_DELAY_1MS;
        S_CONFIG_0 : if (r_bit == CONFIG_DATA_0_L - 'd1) r_delay <= C_DELAY_1MS;
        S_CONFIG_1 : if (r_bit == CONFIG_DATA_1_L - 'd1) r_delay <= C_DELAY_1MS * 100;
        S_CONFIG_2 : if (r_bit == CONFIG_DATA_2_L - 'd1) r_delay <= 'd750;
      endcase
      end
    end
  end

  // state process
  always @(posedge clk) begin
    if (rst_n == 1'b0) begin
      r_state <= S_START;
    end else begin
      if (r_delay == 'd1) r_state <= r_nstate;
      else if (r_delay == 'd0) begin
      case (r_state)
        S_START    :      r_nstate <= S_CONFIG_0;
        S_CONFIG_0 :      r_nstate <= S_CONFIG_1;
        S_CONFIG_1 :      r_nstate <= S_CONFIG_2;
        S_CONFIG_2 :      r_nstate <= S_DONE;
      endcase
      end
    end
  end

  // heartbeat process (4 Hz)
  reg [31:0] hb;
  always @(posedge clk) begin
    if (rst_n == 1'b0) begin
      hb <= C_DELAY_1MS * 32'd250;
      heartbeat <= 1'b0;
    end else begin
      hb <= hb - 32'd1;
      if (hb == 32'd0) begin
        heartbeat <= ~heartbeat;
        hb <= C_DELAY_1MS * 32'd250;
      end
    end
  end

endmodule
