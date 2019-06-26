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

`include "mm_to_lite_v1_0_tb_include.vh"

// Burst Size Defines
`define BURST_SIZE_4_BYTES   3'b010

// Lock Type Defines
`define LOCK_TYPE_NORMAL    1'b0

// lite_response Type Defines
`define RESPONSE_OKAY 2'b00
`define RESPONSE_EXOKAY 2'b01
`define RESP_BUS_WIDTH 2
`define BURST_TYPE_INCR  2'b01
`define BURST_TYPE_WRAP  2'b10

// AMBA S_AXI AXI4 Range Constants
`define S_AXI_MAX_BURST_LENGTH 8'b1111_1111
`define S_AXI_MAX_DATA_SIZE (`S_AXI_DATA_BUS_WIDTH*(`S_AXI_MAX_BURST_LENGTH+1))/8
`define S_AXI_DATA_BUS_WIDTH 256
`define S_AXI_ADDRESS_BUS_WIDTH 32
`define S_AXI_RUSER_BUS_WIDTH 1
`define S_AXI_WUSER_BUS_WIDTH 1


module mm_to_lite_v1_0_tb;
	reg tb_ACLK;
	reg tb_ARESETn;

	// Create an instance of the example tb
	`BD_WRAPPER dut (.ACLK(tb_ACLK),
				.ARESETN(tb_ARESETn));

	// Local Variables

	// AMBA S_AXI AXI4 Local Reg
	reg [(`S_AXI_DATA_BUS_WIDTH*(`S_AXI_MAX_BURST_LENGTH+1)/16)-1:0] S_AXI_rd_data;
	reg [(`S_AXI_DATA_BUS_WIDTH*(`S_AXI_MAX_BURST_LENGTH+1)/16)-1:0] S_AXI_test_data [2:0];
	reg [(`RESP_BUS_WIDTH*(`S_AXI_MAX_BURST_LENGTH+1))-1:0] S_AXI_vresponse;
	reg [`S_AXI_ADDRESS_BUS_WIDTH-1:0] S_AXI_mtestAddress;
	reg [(`S_AXI_RUSER_BUS_WIDTH*(`S_AXI_MAX_BURST_LENGTH+1))-1:0] S_AXI_v_ruser;
	reg [(`S_AXI_WUSER_BUS_WIDTH*(`S_AXI_MAX_BURST_LENGTH+1))-1:0] S_AXI_v_wuser;
	reg [`RESP_BUS_WIDTH-1:0] S_AXI_response;
	integer  S_AXI_mtestID; // Master side testID
	integer  S_AXI_mtestBurstLength;
	integer  S_AXI_mtestvector; // Master side testvector
	integer  S_AXI_mtestdatasize;
	integer  S_AXI_mtestCacheType = 0;
	integer  S_AXI_mtestProtectionType = 0;
	integer  S_AXI_mtestRegion = 0;
	integer  S_AXI_mtestQOS = 0;
	integer  S_AXI_mtestAWUSER = 0;
	integer  S_AXI_mtestARUSER = 0;
	integer  S_AXI_mtestBUSER = 0;
	integer result_slave_full;

	reg [`S_AXI_DATA_BUS_WIDTH-1:0] test_data;
	reg [`S_AXI_DATA_BUS_WIDTH-1:0] s_axi_read_data;

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
	// TEST LEVEL API: COMPARE_DATA
	//------------------------------------------------------------------------
	// Description:
	// COMPARE_DATA(expected,actual)
	// This task checks if the actual data is equal to the expected data.
	// X is used as don't care but it is not permitted for the full vector
	// to be don't care.
	//------------------------------------------------------------------------
	//`define S_AXI_DATA_BUS_WIDTH 32 
	task automatic COMPARE_DATA;
		input [`S_AXI_DATA_BUS_WIDTH-1:0]expected;
		input [`S_AXI_DATA_BUS_WIDTH-1:0]actual;
		begin
			if (expected === 'hx || actual === 'hx) begin
				$display("TESTBENCH ERROR! COMPARE_DATA cannot be performed with an expected or actual vector that is all 'x'!");
		    result_slave_full = 0;
		    $stop;
		  end

			if (actual != expected) begin
				$display("TESTBENCH ERROR! Data expected is not equal to actual.",
				         "\n expected = 0x%h",expected,
				         "\n actual   = 0x%h",actual);
		    result_slave_full = 0;
		    $stop;
		  end
			else 
			begin
			   $display("TESTBENCH Passed! Data expected is equal to actual.",
			            "\n expected = 0x%h",expected,
			            "\n actual   = 0x%h",actual);
			end
		end
	endtask

	task automatic S_AXI_TEST;
		begin
			//---------------------------------------------------------------------
			// EXAMPLE TEST 1:
			// Simple sequential write and read burst transfers example
			// DESCRIPTION:
			// The following master code does a simple write and read burst for
			// each burst transfer type.
			//---------------------------------------------------------------------
			$display("---------------------------------------------------------");
			$display("EXAMPLE TEST S_AXI:");
			$display("Simple sequential write and read burst transfers example");
			$display("---------------------------------------------------------");
			
			S_AXI_mtestID = 1;
			S_AXI_mtestvector = 0;
			S_AXI_mtestBurstLength = 15;
			S_AXI_mtestAddress = `S_AXI_SLAVE_ADDRESS;
			S_AXI_mtestCacheType = 0;
			S_AXI_mtestProtectionType = 0;
			S_AXI_mtestdatasize = `S_AXI_MAX_DATA_SIZE;
			S_AXI_mtestRegion = 0;
			S_AXI_mtestQOS = 0;
			S_AXI_mtestAWUSER = 0;
			S_AXI_mtestARUSER = 0;
			 result_slave_full = 1;
			
			dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.WRITE_BURST_CONCURRENT(S_AXI_mtestID,
			                        S_AXI_mtestAddress,
			                        S_AXI_mtestBurstLength,
			                        `BURST_SIZE_4_BYTES,
			                        `BURST_TYPE_INCR,
			                        `LOCK_TYPE_NORMAL,
			                        S_AXI_mtestCacheType,
			                        S_AXI_mtestProtectionType,
			                        S_AXI_test_data[S_AXI_mtestvector],
			                        S_AXI_mtestdatasize,
			                        S_AXI_mtestRegion,
			                        S_AXI_mtestQOS,
			                        S_AXI_mtestAWUSER,
			                        S_AXI_v_wuser,
			                        S_AXI_response,
			                        S_AXI_mtestBUSER);
			$display("EXAMPLE TEST 1 : DATA = 0x%h, response = 0x%h",S_AXI_test_data[S_AXI_mtestvector],S_AXI_response);
			CHECK_RESPONSE_OKAY(S_AXI_response);
			S_AXI_mtestID = S_AXI_mtestID+1;
			dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.READ_BURST(S_AXI_mtestID,
			                       S_AXI_mtestAddress,
			                       S_AXI_mtestBurstLength,
			                       `BURST_SIZE_4_BYTES,
			                       `BURST_TYPE_WRAP,
			                       `LOCK_TYPE_NORMAL,
			                       S_AXI_mtestCacheType,
			                       S_AXI_mtestProtectionType,
			                       S_AXI_mtestRegion,
			                       S_AXI_mtestQOS,
			                       S_AXI_mtestARUSER,
			                       S_AXI_rd_data,
			                       S_AXI_vresponse,
			                       S_AXI_v_ruser);
			$display("EXAMPLE TEST 1 : DATA = 0x%h, vresponse = 0x%h",S_AXI_rd_data,S_AXI_vresponse);
			CHECK_RESPONSE_OKAY(S_AXI_vresponse);
			// Check that the data received by the master is the same as the test 
			// vector supplied by the slave.
			COMPARE_DATA(S_AXI_test_data[S_AXI_mtestvector],S_AXI_rd_data);

			$display("EXAMPLE TEST 1 : Sequential write and read FIXED burst transfers complete from the master side.");
			$display("---------------------------------------------------------");
			$display("EXAMPLE TEST S_AXI: PTGEN_TEST_FINISHED!");
				if ( result_slave_full ) begin				   
					$display("PTGEN_TEST: PASSED!");                 
				end	else begin                                         
					$display("PTGEN_TEST: FAILED!");                 
				end							   
			$display("---------------------------------------------------------");
		end
	endtask 

	//------------------------------------------------------------------------
	// TEST LEVEL API: WRITE_STROBE
	//------------------------------------------------------------------------
	task automatic WRITE_STROBE;
		input [`S_AXI_ADDRESS_BUS_WIDTH-1:0] addr;
		input [`S_AXI_DATA_BUS_WIDTH-1:0] data;
		input [(`S_AXI_DATA_BUS_WIDTH/8)-1:0] strb;
		begin
			
			S_AXI_mtestBurstLength = 0;
			S_AXI_mtestAddress = `S_AXI_SLAVE_ADDRESS + addr;

			S_AXI_mtestID = 1;
			S_AXI_mtestCacheType = 0;
			S_AXI_mtestProtectionType = 0;
			S_AXI_mtestRegion = 0;
			S_AXI_mtestQOS = 0;
			S_AXI_mtestAWUSER = 0;
			S_AXI_mtestARUSER = 0;

			// write data with strobe enabled
			dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.SEND_WRITE_ADDRESS(
					S_AXI_mtestID,
					S_AXI_mtestAddress,
					S_AXI_mtestBurstLength,
					3'b010, //size - 4 Byte
					`BURST_TYPE_INCR,
					`LOCK_TYPE_NORMAL,
					S_AXI_mtestCacheType,
					S_AXI_mtestProtectionType,
					S_AXI_mtestRegion,
					S_AXI_mtestQOS,
					S_AXI_mtestAWUSER);   
		                                            
			dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.SEND_WRITE_DATA(
					strb,
					data,
					1'b1, //last
					S_AXI_v_wuser);   
		                                                                                                                 
			dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.RECEIVE_WRITE_RESPONSE(
					S_AXI_mtestID,
					S_AXI_response,
					S_AXI_mtestBUSER);
			$display("EXAMPLE TEST STRB : DATA = 0x%h, response = 0x%h",data,S_AXI_response);
		end
	endtask

	//------------------------------------------------------------------------
	// TEST LEVEL API: READ_OUT
	//------------------------------------------------------------------------
	task automatic READ_OUT;
		input [`S_AXI_ADDRESS_BUS_WIDTH-1:0] addr;
		begin
			S_AXI_mtestBurstLength = 0;
			S_AXI_mtestAddress = `S_AXI_SLAVE_ADDRESS + addr;

			S_AXI_mtestID = 1;
			S_AXI_mtestCacheType = 0;
			S_AXI_mtestProtectionType = 0;
			S_AXI_mtestRegion = 0;
			S_AXI_mtestQOS = 0;
			S_AXI_mtestARUSER = 0;

			s_axi_read_data = 0;

			dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.READ_BURST(
					S_AXI_mtestID,
					S_AXI_mtestAddress,
					S_AXI_mtestBurstLength,
					3'b010, //size - 4 Byte
					`BURST_TYPE_INCR,
					`LOCK_TYPE_NORMAL,
					S_AXI_mtestCacheType,
					S_AXI_mtestProtectionType,
					S_AXI_mtestRegion,
					S_AXI_mtestQOS,
					S_AXI_mtestARUSER,
					s_axi_read_data,
					S_AXI_vresponse,
					S_AXI_v_ruser);          

			$display("EXAMPLE TEST READ : DATA = 0x%h, vresponse = 0x%h", s_axi_read_data, S_AXI_vresponse);
		end
	endtask

	// Create the test vectors
	initial begin
		// When performing debug enable all levels of INFO messages.
		wait(tb_ARESETn === 0) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);  

		dut.`BD_INST_NAME.master_0.cdn_axi4_master_bfm_inst.set_channel_level_info(1);

		// Create test data vectors
		S_AXI_test_data[1] = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
		S_AXI_test_data[0] = 512'h00abcdef111111112222222233333333444444445555555566666666777777778888888899999999AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDDEEEEEEEEFFFFFFFF;
		S_AXI_test_data[2] = 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
		S_AXI_v_ruser = 0;
		S_AXI_v_wuser = 0;
	end

	// Drive the BFM
	initial begin
		// Wait for end of reset
		wait(tb_ARESETn === 0) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     
		wait(tb_ARESETn === 1) @(posedge tb_ACLK);     

		#100
		$display("EXAMPLE TEST M_AXI_LITE:");
		#100
		test_data[255:0] = 0;
		//WRITE_STROBE(32'h0, test_data, 32'hFFFFFFFF);
		//READ_OUT(32'h0);

		test_data[255:0] = 256'h12345678ABCDEFAB;
		WRITE_STROBE(32'h44A00000, test_data, 32'hF);
		#20;
		READ_OUT(32'h44A00000);
		#20;

		test_data[255:0] = 256'hC0C0C0C0A0A0A0A0;
		WRITE_STROBE(32'h44A00004, test_data, 32'hF0);
		#20;
		READ_OUT(32'h44A00004);
		#20;

		#100
		$display("M_AXI_LITE: PTGEN_TEST_FINISHED!");
		if ( 1'b0 ) begin
		  $display("PTGEN_TEST: FAILED!");
		end else begin
		  $display("PTGEN_TEST: PASSED!");
		end

	end

endmodule
