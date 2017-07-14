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
module oled (
    input wire clk,
    input wire rst_n,
    input wire vbat,
    input wire vdd,
    input wire res,
    input wire dc,
    input wire sclk,
    input wire sdin,
    input wire init
  );

  parameter NAME = "oled";

  always @(posedge init) $display("%s @ %t: initialization complete", NAME, $time);
  always @(rst_n) $display("%s @ %t: rst_n = %b", NAME, $time, rst_n);
  always @(vdd) $display("%s @ %t: vdd = %b", NAME, $time, vdd);
  always @(vbat) $display("%s @ %t: vbat = %b", NAME, $time, vbat);
  always @(res) $display("%s @ %t: res = %b", NAME, $time, res);

  spireceiver #(.NAME(NAME)) spireceiver_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .sclk ( sclk ),
    .sdc ( dc ),
    .sdin ( sdin )
  );

endmodule
