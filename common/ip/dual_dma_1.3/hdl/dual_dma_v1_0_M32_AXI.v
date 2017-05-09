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

	module dual_dma_v1_0_M32_AXI #
	(
		// Users to add parameters here

		parameter integer C_M_AXI_CMD_32_WIDTH	= 32,
		parameter integer C_M_AXI_STS_32_WIDTH	= 32,

		parameter integer READ_MAX_REQ	= 4,
		parameter integer WRITE_MAX_REQ	= 4,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		parameter integer C_M_AXI_BURST_LEN	= 16,
		// Thread ID Width
		parameter integer C_M_AXI_ID_WIDTH	= 1,
		// Width of Address Bus
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		// Width of Data Bus
		parameter integer C_M_AXI_DATA_WIDTH	= 32,
		// Width of User Write Address Bus
		parameter integer C_M_AXI_AWUSER_WIDTH	= 1,
		// Width of User Read Address Bus
		parameter integer C_M_AXI_ARUSER_WIDTH	= 1,
		// Width of User Write Data Bus
		parameter integer C_M_AXI_WUSER_WIDTH	= 1,
		// Width of User Read Data Bus
		parameter integer C_M_AXI_RUSER_WIDTH	= 1,
		// Width of User Response Bus
		parameter integer C_M_AXI_BUSER_WIDTH	= 1
	)
	(
		// Users to add ports here

		// signal from cmd fifo for 32 bit engine
		input wire cmd_read_m32_m_axis_tvalid,
		output reg cmd_read_m32_m_axis_tready,
		input wire [C_M_AXI_CMD_32_WIDTH - 1 : 0] cmd_read_m32_m_axis_tdata,

		input wire cmd_write_m32_m_axis_tvalid,
		output reg cmd_write_m32_m_axis_tready,
		input wire [C_M_AXI_CMD_32_WIDTH - 1 : 0] cmd_write_m32_m_axis_tdata,

		// signal from sts fifos for slave register
		output reg sts_read_m32_s_axis_tvalid,
		input wire sts_read_m32_s_axis_tready,
		output reg [C_M_AXI_STS_32_WIDTH - 1 : 0] sts_read_m32_s_axis_tdata,

		output reg sts_write_m32_s_axis_tvalid,
		input wire sts_write_m32_s_axis_tready,
		output reg [C_M_AXI_STS_32_WIDTH - 1 : 0] sts_write_m32_s_axis_tdata,

		output reg [C_M_AXI_DATA_WIDTH/8-1 : 0] m32_to_m64_cdc_s_axis_tstrb,

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal.
		input wire  M_AXI_ACLK,
		// Global Reset Singal. This Signal is Active Low
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address ID
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		// Master Interface Write Address
		output reg [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output reg [7 : 0] M_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_AWSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_AWBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each write transaction.
		output wire [3 : 0] M_AXI_AWQOS,
		// Optional User-defined signal in the write address channel.
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid write address and control information.
		output reg  M_AXI_AWVALID,
		// Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data.
		//output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
		//output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write last. This signal indicates the last transfer in a write burst.
		input wire  M_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		// Write valid. This signal indicates that valid write
    // data and strobes are available
		input wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    // can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		// Write response. This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Optional User-defined signal in the write response channel
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		// Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master
    // can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address.
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		// Read address. This signal indicates the initial
    // address of a read burst transaction.
		output reg [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output reg [7 : 0] M_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_ARSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_ARBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each read transaction
		output wire [3 : 0] M_AXI_ARQOS,
		// Optional User-defined signal in the read address channel.
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid read address and control information
		output reg  M_AXI_ARVALID,
		// Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		// Master Read Data
		//input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer
		input wire [1 : 0] M_AXI_RRESP,
		// Read last. This signal indicates the last transfer in a read burst
		input wire  M_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		// Read valid. This signal indicates that the channel
    // is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    // accept the read data and response information.
		input wire  M_AXI_RREADY
	);

	`include "global_defs.vh"

	// function called clogb2 that returns an integer which has the
	//value of the ceiling of the log base 2

	  // function called clogb2 that returns an integer which has the 
	  // value of the ceiling of the log base 2.                      
	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction 

	// Add user logic here

	integer i;
	reg [31 : 0] read_counter;

	localparam integer BYTES_PER_BEAT = C_M_AXI_DATA_WIDTH/8;
	localparam integer BYTES_PER_BURST = C_M_AXI_BURST_LEN*BYTES_PER_BEAT;

	// paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 4;
	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 4'b0001;
	localparam [STATE_BIT_WIDTH - 1 : 0] BURST 	= 4'b0010;
	localparam [STATE_BIT_WIDTH - 1 : 0] WAIT 	= 4'b0100;
	localparam [STATE_BIT_WIDTH - 1 : 0] DONE 	= 4'b1000;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_read;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_read;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_write;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_write;

	reg load_read_registers;
	reg incr_read_registers;
	reg [31:0] 				read_length;
	reg [7:0] 				read_outstanding_requests;

	reg load_write_registers;
	reg incr_write_registers;
	reg [31:0] 				write_length;
	reg [7:0] 				write_outstanding_requests;

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
	//Write Address Channel
	//--------------------

	//combinatorc logic to calculate next state_write
	//and logic to give outputs
	always @( * )
	begin
	    M_AXI_AWVALID = 1'b0;
	    cmd_write_m32_m_axis_tready = 1'b0;
	    sts_write_m32_s_axis_tvalid = 1'b0;
	    load_write_registers = 1'b0;
	    incr_write_registers = 1'b0;

	    case(state_write)
		IDLE:
		    begin
			if(cmd_write_m32_m_axis_tvalid == 1'b1)
			    begin				
	    			cmd_write_m32_m_axis_tready = 1'b1;			
	    			load_write_registers = 1'b1;
				next_state_write = BURST;
			    end
			else
			    begin
		    		next_state_write = IDLE;
			    end
		    end
		BURST:
		    begin
			if(write_length == 0)
			    begin
				next_state_write = DONE;
			    end
			else if(M_AXI_AWREADY == 1'b1)
			    begin
				M_AXI_AWVALID = 1'b1;
	    			incr_write_registers = 1'b1;
				next_state_write = WAIT;
			    end
			else
			    begin
		    		next_state_write = BURST;
			    end
		    end
		WAIT:
		    begin
			if(write_outstanding_requests < WRITE_MAX_REQ)
			    begin
				next_state_write = BURST;
			    end
			else
			    begin
		    		next_state_write = WAIT;
			    end
		    end
		DONE:
		    begin
			if(write_outstanding_requests == 0 && sts_write_m32_s_axis_tready == 1'b1)
			    begin
				sts_write_m32_s_axis_tvalid = 1'b1;
				next_state_write = IDLE;
			    end
			else
			    begin
		    		next_state_write = DONE;
			    end
		    end
		default:
		    next_state_write = IDLE;
	    endcase
	end

	// Burst length counter and
	// Address incrementing
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        M_AXI_AWADDR	<= 0;
	        M_AXI_AWLEN	<= 0;
		write_length <= 0;
		sts_write_m32_s_axis_tdata 	<= 0;
	      end
	    else
		if (load_write_registers == 1'b1)
	      	    begin
	        	M_AXI_AWADDR <= cmd_write_m32_m_axis_tdata[95:64];
	        	write_length <= cmd_write_m32_m_axis_tdata[63:32];
	        	sts_write_m32_s_axis_tdata <= cmd_write_m32_m_axis_tdata[31:0];
			if(cmd_write_m32_m_axis_tdata[63:32] >= BYTES_PER_BURST)
	        		M_AXI_AWLEN <= C_M_AXI_BURST_LEN - 1;
			else
			   begin
			      if(cmd_write_m32_m_axis_tdata[clogb2(BYTES_PER_BEAT)+30:32] > 0) 
	        		M_AXI_AWLEN <= cmd_write_m32_m_axis_tdata[63:32] / BYTES_PER_BEAT;
			      else
	        		M_AXI_AWLEN <= cmd_write_m32_m_axis_tdata[63:32] / BYTES_PER_BEAT - 1;
			   end
	    	    end
		if (incr_write_registers == 1'b1)
	      	    begin
	        	M_AXI_AWADDR <= M_AXI_AWADDR + (M_AXI_AWLEN + 1) * BYTES_PER_BEAT;
			if(write_length < BYTES_PER_BURST)
			   begin
	        		write_length <= 0;
	        		M_AXI_AWLEN <= 0;
			   end
			else if(write_length >= 2 * BYTES_PER_BURST)
			   begin
	        		write_length <= write_length - (M_AXI_AWLEN + 1) * BYTES_PER_BEAT;
	        		M_AXI_AWLEN <= C_M_AXI_BURST_LEN - 1;
			   end
			else
			   begin
	        		write_length <= write_length - (M_AXI_AWLEN + 1) * BYTES_PER_BEAT;
				if(write_length[clogb2(BYTES_PER_BEAT)-2:0] > 0)
	        		   M_AXI_AWLEN <= (write_length - BYTES_PER_BURST) / BYTES_PER_BEAT;
				else
	        		   M_AXI_AWLEN <= (write_length - BYTES_PER_BURST) / BYTES_PER_BEAT - 1;
			   end
	    	    end
	  end

	// count cycles between awvalid and wready
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        write_outstanding_requests <= 0;
	      end
	    else
		if(M_AXI_AWVALID == 1'b1 && M_AXI_BVALID == 1'b1)
			write_outstanding_requests <= write_outstanding_requests;
		else if(M_AXI_AWVALID == 1'b1)
			write_outstanding_requests <= write_outstanding_requests + 1'b1;
		else if(M_AXI_BVALID == 1'b1)
			write_outstanding_requests <= write_outstanding_requests - 1'b1;
	  end

	// Fixed Values for Write Transfers
	assign M_AXI_AWID	= 1'b0;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1); //3'b0;
	assign M_AXI_AWBURST	= 2'b01; // INCR Burst Type
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'b0;
	assign M_AXI_AWQOS	= 4'b0;
	assign M_AXI_AWUSER	= 1'b1;

	//--------------------
	//Write Data Channel
	//--------------------
	assign M_AXI_WUSER	= 1'b1;

	// rest handled by fifos in upper layer


	//----------------------------
	//Write Response (B) Channel
	//----------------------------

	assign M_AXI_BREADY	= 1'b1;


	//----------------------------
	//Read Address Channel
	//----------------------------

	//combinatorc logic to calculate next state_read
	//and logic to give outputs
	always @( * )
	begin
	    M_AXI_ARVALID = 1'b0;
	    cmd_read_m32_m_axis_tready = 1'b0;
	    sts_read_m32_s_axis_tvalid = 1'b0;
	    load_read_registers = 1'b0;
	    incr_read_registers = 1'b0;

	    case(state_read)
		IDLE:
		    begin
			if(cmd_read_m32_m_axis_tvalid == 1'b1)
			    begin			
	    			cmd_read_m32_m_axis_tready = 1'b1;	
	    			load_read_registers = 1'b1;
				next_state_read = BURST;
			    end
			else
			    begin
		    		next_state_read = IDLE;
			    end
		    end
		BURST:
		    begin
			if(read_length == 0)
			    begin
				next_state_read = DONE;
			    end
			else if(M_AXI_ARREADY == 1'b1)
			    begin
				M_AXI_ARVALID = 1'b1;
	    			incr_read_registers = 1'b1;
				next_state_read = WAIT;
			    end
			else
			    begin
		    		next_state_read = BURST;
			    end
		    end
		WAIT:
		    begin
			if(read_outstanding_requests < READ_MAX_REQ)
			    begin
				next_state_read = BURST;
			    end
			else
			    begin
		    		next_state_read = WAIT;
			    end
		    end
		DONE:
		    begin
			if(read_outstanding_requests == 0 && sts_read_m32_s_axis_tready == 1'b1)
			    begin
				sts_read_m32_s_axis_tvalid = 1'b1;
				next_state_read = IDLE;
			    end
			else
			    begin
		    		next_state_read = DONE;
			    end
		    end
		default:
		    next_state_read = IDLE;
	    endcase
	end

	// Burst length counter and
	// Address incrementing
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        M_AXI_ARADDR	<= 0;
	        M_AXI_ARLEN	<= 0;
		read_length 	<= 0;
		sts_read_m32_s_axis_tdata 	<= 0;
	      end
	    else
		if (load_read_registers == 1'b1)
	      	    begin
	        	M_AXI_ARADDR <= cmd_read_m32_m_axis_tdata[95:64];
	        	read_length <= cmd_read_m32_m_axis_tdata[63:32];
	        	sts_read_m32_s_axis_tdata <= cmd_read_m32_m_axis_tdata[31:0];
			if(cmd_read_m32_m_axis_tdata[63:32] >= BYTES_PER_BURST)
	        		M_AXI_ARLEN <= C_M_AXI_BURST_LEN - 1;
			else
			   begin
			      if(cmd_read_m32_m_axis_tdata[clogb2(BYTES_PER_BEAT)+30:32] > 0) 
	        		M_AXI_ARLEN <= cmd_read_m32_m_axis_tdata[63:32] / BYTES_PER_BEAT;
			      else
	        		M_AXI_ARLEN <= cmd_read_m32_m_axis_tdata[63:32] / BYTES_PER_BEAT - 1;
			   end
	    	    end
		if (incr_read_registers == 1'b1)
	      	    begin
	        	M_AXI_ARADDR <= M_AXI_ARADDR + (M_AXI_ARLEN + 1) * BYTES_PER_BEAT;
			if(read_length < BYTES_PER_BURST)
			   begin
	        		read_length <= 0;
	        		M_AXI_ARLEN <= 0;
			   end
			else if(read_length >= 2 * BYTES_PER_BURST)
			   begin
	        		read_length <= read_length - (M_AXI_ARLEN + 1) * BYTES_PER_BEAT;
	        		M_AXI_ARLEN <= C_M_AXI_BURST_LEN - 1;
			   end
			else
			   begin
	        		read_length <= read_length - (M_AXI_ARLEN + 1) * BYTES_PER_BEAT;
				if(read_length[clogb2(BYTES_PER_BEAT)-2:0] > 0)
	        		   M_AXI_ARLEN <= (read_length - BYTES_PER_BURST) / BYTES_PER_BEAT;
				else
	        		   M_AXI_ARLEN <= (read_length - BYTES_PER_BURST) / BYTES_PER_BEAT - 1;
			   end
	    	    end
	  end

	// count cycles between awvalid and wready
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        read_outstanding_requests <= 0;
	      end
	    else
		if(M_AXI_ARVALID == 1'b1 && M_AXI_RLAST == 1'b1 && M_AXI_RVALID == 1'b1 && M_AXI_RREADY == 1'b1)
			read_outstanding_requests <= read_outstanding_requests;
		else if(M_AXI_ARVALID == 1'b1)
			read_outstanding_requests <= read_outstanding_requests + 1'b1;
		else if(M_AXI_RLAST == 1'b1 && M_AXI_RVALID == 1'b1 && M_AXI_RREADY == 1'b1)
			read_outstanding_requests <= read_outstanding_requests - 1'b1;
	  end

	// Fixed Values for Read Transfers
	assign M_AXI_ARUSER	= 1'b1;
	assign M_AXI_ARID	= 1'b0;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1); //3'b0;
	assign M_AXI_ARBURST	= 2'b01; // INCR Burst Type
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'b0;
	assign M_AXI_ARQOS	= 4'b0;


	//--------------------------------
	//Read Data (and Response) Channel
	//--------------------------------

	// mostly handled by fifos in upper layer

	// count valid transfers reads
	  always @(posedge M_AXI_ACLK)
	  begin
	    if (M_AXI_ARESETN == 0)
	      begin
	        read_counter <= 0;
	      end
	    else
		if(load_read_registers == 1'b1)
		   begin
		      read_counter <= cmd_read_m32_m_axis_tdata[63:32];
		   end
		else if(M_AXI_RVALID && M_AXI_RREADY && read_counter >= BYTES_PER_BEAT)
		   begin
		      read_counter <= read_counter - BYTES_PER_BEAT;
		   end
		else if(M_AXI_RVALID && M_AXI_RREADY && read_counter < BYTES_PER_BEAT)
		   begin
		      read_counter <= 0;
		   end
	  end

	// calculate strobe of reads
	  always @(*)
	  begin
	    m32_to_m64_cdc_s_axis_tstrb <= {BYTES_PER_BEAT{1'b1}};
	    for(i = 0; i < BYTES_PER_BEAT; i = i + 1)
		begin
		   if(i >= read_counter)	   
		   	m32_to_m64_cdc_s_axis_tstrb[i] <= 1'b0;
		end
	  end

	// User logic ends

	endmodule
