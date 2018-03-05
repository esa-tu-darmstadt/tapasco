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

	module dual_dma_v1_0_S_AXIS #
	(
		// Users to add parameters here

		parameter integer C_M_AXI_CMD_STR_WIDTH	= 32,
		parameter integer C_M_AXI_STS_STR_WIDTH	= 32,
		parameter integer C_S_AXIS_BURST_LEN	= 16,

		// Width of m64 data Bus for last signal generation
		parameter integer C_M64_AXI_DATA_WIDTH	= 32,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here

		// signal from cmd fifo for stream
		input wire cmd_read_str_m_axis_tvalid,
		output reg cmd_read_str_m_axis_tready,
		input wire [C_M_AXI_CMD_STR_WIDTH - 1 : 0] cmd_read_str_m_axis_tdata,

		// signal from sts fifos for slave register
		output reg sts_read_str_s_axis_tvalid,
		input wire sts_read_str_s_axis_tready,
		output reg [C_M_AXI_STS_STR_WIDTH - 1 : 0] sts_read_str_s_axis_tdata,

		output reg [C_S_AXIS_TDATA_WIDTH/8-1 : 0] str_to_m64_cdc_s_axis_tstrb,
		// signal from fifo for cdc and dwc
		input wire ul_axi_rready,
		output reg ul_axi_rvalid,
		output reg ul_axi_rlast,

		// User ports ends
		// Do not modify the ports beyond this line

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output reg  S_AXIS_TREADY,
		// Data in
		//input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Byte qualifier
		//input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		//input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
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

	integer i;

	localparam integer BYTES_PER_BEAT = C_S_AXIS_TDATA_WIDTH/8;
	localparam integer BYTES_PER_BURST = C_S_AXIS_BURST_LEN*BYTES_PER_BEAT;

	// paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 4;
	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 4'b0001;
	localparam [STATE_BIT_WIDTH - 1 : 0] BURST 	= 4'b0010;
	localparam [STATE_BIT_WIDTH - 1 : 0] WAIT 	= 4'b0100;
	localparam [STATE_BIT_WIDTH - 1 : 0] DONE 	= 4'b1000;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_read;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_read;

	reg load_read_registers;
	reg [31 : 0] read_counter;
	reg [31 : 0] last_counter;

	// switch next_state_read synchron
	always @( posedge S_AXIS_ACLK )
	begin
	  if ( S_AXIS_ARESETN == 1'b0 )
		begin
		    state_read <= IDLE;
		end
	  else
		begin
		    state_read <= next_state_read;
		end
	end

	// combinatorc logic to calculate next state_read
	// and logic to give outputs
	always @( * )
	begin
	    load_read_registers = 1'b0;
	    cmd_read_str_m_axis_tready = 1'b0;
	    sts_read_str_s_axis_tvalid = 1'b0;
	    S_AXIS_TREADY = 1'b0;
	    ul_axi_rvalid = 1'b0;
	
	    case(state_read)
		IDLE:
		    begin
			if(cmd_read_str_m_axis_tvalid == 1'b1)
			    begin				
	    			cmd_read_str_m_axis_tready = 1'b1;			
	    			load_read_registers = 1'b1;
				next_state_read = WAIT;
			    end
			else
			    begin
		    		next_state_read = IDLE;
			    end
		    end
		WAIT:
		    begin
			if(read_counter == 0)
			    begin
				next_state_read = DONE;
			    end
			else
			    begin
				S_AXIS_TREADY = ul_axi_rready;
				ul_axi_rvalid = S_AXIS_TVALID;
		    		next_state_read = WAIT;
			    end
		    end
		DONE:
		    begin
			if(sts_read_str_s_axis_tready == 1'b1)
			    begin				
	    			sts_read_str_s_axis_tvalid = 1'b1;
				next_state_read = IDLE;
			    end
			else
			    begin
		    		next_state_read = WAIT;
			    end
		    end
		default:
		    next_state_read = IDLE;
	    endcase
	end

	// count valid transfers reads
	  always @(posedge S_AXIS_ACLK)
	  begin
	    if (S_AXIS_ARESETN == 0)
	      begin
	        read_counter <= 0;
	      end
	    else
		if(load_read_registers == 1'b1)
		   begin
		      sts_read_str_s_axis_tdata <= cmd_read_str_m_axis_tdata[31:0];
		      read_counter <= cmd_read_str_m_axis_tdata[63:32];
		   end
		else if(S_AXIS_TVALID && S_AXIS_TREADY && read_counter >= BYTES_PER_BEAT)
		   begin
		      read_counter <= read_counter - BYTES_PER_BEAT;
		   end
		else if(S_AXIS_TVALID && S_AXIS_TREADY && read_counter < BYTES_PER_BEAT)
		   begin
		      read_counter <= 0;
		   end
	  end

	// calculate strobe of reads
	  always @(*)
	  begin
	    str_to_m64_cdc_s_axis_tstrb <= {BYTES_PER_BEAT{1'b1}};
	    for(i = 0; i < BYTES_PER_BEAT; i = i + 1)
		begin
		   if(i >= read_counter)	   
		   	str_to_m64_cdc_s_axis_tstrb[i] <= 1'b0;
		end
	  end

	
	// count successfull data transfers in bursts strides
	  always @(posedge S_AXIS_ACLK)
	  begin
	    if (S_AXIS_ARESETN == 0)
	      begin
	        last_counter <= 0;
	      end
	    else
		if(load_read_registers == 1'b1)
		   begin
		      last_counter <= 1;
		   end
		else if(state_read == WAIT && last_counter == C_S_AXIS_BURST_LEN && S_AXIS_TVALID && S_AXIS_TREADY  )
		   begin
		      last_counter <= 1;
		   end
		else if(state_read == WAIT && S_AXIS_TVALID && S_AXIS_TREADY )
		   begin
		      last_counter <= last_counter + 1;
		   end
	  end

	// output rlast with every end of beat and if last of overall stream
	  always @(*)
	  begin
	    if(last_counter == C_S_AXIS_BURST_LEN)
		ul_axi_rlast = 1'b1;
	    else if(read_counter > 0 && read_counter <= BYTES_PER_BEAT)
		ul_axi_rlast = 1'b1;
	    else
		ul_axi_rlast = 1'b0;
	  end

	// User logic ends

	endmodule
