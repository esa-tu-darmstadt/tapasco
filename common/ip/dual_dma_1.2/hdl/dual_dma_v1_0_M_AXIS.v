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

	module dual_dma_v1_0_M_AXIS #
	(
		// Users to add parameters here

		parameter integer C_M_AXI_CMD_STR_WIDTH	= 32,
		parameter integer C_M_AXI_STS_STR_WIDTH	= 32,
		parameter integer C_M_AXIS_BURST_LEN	= 16,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
		parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
		// Start count is the numeber of clock cycles the master will wait before initiating/issuing any transaction.
		parameter integer C_M_START_COUNT	= 32
	)
	(
		// Users to add ports here

		// signal from cmd fifo for stream
		input wire cmd_write_str_m_axis_tvalid,
		output reg cmd_write_str_m_axis_tready,
		input wire [C_M_AXI_CMD_STR_WIDTH - 1 : 0] cmd_write_str_m_axis_tdata,

		// signal from sts fifos for slave register

		output reg sts_write_str_s_axis_tvalid,
		input wire sts_write_str_s_axis_tready,
		output reg [C_M_AXI_STS_STR_WIDTH - 1 : 0] sts_write_str_s_axis_tdata,

		// signal from fifo for cdc and dwc
		output reg ul_axi_wready,
		input wire ul_axi_wvalid,
		input wire ul_axi_wlast,

		// User ports ends
		// Do not modify the ports beyond this line

		// Global ports
		input wire  M_AXIS_ACLK,
		// 
		input wire  M_AXIS_ARESETN,
		// Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted. 
		output reg  M_AXIS_TVALID,
		// TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		//output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
		// TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		//output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
		// TLAST indicates the boundary of a packet.
		output reg  M_AXIS_TLAST,
		// TREADY indicates that the slave can accept a transfer in the current cycle.
		input wire  M_AXIS_TREADY
	);                                              
	                                                                                     
	// function called clogb2 that returns an integer which has the                      
	// value of the ceiling of the log base 2.                                           
	function integer clogb2 (input integer bit_depth);                                   
	  begin                                                                              
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                                      
	      bit_depth = bit_depth >> 1;                                                    
	  end                                                                                
	endfunction                                              

	// Add user logic here

	localparam integer BYTES_PER_BEAT = C_M_AXIS_TDATA_WIDTH/8;
	localparam integer BYTES_PER_BURST = C_M_AXIS_BURST_LEN*BYTES_PER_BEAT;

	// paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 4;
	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 4'b0001;
	localparam [STATE_BIT_WIDTH - 1 : 0] BURST 	= 4'b0010;
	localparam [STATE_BIT_WIDTH - 1 : 0] WAIT 	= 4'b0100;
	localparam [STATE_BIT_WIDTH - 1 : 0] DONE 	= 4'b1000;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_write;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_write;

	reg load_write_registers;
	reg [31 : 0] write_counter;


	// switch next_state_read synchron
	always @( posedge M_AXIS_ACLK )
	begin
	  if ( M_AXIS_ARESETN == 1'b0 )
		begin
		    state_write <= IDLE;
		end
	  else
		begin
		    state_write <= next_state_write;
		end
	end

	// combinatorc logic to calculate next state_write
	// and logic to give outputs
	always @( * )
	begin
	    load_write_registers = 1'b0;
	    cmd_write_str_m_axis_tready = 1'b0;
	    sts_write_str_s_axis_tvalid = 1'b0;
	    ul_axi_wready = 1'b0;
	    M_AXIS_TVALID = 1'b0;

	    case(state_write)
		IDLE:
		    begin
			if(cmd_write_str_m_axis_tvalid == 1'b1)
			    begin				
	    			cmd_write_str_m_axis_tready = 1'b1;			
	    			load_write_registers = 1'b1;
				next_state_write = WAIT;
			    end
			else
			    begin
		    		next_state_write = IDLE;
			    end
		    end
		WAIT:
		    begin
			if(write_counter == 0)
			    begin
				next_state_write = DONE;
			    end
			else
			    begin
		    		ul_axi_wready = M_AXIS_TREADY;
		    		M_AXIS_TVALID = ul_axi_wvalid;
		    		next_state_write = WAIT;
			    end
		    end
		DONE:
		    begin
			if(sts_write_str_s_axis_tready == 1'b1)
			    begin				
	    			sts_write_str_s_axis_tvalid = 1'b1;
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

	// count valid transfers reads
	  always @(posedge M_AXIS_ACLK)
	  begin
	    if (M_AXIS_ARESETN == 0)
	      begin
	        write_counter <= 0;
	      end
	    else
		if(load_write_registers == 1'b1)
		   begin
		      sts_write_str_s_axis_tdata <= cmd_write_str_m_axis_tdata[31:0];
		      write_counter <= cmd_write_str_m_axis_tdata[63:32];
		   end
		else if(M_AXIS_TVALID && M_AXIS_TREADY && write_counter >= BYTES_PER_BEAT)
		   begin
		      write_counter <= write_counter - BYTES_PER_BEAT;
		   end
		else if(M_AXIS_TVALID && M_AXIS_TREADY && write_counter < BYTES_PER_BEAT)
		   begin
		      write_counter <= 0;
		   end
	  end

	// output rlast if last of overall stream
	  always @(*)
	  begin
	    if(write_counter > 0 && write_counter <= BYTES_PER_BEAT)
		M_AXIS_TLAST = 1'b1;
	    else
		M_AXIS_TLAST = 1'b0;
	  end

	// User logic ends

	endmodule
