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
module oled_bfm (
    clk,
    rst_n,
    sclk,
    sdc,
    sdin
  );
  parameter
    C_COLS = 128,
    C_ROWS = 32;

  function integer log2;
    input integer n;
    begin
      n = n - 1;
      for (log2 = 0; n > 0; log2 = log2 + 1)
        n = n >> 1;
    end
  endfunction

  input wire clk, rst_n, sclk, sdc, sdin;

  reg [63:0] r_fc;			// frame counter
  reg [C_COLS * C_ROWS - 1 : 0] r_fb;	// frame buffer
  reg [log2(C_COLS) - 1 : 0] r_col;	// current col
  reg [log2(C_ROWS) - 1 : 0] r_row;	// current row

  always @(posedge clk) begin
    if (!rst_n) begin
      r_fc <= 'b0;
      r_fb <= 'b0;
      r_col <= 'b0;
      r_row <= 'b0;
    end
  end

  reg [2:0] r_bit;
  always @(posedge sclk, negedge rst_n) begin
    if (rst_n == 1'b0)    r_bit <= 3'd7;
    else if (sdc == 1'b1) r_bit <= r_bit - 1;
  end

  wire [31:0] crow;
  assign crow = {r_row[log2(C_ROWS) - 1:3], r_bit};

  always @(posedge sclk) begin
    if (rst_n == 1'b1 && sdc == 1'b1) begin
      r_fb[crow * C_COLS + r_col] <= sdin;
      r_row <= r_row + 1;
      if (r_row == C_ROWS - 1) begin
        r_col <= r_col + 1;
        if (r_col == C_COLS - 1) r_fc <= r_fc + 1;
      end
    end
  end

  always @(r_fc) $display("dumping frame %d", render(r_fc));

  integer dumpfile;
  initial dumpfile = $fopen("screendump.txt", "w");

  function integer render;
    input integer r_fc;
    integer r, c;
    begin
      render = r_fc;
      $fwrite(dumpfile, "Frame #%d:\n", r_fc);
      for (r = C_ROWS - 1; r >= 0; r = r - 1) begin
        for (c = 0; c < C_COLS; c = c + 1)
          $fwrite(dumpfile, "%s", r_fb[r * C_COLS + c] == 1'b1 ? "O" : ".");
        $fwrite(dumpfile, "\n");
      end
      $fwrite(dumpfile, "\n");
    end
  endfunction
endmodule
