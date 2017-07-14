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
//! @file   oled_performance_counters.v
//! @brief  Performance counter module with SPI data output for zedboard OLED.
//!         Configurable number of counters + bit width; continuously writes
//!         current data via SPI to OLED controller at half clk speed.
//!         Displays the counters as bars of C_COLS width on the display.
//!         This is debug IP, no attempts at optimization have been made.
//! @author J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
module oled_performance_counters #(
    parameter C_COUNTER_N = 64,
    parameter C_COUNTER_W = 6,    // bit width of counters
    parameter C_COLS = 128,       // number of display columns
    parameter C_ROWS = 32         // number of display rows
  ) (
    input wire clk,
    input wire rst_n,
    input wire [C_COUNTER_N - 1 : 0] intr,
    input wire ready,
    output reg oled_sclk,
    output wire oled_dc,
    output wire oled_sdin
  );

  // constant function: compute log_2 of integer
  function integer log2;
    input integer n;
    begin
      n = n - 1;
      for (log2 = 0; n > 0; log2 = log2 + 1)
        n = n >> 1;
    end
  endfunction

  function integer max;
    input integer n1, n2;
    begin
      max = n2 > n1 ? n2 : n1;
    end
  endfunction

  reg [log2(C_COLS) - 1 : 0] r_col;		              // current column
  reg [log2(C_ROWS) - 1 : 0] r_row;		              // current row
  reg [max(log2(C_COUNTER_N / C_ROWS), 1) - 1 : 0] r_page;    // current page

  reg [C_COUNTER_W - 1 : 0] r_pc [C_COUNTER_N - 1 : 0];
  reg [C_COUNTER_N - 1 : 0] r_intr;		          // int regs

  // oled_sdc
  assign oled_dc = 1'b1;                        // always 1 -- data

  // oled_sclk process
  always @(posedge clk) begin
    if (rst_n == 1'b1 && ready) oled_sclk <= ~oled_sclk;
    else                        oled_sclk <= 1'b1;
  end

  reg [7:0] r_word;			// SPI word
  reg [2:0] r_cnt;			// bit counter
  wire [31:0] offset;			// row offset with paging
  assign offset = r_page * C_ROWS + r_row;
  assign oled_sdin = r_word[0];

  // SPI process
  always @(negedge oled_sclk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      r_word    <= 'd0;
      r_cnt     <= 'd7;
    end else begin
      if (r_cnt == 'd7) begin
        if ((r_col >= (1 << C_COUNTER_W)) || (offset >= C_COUNTER_N)) begin
	  r_word <= 8'd0;
	end else begin
	  r_word <= {
	    offset + 0 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 0] >= r_col + 'd1),
	    offset + 1 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 1] >= r_col + 'd1),
	    offset + 2 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 2] >= r_col + 'd1),
	    offset + 3 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 3] >= r_col + 'd1),
	    offset + 4 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 4] >= r_col + 'd1),
	    offset + 5 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 5] >= r_col + 'd1),
	    offset + 6 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 6] >= r_col + 'd1),
	    offset + 7 >= C_COUNTER_N ? 1'b0 : (r_pc[offset + 7] >= r_col + 'd1)
	  };
	end
      end else begin
	r_word <= r_word >> 1;
      end
      r_cnt <= r_cnt - 'd1;
    end
  end

  // process: advance pixel coordinates by one
  // vertical top to bottom, left to right
  always @(negedge oled_sclk, negedge rst_n) begin
    if (rst_n == 1'b0 || ready == 1'b0) begin
      r_col  <= 'd0;               // reset row/col
      r_row  <= 'd0;
      r_page <= 'd0;
    end else begin
      r_row <= r_row + 1;         // advance row
      if (r_row == C_ROWS - 1) begin
        r_col <= r_col == C_COLS - 1 ? 'b0 : r_col + 1;
	if (C_COUNTER_N > C_ROWS) begin
          if (r_col == C_COLS - 1) r_page <= r_page + 'd1;
	end
      end
    end
  end

  // process: count posedges on the intr input lines (synch)
  genvar i;
  generate
  for (i = 0; i < C_COUNTER_N; i = i + 1) begin
    always @(posedge clk) begin
      if (rst_n == 1'b0) begin
        r_intr[i] <= 1'b0;
        r_pc[i] <= 'd0;
      end else begin
        r_intr[i] <= intr[i];
        if (intr[i] == 1'b1 && r_intr[i] == 1'b0)
          r_pc[i] <= r_pc[i] + 1;
      end
    end
  end
  endgenerate

endmodule
