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

`include "dual_dma_v1_0_tb_include.vh"

// lite_response Type Defines
`define RESPONSE_OKAY 2'b00
`define RESPONSE_EXOKAY 2'b01
`define RESP_BUS_WIDTH 2
`define BURST_TYPE_INCR  2'b01
`define BURST_TYPE_WRAP  2'b10

// AMBA AXI4 Lite Range Constants
`define S_AXI_MAX_BURST_LENGTH 1

`define S_AXI_REGISTER 8
//`define S_AXI_DATA_BUS_WIDTH 64
`define S_AXI_DATA_BUS_WIDTH 32

`define S_AXI_ADDRESS_BUS_WIDTH 32
`define S_AXI_MAX_DATA_SIZE (`S_AXI_DATA_BUS_WIDTH*`S_AXI_MAX_BURST_LENGTH)/8


`define SLAVE_AXI_ADDRESS_BUS_WIDTH 64
`define SLAVE_AXI_BASE_ADDRESS 5000000060000000

	// Streaming defines
`define MAX_BURST_LENGTH 1
`define DESTVALID_FALSE 1'b0
`define DESTVALID_TRUE  1'b1
`define IDVALID_TRUE  1'b1
`define IDVALID_FALSE 1'b0
`define DATA_BUS_WIDTH 32
`define ID_BUS_WIDTH    8
`define DEST_BUS_WIDTH  4
`define USER_BUS_WIDTH  8
`define MAX_PACKET_SIZE 10
`define MAX_OUTSTANDING_TRANSACTIONS 8
`define STROBE_NOT_USED  0
`define KEEP_NOT_USED  0

module dual_dma_v1_0_tb;
	reg tb_ACLK_LITE;
	reg tb_ARESETN_LITE;
	reg tb_ACLK_M64;
	reg tb_ARESETN_M64;
	reg tb_ACLK_M32;
	reg tb_ARESETN_M32;

	wire tb_IRQ;

	// Create an instance of the example tb
	`BD_WRAPPER dut (	.ACLK_LITE(tb_ACLK_LITE),
				.ARESETN_LITE(tb_ARESETN_LITE),
				.ACLK_M64(tb_ACLK_M64),
				.ARESETN_M64(tb_ARESETN_M64),
				.ACLK_M32(tb_ACLK_M32),
				.ARESETN_M32(tb_ARESETN_M32),
				.IRQ(tb_IRQ));

	// Local Variables

	// AMBA S_AXI AXI4 Lite Local Reg
	reg [`S_AXI_DATA_BUS_WIDTH-1:0] S_AXI_rd_data_lite;
	reg [`S_AXI_DATA_BUS_WIDTH-1:0] S_AXI_test_data_lite [31:0];
	reg [`RESP_BUS_WIDTH-1:0] S_AXI_lite_response;
	reg [`S_AXI_ADDRESS_BUS_WIDTH-1:0] S_AXI_mtestAddress;
	reg [`SLAVE_AXI_ADDRESS_BUS_WIDTH-1:0] SLAVE_AXI_mtestAddress;
	reg [3-1:0]   S_AXI_mtestProtection_lite;
	integer S_AXI_mtestvectorlite; // Master side testvector
	integer S_AXI_mtestdatasizelite;
	integer result_slave_lite;

	
	reg [`ID_BUS_WIDTH-1:0]       mteststreamID;  
	reg [`DEST_BUS_WIDTH-1:0]     mtestDEST;
	reg [`DATA_BUS_WIDTH-1:0]     mtestDATA [7:0];
	reg [(`DATA_BUS_WIDTH/8)-1:0] mtestSTRB;
	reg [(`DATA_BUS_WIDTH/8)-1:0] mtestKEEP;
	reg                          mtestLAST;
	reg [`USER_BUS_WIDTH-1:0]     mtestUSER;
	integer                      mtestDATASIZE;
	reg [(`DATA_BUS_WIDTH*(`MAX_PACKET_SIZE))-1:0] v_mtestDATA;
	reg [(`USER_BUS_WIDTH*(`MAX_PACKET_SIZE))-1:0] v_mtestUSER;

	reg [`ID_BUS_WIDTH-1:0]       steststreamID;  
	reg [`DEST_BUS_WIDTH-1:0]     stestDEST;
	reg [`DATA_BUS_WIDTH-1:0]     stestDATA [7:0];
	reg [(`DATA_BUS_WIDTH/8)-1:0] stestSTRB;
	reg [(`DATA_BUS_WIDTH/8)-1:0] stestKEEP;
	reg                          stestLAST;
	reg [`USER_BUS_WIDTH-1:0]     stestUSER;
	integer                      stestDATASIZE;
	reg [(`DATA_BUS_WIDTH/8)-1:0] all_valid_strobe;
	reg [(`DATA_BUS_WIDTH/8)-1:0] all_valid_keep;
	

	integer                     i; // Simple loop integ
	integer                     j; // Simple loop integer. ;

	// Simple Reset Generator and test
	initial begin
		tb_ARESETN_LITE = 1'b0;
	  #500;
		// Release the reset on the posedge of the clk.
		@(posedge tb_ACLK_LITE);
	  tb_ARESETN_LITE = 1'b1;
		@(posedge tb_ACLK_LITE);
	end

	// Simple Reset Generator and test
	initial begin
		tb_ARESETN_M64 = 1'b0;
	  #500;
		// Release the reset on the posedge of the clk.
		@(posedge tb_ACLK_M64);
	  tb_ARESETN_M64 = 1'b1;
		@(posedge tb_ACLK_M64);
	end

	// Simple Reset Generator and test
	initial begin
		tb_ARESETN_M32 = 1'b0;
	  #500;
		// Release the reset on the posedge of the clk.
		@(posedge tb_ACLK_M32);
	  tb_ARESETN_M32 = 1'b1;
		@(posedge tb_ACLK_M32);
	end

	// Simple Clock Generator
	initial tb_ACLK_LITE = 1'b0;
	always #4 tb_ACLK_LITE = !tb_ACLK_LITE;

	initial tb_ACLK_M64 = 1'b0;
	always #4 tb_ACLK_M64 = !tb_ACLK_M64;

	initial tb_ACLK_M32 = 1'b0;
	always #5 tb_ACLK_M32 = !tb_ACLK_M32;

	//------------------------------------------------------------------------
	// TEST LEVEL API: CHECK_RESPONSE_OKAY
	//------------------------------------------------------------------------
	// Description:
	// CHECK_RESPONSE_OKAY(lite_response)
	// This task checks if the return lite_response is equal to OKAY
	//------------------------------------------------------------------------
	task automatic CHECK_RESPONSE_OKAY;
		input [`RESP_BUS_WIDTH-1:0] response;
		begin
		  if (response !== `RESPONSE_OKAY) begin
			  $display("TESTBENCH ERROR! lite_response is not OKAY",
				         "\n expected = 0x%h",`RESPONSE_OKAY,
				         "\n actual   = 0x%h",response);
		    $stop;
		  end
		end
	endtask

	//------------------------------------------------------------------------
	// TEST LEVEL API: COMPARE_LITE_DATA
	//------------------------------------------------------------------------
	// Description:
	// COMPARE_LITE_DATA(expected,actual)
	// This task checks if the actual data is equal to the expected data.
	// X is used as don't care but it is not permitted for the full vector
	// to be don't care.
	//------------------------------------------------------------------------
	task automatic COMPARE_LITE_DATA;
		input [`S_AXI_DATA_BUS_WIDTH-1:0] expected;
		input [`S_AXI_DATA_BUS_WIDTH-1:0] actual;
		begin
			if (expected === 'hx || actual === 'hx) begin
				$display("TESTBENCH ERROR! COMPARE_LITE_DATA cannot be performed with an expected or actual vector that is all 'x'!");
		    result_slave_lite = 0;
		    //$stop;
		  end

			else if (actual != expected) begin
				$display("TESTBENCH ERROR! Data expected is not equal to actual.",
				         "\nexpected = 0x%h",expected,
				         "\nactual   = 0x%h",actual);
		    result_slave_lite = 0;
		    //$stop;
		  end
			else 
			begin
			   $display("TESTBENCH Passed! Data expected is equal to actual.",
			            "\n expected = 0x%h",expected,
			            "\n actual   = 0x%h",actual);
			end
		end
	endtask

	//------------------------------------------------------------------------
	// TEST LEVEL API: COMPARE_DATA_STREAM
	//------------------------------------------------------------------------
	// Description:
	// COMPARE_DATA_STREAM(expected,actual)
	// This task checks if the actual data is equal to the expected data.
	// X is used as don't care but it is not permitted for the full vector
	// to be don't care.
	//------------------------------------------------------------------------
	task automatic COMPARE_DATA_STREAM;
	input [(`DATA_BUS_WIDTH*(`MAX_BURST_LENGTH+1))-1:0] expected;
	input [(`DATA_BUS_WIDTH*(`MAX_BURST_LENGTH+1))-1:0] actual;
		begin
			if (expected === 'hx || actual === 'hx) begin
			    $display("TESTBENCH ERROR! COMPARE_DATA_STREAM cannot be performed with an expected or actual vector that is all 'x'!");
			    //$stop;
			end

			if (actual != expected) begin
			   $display("TESTBENCH ERROR! Data expected is not equal to actual.",
			            "\n expected = 0x%h",expected,
			            "\n actual   = 0x%h",actual);
			   //$stop;
			end
			else 
			begin
			   $display("TESTBENCH Passed! Data expected is equal to actual.",
			            "\n expected = 0x%h",expected,
			            "\n actual   = 0x%h",actual);
			end
		end
	endtask

	task automatic S_AXI_RW_REGISTER_TEST;
		begin
			$display("---------------------------------------------------------");
			$display("EXAMPLE TEST : S_AXI");
			$display("Simple register write and read example");
			$display("---------------------------------------------------------");

			S_AXI_mtestvectorlite = 0;
			S_AXI_mtestAddress = `S_AXI_SLAVE_ADDRESS;
			S_AXI_mtestProtection_lite = 0;
			S_AXI_mtestdatasizelite = `S_AXI_MAX_DATA_SIZE;

			 result_slave_lite = 1;

			for (S_AXI_mtestvectorlite = 0; S_AXI_mtestvectorlite < `S_AXI_REGISTER; S_AXI_mtestvectorlite = S_AXI_mtestvectorlite + 1)
			begin
			  dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( S_AXI_mtestAddress,
				                     S_AXI_mtestProtection_lite,
				                     S_AXI_test_data_lite[S_AXI_mtestvectorlite],
				                     S_AXI_mtestdatasizelite,
				                     S_AXI_lite_response);
			  $display("EXAMPLE TEST %d write : DATA = 0x%h, lite_response = 0x%h",S_AXI_mtestvectorlite,S_AXI_test_data_lite[S_AXI_mtestvectorlite],S_AXI_lite_response);
			  CHECK_RESPONSE_OKAY(S_AXI_lite_response);
			  /*
			  dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.READ_BURST(S_AXI_mtestAddress,
				                     S_AXI_mtestProtection_lite,
				                     S_AXI_rd_data_lite,
				                     S_AXI_lite_response);
			  $display("EXAMPLE TEST %d read : DATA = 0x%h, lite_response = 0x%h",S_AXI_mtestvectorlite,S_AXI_rd_data_lite,S_AXI_lite_response);
			  CHECK_RESPONSE_OKAY(S_AXI_lite_response);
			  COMPARE_LITE_DATA(S_AXI_test_data_lite[S_AXI_mtestvectorlite],S_AXI_rd_data_lite);
			  $display("EXAMPLE TEST %d : Sequential write and read burst transfers complete from the master side. %d",S_AXI_mtestvectorlite,S_AXI_mtestvectorlite);
			  */
			  S_AXI_mtestAddress = S_AXI_mtestAddress + `S_AXI_DATA_BUS_WIDTH/8;
			end

			$display("---------------------------------------------------------");
			$display("EXAMPLE TEST S_AXI: PTGEN_TEST_FINISHED!");
				if ( result_slave_lite ) begin                                        
					$display("PTGEN_TEST: PASSED!");                 
				end	else begin                                         
					$display("PTGEN_TEST: FAILED!");                 
				end							   
			$display("---------------------------------------------------------");
		end
	endtask

	task automatic SLAVE_MEMORY_INIT;
		begin
			$display("---------------------------------------------------------");
			$display("Init Slave memory registers");
			$display("---------------------------------------------------------");

			S_AXI_mtestvectorlite = 0;
			SLAVE_AXI_mtestAddress = 64'h5000000060000000;
			S_AXI_mtestProtection_lite = 0;
			S_AXI_mtestdatasizelite = `S_AXI_MAX_DATA_SIZE;

		  	dut.`BD_INST_NAME.master_1.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( 
					     SLAVE_AXI_mtestAddress,
			                     S_AXI_mtestProtection_lite,
			                     32'hABCD_5678,
			                     S_AXI_mtestdatasizelite,
			                     S_AXI_lite_response);

			for (S_AXI_mtestvectorlite = 0; S_AXI_mtestvectorlite < 600; S_AXI_mtestvectorlite = S_AXI_mtestvectorlite + 1)
			    begin

		  		dut.`BD_INST_NAME.master_1.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( 
					     SLAVE_AXI_mtestAddress,
			                     S_AXI_mtestProtection_lite,
			                     S_AXI_mtestvectorlite+32'h1122_3344,
			                     S_AXI_mtestdatasizelite,
			                     S_AXI_lite_response);
				CHECK_RESPONSE_OKAY(S_AXI_lite_response);
				/*
			 	dut.`BD_INST_NAME.master_1.cdn_axi4_lite_master_bfm_inst.READ_BURST(
					     SLAVE_AXI_mtestAddress,
				             S_AXI_mtestProtection_lite,
				             S_AXI_rd_data_lite,
				             S_AXI_lite_response);

				CHECK_RESPONSE_OKAY(S_AXI_lite_response);
				COMPARE_LITE_DATA(S_AXI_mtestvectorlite+32'h1122_3344,S_AXI_rd_data_lite);
				*/
		  		SLAVE_AXI_mtestAddress = SLAVE_AXI_mtestAddress + 64'h4;
			    end
		end
	endtask

	task automatic TB_REGISTER_INIT;
		begin
			$display("---------------------------------------------------------");
			$display("Init tb memory registers");
			$display("---------------------------------------------------------");

			// Create test data vectors
			if( `S_AXI_DATA_BUS_WIDTH == 64 )
			  begin	
				S_AXI_test_data_lite[0] = 64'h5000000060000000;
				S_AXI_test_data_lite[1] = 64'hDEADBEEF40000000;
				S_AXI_test_data_lite[2] = 64'h1234567800000007;
				S_AXI_test_data_lite[3] = 64'hC00FFEE100000000;

				for (i = 4; i < `S_AXI_REGISTER; i = i + 1)
				begin
					//S_AXI_test_data_lite[i] = i+ 32'h45670000;
					S_AXI_test_data_lite[i] = i+ 64'h12345678ABCD0000;
				end
			  end
			else
			  begin	
				S_AXI_test_data_lite[0] = 32'h60000000;  // slv_reg0 = PCIe addr (under)
				S_AXI_test_data_lite[1] = 32'h50000000;  // slv_reg1 = PCIe addr (upper)
				S_AXI_test_data_lite[2] = 32'h40000000;  // slv_reg2 = FPGA addr
				S_AXI_test_data_lite[3] = 32'hDEADBEEF;  // slv_reg3 = reserved
				S_AXI_test_data_lite[4] = 32'd00000007;  // slv_reg4 = bytes to transfer
				S_AXI_test_data_lite[5] = 32'h12345678;  // slv_reg5 = ID
				S_AXI_test_data_lite[6] = 32'h00000000;  // slv_reg7 = CMD
				S_AXI_test_data_lite[7] = 32'hC00FFEE1;  // slv_reg6 = reserved

				for (i = 8; i < `S_AXI_REGISTER; i = i + 1)
				begin
					S_AXI_test_data_lite[i] = i+ 32'hFEDCBAAB;
				end
			  end

			/*
			// axi stream registers init
			dut.`BD_INST_NAME.slave_2.cdn_axi4_streaming_slave_bfm_inst.set_channel_level_info(1);
			mtestDATA[0] = 8'h01;
			mtestDATA[1] = 8'h02;
			mtestDATA[2] = 8'h03;
			mtestDATA[3] = 8'h04;
			mtestDATA[4] = 8'h05;
			mtestDATA[5] = 8'h06;
			mtestDATA[6] = 8'h07;
			mtestDATA[7] = 8'h08;
			*/
		end
	endtask

	task automatic DMA_TRANSFER_TEST;
		begin
			$display("---------------------------------------------------------");
			$display("Write DMA registers to start transmissions and acknowledge afterwards");
			$display("---------------------------------------------------------");


			// cmd new transfer - host memory read
			dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( `S_AXI_SLAVE_ADDRESS + 32'h18,
					     0,
					     32'h1000_0001,
					     `S_AXI_MAX_DATA_SIZE,
					     S_AXI_lite_response);

			#20000;

			// id
			dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( `S_AXI_SLAVE_ADDRESS + 32'h14,
					     0,
					     32'h33334444,
					     `S_AXI_MAX_DATA_SIZE,
					     S_AXI_lite_response);

			// cmd new transfer - host memory write
			dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( `S_AXI_SLAVE_ADDRESS + 32'h18,
					     0,
					     32'h1000_1000,
					     `S_AXI_MAX_DATA_SIZE,
					     S_AXI_lite_response);

			#20000;

			// cmd acknowledge transfer
			dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( `S_AXI_SLAVE_ADDRESS + 32'h18,
					     0,
					     32'h1001_1001,
					     `S_AXI_MAX_DATA_SIZE,
					     S_AXI_lite_response);
			#2000;
			// cmd acknowledge transfer
			dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.WRITE_BURST_CONCURRENT( `S_AXI_SLAVE_ADDRESS + 32'h18,
					     0,
					     32'h1001_1001,
					     `S_AXI_MAX_DATA_SIZE,
					     S_AXI_lite_response);
		end	
	endtask

	// Drive the BFM
	initial begin
		// Wait for end of reset
		wait(tb_ARESETN_LITE === 0) @(posedge tb_ACLK_LITE);
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);     
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);     
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE); 
    
		dut.`BD_INST_NAME.master_0.cdn_axi4_lite_master_bfm_inst.set_channel_level_info(1);		
		dut.`BD_INST_NAME.master_1.cdn_axi4_lite_master_bfm_inst.set_channel_level_info(1);

		TB_REGISTER_INIT();

		SLAVE_MEMORY_INIT();

		S_AXI_RW_REGISTER_TEST();

		DMA_TRANSFER_TEST();

		#500000;

	end

	// Drive the BFM axi stream
	/*
	initial begin
		// Wait for end of reset
		wait(tb_ARESETN_LITE === 0) @(posedge tb_ACLK_LITE);
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);     
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);     
		wait(tb_ARESETN_LITE === 1) @(posedge tb_ACLK_LITE);     

		for (j = 0; j < 8; j=j+1) begin
			steststreamID = j;
			stestDEST = j;
			stestSTRB = 4'b1111;
			stestKEEP = 4'b1111;
			dut.`BD_INST_NAME.slave_2.cdn_axi4_streaming_slave_bfm_inst.RECEIVE_TRANSFER(steststreamID,
			                          `IDVALID_FALSE,
			                          stestDEST,
			                          `DESTVALID_FALSE,
			                          steststreamID,
			                          stestDEST,
			                          stestDATA[j],
			                          stestSTRB,
			                          stestKEEP,
			                          stestLAST,
			                          stestUSER);

			COMPARE_DATA_STREAM(mtestDATA[j],stestDATA[j]);
		end

	end
	*/

endmodule
