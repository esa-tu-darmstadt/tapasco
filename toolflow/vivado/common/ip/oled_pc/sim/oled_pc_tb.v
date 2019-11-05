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
`timescale 1ns / 1ps
module oled_pc_tb #(
    parameter C_COUNTER_N = 1,       // number of counters
    parameter C_COUNTER_W = 7,       // counter bit width
    parameter C_COLS      = 128,     // display columns
    parameter C_ROWS      = 32       // display rows
  );

  // clock generation: 4 MHz clock
  reg clk;
  initial clk = 0;
  always #125 clk = ~clk;

  integer delay = 400000;		// 100ms in clock cycles
  // process: display progress of time every 100 ms
  always @(posedge clk) begin
    if (delay > 0)	delay = delay - 1;
    else begin
      delay = 400000;
      $display("--- PROGRESS: 100ms ---");
    end
  end

  // reset generation
  reg rst_n;
  initial begin
    rst_n = 0;
    repeat (1000) @(posedge clk);
    rst_n = 1;
    $display("--- RESET PHASE FINISHED ---");
  end

  // interrupt generation
  reg [C_COUNTER_N - 1:0] r_intr;
  initial r_intr = 'd0;

  wire oled_vdd, oled_vbat, oled_res;
  wire oled_sclk, oled_dc, oled_sdin;
  wire init, hb;

  oled_pc #(
    .C_COUNTER_N ( C_COUNTER_N ),
    .C_COUNTER_W ( C_COUNTER_W ),
    .C_COLS ( C_COLS ),
    .C_ROWS ( C_ROWS )
  ) oled_pc_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .intr ( r_intr ),
    .oled_vdd ( oled_vdd ),
    .oled_vbat ( oled_vbat ),
    .oled_res ( oled_res ),
    .oled_sclk ( oled_sclk ),
    .oled_dc ( oled_dc ),
    .oled_sdin ( oled_sdin ),
    .initialized ( init ),
    .heartbeat ( hb )
  );

  oled_bfm #(
    .C_COLS ( C_COLS ),
    .C_ROWS ( C_ROWS )
  ) oled_bfm_i (
    .clk ( clk ),
    .rst_n ( rst_n ),
    .sclk ( oled_sclk ),
    .sdc ( oled_dc ),
    .sdin ( oled_sdin )
  );

  integer i;		// loop var

  initial begin
    @(posedge init);

    // provoke overflow on every performance counter
    repeat (1 << C_COUNTER_W) begin
      r_intr <= 'b1;
      repeat (C_COUNTER_N) begin
        repeat (100) @(posedge clk);
        r_intr <= r_intr << 1;
      end
      repeat (100) @(posedge clk);
    end

    repeat (10000) @(posedge clk);
    for (i = 0; i < C_COUNTER_N; i = i + 1) begin
      show_pc_value(i);
      if (|oled_pc_i.oled_pc_i.r_pc[i]) $stop; // stop on error
    end

    $display("\nFINISHED - TEST PASSED");
    if (oled_bfm_i.r_fc < 70)
      @(oled_bfm_i.r_fc >= 70);
    $finish;			// else just finish
  end

  task automatic show_pc_value;
    input integer i;
    begin
      if (oled_pc_i.oled_pc_i.r_pc[i] == 'h0)
        $display("r_pc[%d] = %b (%d) \tVALUE OK!", i,
          oled_pc_i.oled_pc_i.r_pc[i],
          oled_pc_i.oled_pc_i.r_pc[i]);
      else
        $display("r_pc[%d] = %b (%d) \tERROR!", i,
          oled_pc_i.oled_pc_i.r_pc[i],
          oled_pc_i.oled_pc_i.r_pc[i]);
    end
  endtask
endmodule
