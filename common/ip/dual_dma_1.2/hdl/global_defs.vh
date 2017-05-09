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
`ifndef _GLOBAL_DEFS_vh_
`define _GLOBAL_DEFS_vh_

// common defines of modules
`define TEST_DEFINE 1000 //for testing

// width of one command in fifo
`define CMD_64_FIFO_WIDTH 128 // address + btt + id
`define CMD_32_FIFO_WIDTH 96 // address + btt + id
`define CMD_STR_FIFO_WIDTH 64 // btt + id

// width of return status in fifo
`define STS_64_FIFO_WIDTH 32 // id
`define STS_32_FIFO_WIDTH 32 // id
`define STS_STR_FIFO_WIDTH 32 // id

// define commands for user registers
`define CMD_READ	32'h1000_1000 // from m32 fpga memory to m64 host memory
`define CMD_WRITE	32'h1000_0001 // from m64 host memory to m32 fpga memory
`define CMD_ACK		32'h1001_1001 // acknowledge data transfer to toggle interrupt

// define commands for FSMs
`define CMD_DEFAULT	32'h9999_8888

// kind of wrapper between 2D and 1D vectors
`define FLATTEN_ARRAY(SRC, DEST, WIDTH, COUNT) genvar flatten; generate for(flatten = 1; flatten <= COUNT; flatten = flatten + 1) begin:FLATTEN; assign DEST[(flatten * WIDTH) - 1 : ((flatten * WIDTH) - 1) - (WIDTH - 1)] = SRC[flatten - 1]; end; endgenerate

`define UNFLATTEN_ARRAY(SRC, DEST, WIDTH, COUNT) genvar unflatten; generate for(unflatten = 1; unflatten <= COUNT; unflatten = unflatten + 1) begin:UNFLATTEN; assign DEST[unflatten - 1] = SRC[(unflatten * WIDTH) - 1 : ((unflatten * WIDTH) - 1) - (WIDTH - 1)]; end; endgenerate

// to be able to use flatten_array two times in one module
`define FLATTEN_ARRAY_2(SRC, DEST, WIDTH, COUNT) genvar flatten_2; generate for(flatten_2 = 1; flatten_2 <= COUNT; flatten_2 = flatten_2 + 1) begin:FLATTEN_2; assign DEST[(flatten_2 * WIDTH) - 1 : ((flatten_2 * WIDTH) - 1) - (WIDTH - 1)] = SRC[flatten_2 - 1]; end; endgenerate

`define UNFLATTEN_ARRAY_2(SRC, DEST, WIDTH, COUNT) genvar unflatten_2; generate for(unflatten_2 = 1; unflatten_2 <= COUNT; unflatten_2 = unflatten_2 + 1) begin:UNFLATTEN_2; assign DEST[unflatten_2 - 1] = SRC[(unflatten_2 * WIDTH) - 1 : ((unflatten_2 * WIDTH) - 1) - (WIDTH - 1)]; end; endgenerate

`define UNFLATTEN_ARRAY_3(SRC, DEST, WIDTH, COUNT) genvar unflatten_3; generate for(unflatten_3 = 1; unflatten_3 <= COUNT; unflatten_3 = unflatten_3 + 1) begin:UNFLATTEN_3; assign DEST[unflatten_3 - 1] = SRC[(unflatten_3 * WIDTH) - 1 : ((unflatten_3 * WIDTH) - 1) - (WIDTH - 1)]; end; endgenerate

// push to verilog files where used
	/*
	//paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 4;
	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 4'b0000;
	localparam [STATE_BIT_WIDTH - 1 : 0] START 	= 4'b0001;
	localparam [STATE_BIT_WIDTH - 1 : 0] READY 	= 4'b0010;
	localparam [STATE_BIT_WIDTH - 1 : 0] INTR 	= 4'b0011;
	localparam [STATE_BIT_WIDTH - 1 : 0] DONE 	= 4'b0100;
	localparam [STATE_BIT_WIDTH - 1 : 0] SAMPLE 	= 4'b0101;
	*/

`endif	//_LCU_GLOBAL_DEFINE_vh_
