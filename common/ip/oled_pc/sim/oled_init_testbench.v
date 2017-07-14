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
module oled_init_testbench;
  reg clk;
  initial clk = 0;
  always #125 clk = ~clk;

  reg rst_n;
  initial begin
    rst_n = 0;
    repeat (1000) @(posedge clk);
    rst_n = 1;
  end

  wire initialized, oled_vdd, oled_vbat, oled_res, oled_sclk, oled_dc, oled_sdin, heartbeat;

  oled_init oled_init_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .initialized ( initialized ),
    .oled_vdd ( oled_vdd ),
    .oled_vbat ( oled_vbat ),
    .oled_res ( oled_res ),
    .oled_sclk ( oled_sclk ),
    .oled_dc ( oled_dc ),
    .oled_sdin ( oled_sdin ),
    .heartbeat ( heartbeat )
  );

  spireceiver spireceiver_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .sclk ( oled_sclk ),
    .sdc ( oled_dc ),
    .sdin ( oled_sdin )
  );

  initial begin
    @(posedge initialized);
    repeat (10) @(posedge clk);
    $finish;
  end
endmodule
