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
`ifndef __TEST_HARNESS_VH__ 
`define __TEST_HARNESS_VH__ 1
  `define CLK_PERIOD 			8
  `define TIMEOUT			1000000000		// 1000 ms
  `define PROGRESS			100000			// cycles

  reg clk;
  reg rst;
  reg [95:0] progress;

  // clock generation
  initial clk <= 1;
  always #(`CLK_PERIOD >> 1) clk <= ~clk;

  // timeout process
  initial begin
    repeat (`TIMEOUT/`CLK_PERIOD) @(posedge clk);
    $display("--- SIMULATION TIMEOUT @ %0d ---", $time);
    $display("--- TEST FAILED @ %d ---", $time);
    $finish;
  end

  // progress process
  initial progress <= `PROGRESS;

  always @(posedge clk) begin
    if (rst) begin
      progress <= progress - 1;
      if (progress == 0) begin
        $display("--- PROGRESS: %d cycles @ %0d ---", `PROGRESS, $time);
        progress <= `PROGRESS;
      end
    end
  end

  // reset generation
  initial begin
    #100 rst <= 0;
    repeat (1000) @(posedge clk);
    rst <= 1;
    repeat (100) @(posedge clk);
    $display("--- RESET PHASE FINISHED @ %0d ---", $time);
  end

  system system_i(
    clk,
    rst
  );

`endif /* __TEST_HARNESS_VH__ */
