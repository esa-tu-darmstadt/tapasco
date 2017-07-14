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
module shift_pattern_generator #(
    parameter C_PATTERN_W = 64     // bit width of pattern
  ) (
    input wire clk,
    input wire rst_n,
    output reg [C_PATTERN_W - 1 : 0] pattern
  );

  // pattern process
  always @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0 || pattern == 'd0) pattern <= 'd1;
    else                                 pattern <= (pattern << 1);
  end

endmodule
