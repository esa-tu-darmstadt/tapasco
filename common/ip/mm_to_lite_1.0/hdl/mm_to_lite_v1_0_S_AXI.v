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

	module mm_to_lite_v1_0_S_AXI #
	(
		// Users to add parameters here

		parameter integer C_M_AXI_DATA_WIDTH	= 32,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of ID for for write address, write data, read address and read data
		parameter integer C_S_AXI_ID_WIDTH	= 1,
		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 6,
		// Width of optional user defined signal in write address channel
		parameter integer C_S_AXI_AWUSER_WIDTH	= 0,
		// Width of optional user defined signal in read address channel
		parameter integer C_S_AXI_ARUSER_WIDTH	= 0,
		// Width of optional user defined signal in write data channel
		parameter integer C_S_AXI_WUSER_WIDTH	= 0,
		// Width of optional user defined signal in read data channel
		parameter integer C_S_AXI_RUSER_WIDTH	= 0,
		// Width of optional user defined signal in write response channel
		parameter integer C_S_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here

		output reg start_write,
		output reg [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr_dd,
		output reg [C_M_AXI_DATA_WIDTH-1 : 0] s_axi_wdata_dd,
		input wire end_write,

		output reg start_read,
		output reg [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr_dd,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] m_axi_rdata_dd,
		input wire end_read,


		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write Address ID
		input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_AWID,
		// Write address
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		input wire [7 : 0] S_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		input wire [2 : 0] S_AXI_AWSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		input wire [1 : 0] S_AXI_AWBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		input wire  S_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		input wire [3 : 0] S_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each
    // write transaction.
		input wire [3 : 0] S_AXI_AWQOS,
		// Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
		input wire [3 : 0] S_AXI_AWREGION,
		// Optional User-defined signal in the write address channel.
		input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] S_AXI_AWUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid write address and
    // control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
		output reg  S_AXI_AWREADY,
		// Write Data
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write last. This signal indicates the last transfer
    // in a write burst.
		input wire  S_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		input wire [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
		// Write valid. This signal indicates that valid write
    // data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    // can accept the write data.
		output reg  S_AXI_WREADY,
		// Response ID tag. This signal is the ID tag of the
    // write response.
		output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_BID,
		// Write response. This signal indicates the status
    // of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Optional User-defined signal in the write response channel.
		output wire [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
		// Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
		output reg  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    // can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address ID. This signal is the identification
    // tag for the read address group of signals.
		input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_ARID,
		// Read address. This signal indicates the initial
    // address of a read burst transaction.
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		input wire [7 : 0] S_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		input wire [2 : 0] S_AXI_ARSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		input wire [1 : 0] S_AXI_ARBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		input wire  S_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		input wire [3 : 0] S_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each
    // read transaction.
		input wire [3 : 0] S_AXI_ARQOS,
		// Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
		input wire [3 : 0] S_AXI_ARREGION,
		// Optional User-defined signal in the read address channel.
		input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] S_AXI_ARUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid read address and
    // control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
		output reg  S_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
		output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_RID,
		// Read Data
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of
    // the read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read last. This signal indicates the last transfer
    // in a read burst.
		output reg  S_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		output wire [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
		// Read valid. This signal indicates that the channel
    // is signaling the required read data.
		output reg  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    // accept the read data and response information.
		input wire  S_AXI_RREADY
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

	// used as loop-iterator
	integer i;

	// paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 4;
	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 4'b0001;
	localparam [STATE_BIT_WIDTH - 1 : 0] DATA 	= 4'b0010;
	localparam [STATE_BIT_WIDTH - 1 : 0] RESP 	= 4'b0100;
	localparam [STATE_BIT_WIDTH - 1 : 0] WAIT 	= 4'b1000;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_read;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_read;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_write;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_write;

	// switch next_state_read synchron
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
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
	reg [C_S_AXI_ID_WIDTH-1 : 0] s_axi_awid_dd;

	wire [C_M_AXI_DATA_WIDTH-1 : 0] s_axi_wdata_array [0 : (C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH)-1];
	wire [(C_M_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb_array [0 : (C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH)-1];

	assign S_AXI_BID = s_axi_awid_dd;
	assign S_AXI_BRESP = 2'b00;
	assign S_AXI_BUSER = 0;

	// convert data/strb register to 2d vector to ease access internally
	genvar j;
	generate
	  for(j=1; j <= C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH; j=j+1)
	    begin:WRITE_ARRAY
		assign s_axi_wdata_array[j-1] = S_AXI_WDATA[(j*C_M_AXI_DATA_WIDTH)-1 : ((j*C_M_AXI_DATA_WIDTH)-1)-(C_M_AXI_DATA_WIDTH-1)];
		assign s_axi_wstrb_array[j-1] = S_AXI_WSTRB[(j*C_M_AXI_DATA_WIDTH/8)-1 : ((j*C_M_AXI_DATA_WIDTH/8)-1)-(C_M_AXI_DATA_WIDTH/8-1)];
	    end
	endgenerate

	// save aw channel inputs
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_AWVALID == 1'b1 && S_AXI_AWREADY == 1'b1 )
		begin
		    s_axi_awid_dd <= S_AXI_AWID;
		    s_axi_awaddr_dd <= S_AXI_AWADDR;
		end
	  if ( S_AXI_WVALID == 1'b1 && S_AXI_WREADY == 1'b1 )
		begin
		  for(i=0; i < C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH; i=i+1)
		    begin
		      if(s_axi_wstrb_array[i] == 8'hF)
		    	s_axi_wdata_dd <= s_axi_wdata_array[i];
		    end
		end
	end

	//combinatorc logic to calculate next state_write
	//and logic to give outputs
	always @( * )
	begin
	    S_AXI_AWREADY = 1'b0;
	    S_AXI_WREADY = 1'b0;
	    S_AXI_BVALID = 1'b0;
	    start_write = 1'b0;

	    case(state_write)
		IDLE:
		    begin
	    		S_AXI_AWREADY = 1'b1;
			if(S_AXI_AWVALID == 1'b1)
			    begin
				next_state_write = DATA;
			    end
			else
			    begin
		    		next_state_write = IDLE;
			    end
		    end
		DATA:
		    begin
	    		S_AXI_WREADY = 1'b1;
			if(S_AXI_WVALID == 1'b1)
			    begin
	    			start_write = 1'b1;
				next_state_write = RESP;
			    end
			else
			    begin
		    		next_state_write = DATA;
			    end
		    end
		RESP:
		    begin	
	    		S_AXI_BVALID = 1'b1;
			if(S_AXI_BREADY == 1'b1)
			    begin
				next_state_write = WAIT;
			    end
			else
			    begin
		    		next_state_write = RESP;
			    end
		    end
		WAIT:
		    begin
			if(end_write == 1'b1)
			    begin
				next_state_write = IDLE;
			    end
			else
			    begin
		    		next_state_write = WAIT;
			    end
		    end
		default:
		    next_state_write = IDLE;
	    endcase
	end

	//--------------------
	// Read Channel
	//--------------------

	// Fixed Values for Read Transfers
	reg [C_S_AXI_ID_WIDTH-1 : 0] s_axi_arid_dd;
	assign S_AXI_RID = s_axi_arid_dd;
	assign S_AXI_RRESP = 2'b00;
	assign S_AXI_RUSER = 0;

	reg [C_M_AXI_DATA_WIDTH-1 : 0] s_axi_rdata_array [0 : (C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH)-1];

	// convert data register to 2d vector to ease access internally
	genvar k;
	generate
	  for(k=1; k <= C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH; k=k+1)
	    begin:READ_ARRAY
		assign S_AXI_RDATA[(k*C_M_AXI_DATA_WIDTH)-1 : ((k*C_M_AXI_DATA_WIDTH)-1)-(C_M_AXI_DATA_WIDTH-1)] = s_axi_rdata_array[k-1];
	    end
	endgenerate

	// save ar channel inputs
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARVALID == 1'b1 && S_AXI_ARREADY == 1'b1 )
		begin
		    s_axi_arid_dd <= S_AXI_ARID;
		    s_axi_araddr_dd <= S_AXI_ARADDR;
		end
	  begin
	    for(i=0; i < C_S_AXI_DATA_WIDTH/C_M_AXI_DATA_WIDTH; i=i+1)
	      begin
	        if(s_axi_araddr_dd[4:0] == i*4)
	    	  s_axi_rdata_array[i] <= m_axi_rdata_dd;
		else
	    	  s_axi_rdata_array[i] <= 0;
		  
	    end
	  end
	end

	//combinatorc logic to calculate next state_read
	//and logic to give outputs
	always @( * )
	begin
	    S_AXI_ARREADY = 1'b0;
	    S_AXI_RVALID = 1'b0;
	    S_AXI_RLAST = 1'b0;
	    start_read = 1'b0;

	    case(state_read)
		IDLE:
		    begin
	    		S_AXI_ARREADY = 1'b1;
			if(S_AXI_ARVALID == 1'b1)
			    begin
	    			start_read = 1'b1;
				next_state_read = WAIT;
			    end
			else
			    begin
		    		next_state_read = IDLE;
			    end
		    end
		WAIT:
		    begin
			if(end_read == 1'b1)
			    begin
				next_state_read = RESP;
			    end
			else
			    begin
		    		next_state_read = WAIT;
			    end
		    end
		// bubble cycle to wait for data register update
		RESP:
		    begin
			next_state_read = DATA;
		    end
		DATA:
		    begin
	    		S_AXI_RVALID = 1'b1;
			if(S_AXI_RREADY == 1'b1)
			    begin
	    			S_AXI_RLAST = 1'b1;
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
