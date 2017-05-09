//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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

`timescale 1 ns / 1 ps

`include "GP_LED_v1_0_tb_include.vh"

// lite_response Type Defines
`define RESPONSE_OKAY 2'b00
`define RESPONSE_EXOKAY 2'b01
`define RESP_BUS_WIDTH 2
`define BURST_TYPE_INCR  2'b01
`define BURST_TYPE_WRAP  2'b10

module GP_LED_v1_0_tb;
	reg tb_ACLK;
	reg tb_ARESETn;
	reg tb_IN_0;
	reg tb_IN_1;
	reg tb_IN_2;
	reg tb_IN_3;
	reg tb_IN_4;
	reg tb_IN_5;
	wire [7:0] tb_LED_Port;

	// Create an instance of the example tb
	`BD_WRAPPER dut (	.ACLK(tb_ACLK),
				.ARESETN(tb_ARESETn),
				.IN_0(tb_IN_0),
				.IN_1(tb_IN_1),
				.IN_2(tb_IN_2),
				.IN_3(tb_IN_3),
				.IN_4(tb_IN_4),
				.IN_5(tb_IN_5),
				.LED_Port(tb_LED_Port)
			);

	// Local Variables


	// Simple Reset Generator and test
	initial begin
		tb_ARESETn = 1'b0;
	  #500;
		// Release the reset on the posedge of the clk.
		@(posedge tb_ACLK);
	  tb_ARESETn = 1'b1;
		@(posedge tb_ACLK);
	end

	// Simple Clock Generator
	initial tb_ACLK = 1'b0;
	always #10 tb_ACLK = !tb_ACLK;

	// Create the test vectors
	initial begin
		// When performing debug enable all levels of INFO messages.
		wait(tb_ARESETn === 0) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);  

		// Create test data vectors
	end

	// Drive the BFM
	initial begin
		// Wait for end of reset
		wait(tb_ARESETn === 0) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     

		#100;

		tb_IN_0 = 1'b1;
		tb_IN_1 = 1'b1;
		tb_IN_2 = 1'b1;
		tb_IN_3 = 1'b1;
		tb_IN_4 = 1'b1;
		tb_IN_5 = 1'b1;

		#100;

		tb_IN_0 = 1'b0;
		tb_IN_1 = 1'b1;
		tb_IN_2 = 1'b0;
		tb_IN_3 = 1'b1;
		tb_IN_4 = 1'b0;
		tb_IN_5 = 1'b1;

	end

endmodule
