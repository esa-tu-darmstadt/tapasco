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

`include "pcie_intr_ctrl_v1_0_tb_include.vh"

// lite_response Type Defines
`define RESPONSE_OKAY 2'b00

// AMBA AXI4 Lite Range Constants
`define S_AXI_INTR_DATA_BUS_WIDTH 32

module pcie_intr_ctrl_v1_0_tb;
	reg tb_axi_aclk;
	reg tb_axi_aresetn;

	reg tb_msi_enable;
	reg tb_msi_grant;
	reg [2:0] tb_msi_vector_width;

	reg tb_irq_in_0;
	reg tb_irq_in_1;
	reg tb_irq_in_2;
	reg tb_irq_in_3;
	reg tb_irq_in_4;
	reg tb_irq_in_5;
	reg tb_irq_in_6;
	reg tb_irq_in_7;

	wire [4:0] 	tb_msi_vector_num;
	wire 		tb_irq_out;

	// Create an instance of the example tb
	`BD_WRAPPER dut (	.axi_aclk(tb_axi_aclk),
				.axi_aresetn(tb_axi_aresetn),

				.msi_enable(tb_msi_enable),
				.msi_grant(tb_msi_grant),
				.msi_vector_width(tb_msi_vector_width),

				.irq_in_0(tb_irq_in_0),
				.irq_in_1(tb_irq_in_1),
				.irq_in_2(tb_irq_in_2),
				.irq_in_3(tb_irq_in_3),
				.irq_in_4(tb_irq_in_4),
				.irq_in_5(tb_irq_in_5),
				.irq_in_6(tb_irq_in_6),
				.irq_in_7(tb_irq_in_7),

				.msi_vector_num(tb_msi_vector_num),
				.irq_out(tb_irq_out)
			);

	// Local Variables


	// Simple Reset Generator and test
	initial begin
		tb_axi_aresetn = 1'b0;
	  #500;
		// Release the reset on the posedge of the clk.
		@(posedge tb_axi_aclk);
	  tb_axi_aresetn = 1'b1;
		@(posedge tb_axi_aclk);
	end

	// Simple Clock Generator
	initial tb_axi_aclk = 1'b0;
	always #5 tb_axi_aclk = !tb_axi_aclk;

	// Drive the BFM
	initial begin
		
		tb_msi_enable <= 1'b0;
		tb_msi_grant <= 1'b0;
		tb_msi_vector_width <= 3'b0;

		tb_irq_in_0 <= 1'b0;
		tb_irq_in_1 <= 1'b0;
		tb_irq_in_2 <= 1'b0;
		tb_irq_in_3 <= 1'b0;
		tb_irq_in_4 <= 1'b0;
		tb_irq_in_5 <= 1'b0;
		tb_irq_in_6 <= 1'b0;
		tb_irq_in_7 <= 1'b0;

		// Wait for end of reset
		wait(tb_axi_aresetn === 0) @(posedge tb_axi_aclk);
		wait(tb_axi_aresetn === 1) @(posedge tb_axi_aclk);
		wait(tb_axi_aresetn === 1) @(posedge tb_axi_aclk);     
		wait(tb_axi_aresetn === 1) @(posedge tb_axi_aclk);     
		wait(tb_axi_aresetn === 1) @(posedge tb_axi_aclk);

	#100;
	tb_msi_enable <= 1'b1;
	tb_msi_vector_width <= 3'b101;

	#1000;
	tb_irq_in_0 <= 1'b1;
        tb_irq_in_1 <= 1'b1;
	tb_irq_in_2 <= 1'b1;
	tb_irq_in_3 <= 1'b1;
        tb_irq_in_4 <= 1'b1;
        tb_irq_in_5 <= 1'b1;
        tb_irq_in_6 <= 1'b1;
        tb_irq_in_7 <= 1'b1;
		
	#1000;
	tb_msi_grant <= 1'b1;
	#10;
	tb_msi_grant <= 1'b0;
	#1000;
	tb_msi_grant <= 1'b1;
	#10;
	tb_msi_grant <= 1'b0;
	
	#1000;

        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0;
        #1000;
        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0;                
      
        #10;
        tb_irq_in_3 <= 1'b0;
        #10;
        tb_irq_in_3 <= 1'b1;        
      
      
        #1000;
        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0; 
        #1000;
        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0;
        
        #1000;
        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0; 
        #1000;
        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0;

        #1000;
        tb_msi_grant <= 1'b1;
        #10;
        tb_msi_grant <= 1'b0;

	end

endmodule
