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
  task print_sudoku; 
  input [31:0] addr;
  reg [7:0] i;
  reg [31:0] grid [80:0];
  begin
    for (i = 0; i < 81; i = i + 1) begin
      read_mem(addr + (i << 2), 4, grid[i]);
    end
    for (i = 0; i < 9; i = i + 1) begin
      $display("%1d%1d%1d|%1d%1d%1d|%1d%1d%1d", grid[(i * 9) + 0], 
        grid[(i * 9) + 1], grid[(i * 9) + 2], grid[(i * 9) + 3], 
        grid[(i * 9) + 4], grid[(i * 9)  + 5], grid[(i * 9) + 6], 
        grid[(i * 9) + 7], grid[(i * 9) + 8]);
      if (i == 2 || i == 5) $display("---+---+---");
    end
  end
  endtask

  task execute_test;
  output result;
  reg [3:0] irqs;
  reg [31:0] data;
  reg [31:0] check_data;
  reg [2:0] resp;
  reg [9:0] i, j;
  reg [31:0] failed;
  reg [31:0] res;
  reg [31:0] sudoku;
  begin
    failed = 0;
    print_sudoku(32'h8000);
    // start
    launch_kernel(0, irqs);

    read_kernel_reg(0, 4, res[31:0], resp);

    if (res[31:0] != 32'd1) begin
      $display("Sudoku could not be solved.");
      failed = failed + 1;
    end else begin
      $display("SOLUTION:");
      print_sudoku(32'h8000);
      for (i = 0; i < 81; i = i + 1) begin
        read_mem(32'h8000 + (i << 4), 4, sudoku);
        read_mem(32'h10000 + (i << 4), 4, check_data);
	if (check_data != sudoku) begin
	  $display("Field (%d, %d) is wrong, expected: %d", i / 9, i % 9, check_data);
	  failed = failed + 1;
	end
      end
      if (failed == 0) begin
        $display("SOLUTION CORRECT");
      end else begin
        $display("EXPECTED SOLUTION:");
        print_sudoku(32'h10000);
      end
    end

    if (failed == 0) begin
      result = 1;
    end else begin
      result = 0;
    end
  end
  endtask
