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
//! @file	spireceiver.v
//! @brief	Primitive SPI slave, reads 8b words and displays them.
//!		Not for synthesis, sim only.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
module spireceiver (
    input wire clk,
    input wire rst_n,
    input wire sclk,
    input wire sdc,
    input wire sdin
  );

  // internal states
  parameter [2:0]
    S_READ_BIT7 = 3'd0,
    S_READ_BIT6 = 3'd1,
    S_READ_BIT5 = 3'd2,
    S_READ_BIT4 = 3'd3,
    S_READ_BIT3 = 3'd4,
    S_READ_BIT2 = 3'd5,
    S_READ_BIT1 = 3'd6,
    S_READ_BIT0 = 3'd7;

  reg [2:0] r_state;
  reg r_sdc, r_print;
  reg [7:0] r_word;

  // print the current word
  task print_word();
    begin
      if (r_sdc) $display("received data: %08b (%02x)", r_word, r_word);
      else $display("received command: %08b (%02x)", r_word, r_word);
    end
  endtask

  always @(negedge clk) begin
    if (rst_n) begin
      r_state <= S_READ_BIT7;
      if (r_print) begin
        r_print <= 1'b0;
        print_word();
      end
    end else r_print <= 1'b0;
  end

  // sample inputs on sclk (negative edge, SPI clock is "active low")
  always @(negedge sclk) begin
    if (rst_n == 1'b1) begin
      r_sdc <= sdc;
      r_word <= r_word << 1;
      r_word[0] <= sdin;
      case (r_state)
        S_READ_BIT7 : r_state <= S_READ_BIT6;
        S_READ_BIT6 : r_state <= S_READ_BIT5;
        S_READ_BIT5 : r_state <= S_READ_BIT4;
        S_READ_BIT4 : r_state <= S_READ_BIT3;
        S_READ_BIT3 : r_state <= S_READ_BIT2;
        S_READ_BIT2 : r_state <= S_READ_BIT1;
        S_READ_BIT1 : r_state <= S_READ_BIT0;
        S_READ_BIT0 : r_state <= S_READ_BIT7;
      endcase
      r_print <= r_state == S_READ_BIT0;
    end
  end

endmodule
