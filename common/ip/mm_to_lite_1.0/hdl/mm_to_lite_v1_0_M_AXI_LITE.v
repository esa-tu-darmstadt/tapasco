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

	module mm_to_lite_v1_0_M_AXI_LITE #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// The master requires a target slave base address.
    // The master will initiate read and write transactions on the slave with base address specified here as a parameter.
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		// Width of M_AXI address bus. 
    // The master generates the read and write addresses of width specified as C_M_AXI_ADDR_WIDTH.
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		// Width of M_AXI data bus. 
    // The master issues write data and accept read data where the width of the data bus is C_M_AXI_DATA_WIDTH
		parameter integer C_M_AXI_DATA_WIDTH	= 32
	)
	(
		// Users to add ports here

		input wire start_write,
		input wire [C_M_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr_dd,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] s_axi_wdata_dd,
		output reg end_write,

		input wire start_read,
		input wire [C_M_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr_dd,
		output reg [C_M_AXI_DATA_WIDTH-1 : 0] m_axi_rdata_dd,
		output reg end_read,

		// User ports ends
		// Do not modify the ports beyond this line

		// AXI clock signal
		input wire  M_AXI_ACLK,
		// AXI active low reset signal
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address Channel ports. Write address (issued by master)
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Write channel Protection type.
    // This signal indicates the privilege and security level of the transaction,
    // and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Write address valid. 
    // This signal indicates that the master signaling valid write address and control information.
		output reg  M_AXI_AWVALID,
		// Write address ready. 
    // This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data Channel ports. Write data (issued by master)
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes. 
    // This signal indicates which byte lanes hold valid data.
    // There is one write strobe bit for each eight bits of the write data bus.
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write valid. This signal indicates that valid write data and strobes are available.
		output reg  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response Channel ports. 
    // This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Write response valid. 
    // This signal indicates that the channel is signaling a valid write response
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master can accept a write response.
		output reg  M_AXI_BREADY,
		// Master Interface Read Address Channel ports. Read address (issued by master)
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Protection type. 
    // This signal indicates the privilege and security level of the transaction, 
    // and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Read address valid. 
    // This signal indicates that the channel is signaling valid read address and control information.
		output reg  M_AXI_ARVALID,
		// Read address ready. 
    // This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_ARREADY,
		// Master Interface Read Data Channel ports. Read data (issued by slave)
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer.
		input wire [1 : 0] M_AXI_RRESP,
		// Read valid. This signal indicates that the channel is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can accept the read data and response information.
		output reg  M_AXI_RREADY
	);
                                              
	// Add user logic here

	// function called clogb2 that returns an integer which has the 
	// value of the ceiling of the log base 2.                      
	function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	  for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	    bit_depth = bit_depth >> 1;                                 
	  end                                                           
	endfunction 

	//localparam integer BYTES_PER_BEAT = C_M_AXI_DATA_WIDTH/8;

	// paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 5;
	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 5'b00001;
	localparam [STATE_BIT_WIDTH - 1 : 0] ALL 	= 5'b00010;
	localparam [STATE_BIT_WIDTH - 1 : 0] ADDR 	= 5'b00100;
	localparam [STATE_BIT_WIDTH - 1 : 0] DATA 	= 5'b01000;
	localparam [STATE_BIT_WIDTH - 1 : 0] RESP 	= 5'b10000;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_read;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_read;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_write;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_write;

	// switch next_state_read synchron
	always @( posedge M_AXI_ACLK )
	begin
	  if ( M_AXI_ARESETN == 1'b0 )
		begin
		    state_read <= IDLE;
		    state_write <= IDLE;
		end
	  else
		begin
		    state_read <= next_state_read;
		    state_write <= next_state_write;
		end
	end

	//--------------------
	// Write Channel
	//--------------------

	// Fixed Values for Write Transfers
	assign M_AXI_WSTRB = {C_M_AXI_DATA_WIDTH/8{1'b1}};
	assign M_AXI_AWPROT = 3'b000;

	assign M_AXI_AWADDR = s_axi_awaddr_dd;
	assign M_AXI_WDATA = s_axi_wdata_dd;

	//combinatorc logic to calculate next state_write
	//and logic to give outputs
	always @( * )
	begin
	    M_AXI_AWVALID = 1'b0;
	    M_AXI_WVALID = 1'b0;
	    M_AXI_BREADY = 1'b0;
	    end_write = 1'b0;

	    case(state_write)
		IDLE:
		    begin
			if(start_write == 1'b1)
			    begin
				next_state_write = ALL;
			    end
			else
			    begin
		    		next_state_write = IDLE;
			    end
		    end
		ALL:
		    begin
	    		M_AXI_AWVALID = 1'b1;
	    		M_AXI_WVALID = 1'b1;
			if(M_AXI_AWREADY == 1'b1 && M_AXI_WREADY == 1'b1)
			    begin
				next_state_write = RESP;
			    end
			else if(M_AXI_AWREADY == 1'b1)
			    begin
				next_state_write = DATA;
			    end
			else if(M_AXI_WREADY == 1'b1)
			    begin
				next_state_write = ADDR;
			    end
			else
			    begin
		    		next_state_write = ALL;
			    end
		    end
		ADDR:
		    begin
	    		M_AXI_AWVALID = 1'b1;
			if(M_AXI_AWREADY == 1'b1)
			    begin
				next_state_write = RESP;
			    end
			else
			    begin
		    		next_state_write = ADDR;
			    end
		    end
		DATA:
		    begin
	    		M_AXI_WVALID = 1'b1;
			if(M_AXI_WREADY == 1'b1)
			    begin
				next_state_write = RESP;
			    end
			else
			    begin
		    		next_state_write = DATA;
			    end
		    end
		RESP:
		    begin
	    		M_AXI_BREADY = 1'b1;
			if(M_AXI_BVALID == 1'b1)
			    begin
	    			end_write = 1'b1;
				next_state_write = IDLE;
			    end
			else
			    begin
		    		next_state_write = RESP;
			    end
		    end
		default:
		    next_state_write = IDLE;
	    endcase
	end

	//--------------------
	// Read Channel
	//--------------------

	// Fixed Values for Write Transfers
	assign M_AXI_ARPROT = 3'b000;
	assign M_AXI_ARADDR = s_axi_araddr_dd;

	// save read channel inputs
	always @( posedge M_AXI_ACLK )
	begin
	  if ( M_AXI_RVALID == 1'b1 && M_AXI_RREADY == 1'b1 )
		begin
		    m_axi_rdata_dd <= M_AXI_RDATA;
		end
	end

	//combinatorc logic to calculate next state_read
	//and logic to give outputs
	always @( * )
	begin
	    M_AXI_ARVALID = 1'b0;
	    M_AXI_RREADY = 1'b0;
	    end_read = 1'b0;

	    case(state_read)
		IDLE:
		    begin
			if(start_read == 1'b1)
			    begin
				next_state_read = ALL;
			    end
			else
			    begin
		    		next_state_read = IDLE;
			    end
		    end
		ALL:
		    begin
	    		M_AXI_ARVALID = 1'b1;
	    		M_AXI_RREADY = 1'b1;
			if(M_AXI_ARREADY == 1'b1 && M_AXI_RVALID == 1'b1)
			    begin
	    			end_read = 1'b1;
				next_state_read = IDLE;
			    end
			else if(M_AXI_ARREADY == 1'b1)
			    begin
				next_state_read = DATA;
			    end
			else if(M_AXI_RVALID == 1'b1)
			    begin
				next_state_read = ADDR;
			    end
			else
			    begin
		    		next_state_read = ALL;
			    end
		    end
		ADDR:
		    begin
	    		M_AXI_ARVALID = 1'b1;
			if(M_AXI_ARREADY == 1'b1)
			    begin
	    			end_read = 1'b1;
				next_state_read = IDLE;
			    end
			else
			    begin
		    		next_state_read = ADDR;
			    end
		    end
		DATA:
		    begin
	    		M_AXI_RREADY = 1'b1;
			if(M_AXI_RVALID == 1'b1)
			    begin
	    			end_read = 1'b1;
				next_state_read = IDLE;
			    end
			else
			    begin
		    		next_state_read = DATA;
			    end
		    end
		default:
		    next_state_read = IDLE;
	    endcase
	end

	// User logic ends

	endmodule
