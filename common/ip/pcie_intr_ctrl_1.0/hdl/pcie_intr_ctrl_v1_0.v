//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//

`timescale 1 ns / 1 ps

	module pcie_intr_ctrl_v1_0 #
	(
		// Users to add parameters here

		// pcie controller params
		parameter integer MSI_BIT_WIDTH		= 3,
		parameter integer MSI_VECTOR_WIDTH	= 5,
		// length of delay in cycles, before next irq will be triggered
		parameter integer IRQ_DELAY 		= 8,
		// length of delay in cycles, when msi packet is assumed to be lost
		parameter integer IRQ_TIMEOUT 		= 100,
		// output format of irq_out
		parameter IRQ_TRIGGERD 			= "EDGE",
		// condition to acknowledge an irq
		parameter IRQ_RECAP 			= "FAST",
		// (de)activate input check
		parameter IRQ_RECAP_CHECK		= 1'b1

		// User parameters ends
	)
	(
		// Users to add ports here

		// Global Ports for sync
		input wire  				axi_aclk,
		input wire  				axi_aresetn,

		// MSI Ports for PCIe-Core
		input wire  				msi_enable,
		input wire  				msi_grant,
		input wire  [MSI_BIT_WIDTH-1 : 0] 	msi_vector_width,
		output reg  [MSI_VECTOR_WIDTH-1 : 0] 	msi_vector_num,
		output wire 				irq_out,

		// Interrupts from user logic
		input wire 				irq_in_0,
		input wire 				irq_in_1,
		input wire 				irq_in_2,
		input wire 				irq_in_3,
		input wire 				irq_in_4,
		input wire 				irq_in_5,
		input wire 				irq_in_6,
		input wire 				irq_in_7

		// User ports ends
	);

	// Add user logic here

	// parameter for interrupt vector
	localparam integer IRQ_WIDTH = 8;

	// counter to realize delay 
	reg [15 : 0] delay_counter;
	// flag from fsm to start counting 
	reg delay_start;

	// counter to realize timeout 
	reg [15 : 0] timeout_counter;
	// flag from fsm to start counting 
	reg timeout_start;

	reg  [IRQ_WIDTH-1:0] irq_in_ff;
	reg  [IRQ_WIDTH-1:0] irq_granted;
	wire [IRQ_WIDTH-1:0] fsm_condition;
	reg  irq_out_ff;
	reg  irq_out_ff_d;

	//paramter for fsm and control unit
	localparam integer STATE_BIT_WIDTH 		= 8;

	localparam [STATE_BIT_WIDTH - 1 : 0] INT_0 	= 8'h00;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_1 	= 8'h01;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_2 	= 8'h02;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_3 	= 8'h03;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_4 	= 8'h04;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_5 	= 8'h05;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_6 	= 8'h06;
	localparam [STATE_BIT_WIDTH - 1 : 0] INT_7 	= 8'h07;

	localparam [STATE_BIT_WIDTH - 1 : 0] IDLE 	= 8'h10;
	localparam [STATE_BIT_WIDTH - 1 : 0] DELAY 	= 8'h11;
	localparam [STATE_BIT_WIDTH - 1 : 0] RECAP 	= 8'h12;

	reg  [STATE_BIT_WIDTH - 1 : 0] 		state_intr;
	reg  [STATE_BIT_WIDTH - 1 : 0] 		next_state_intr;

	// register to recap from timeout to previous state
	reg [STATE_BIT_WIDTH - 1 : 0] 		state_recap;
	reg [MSI_VECTOR_WIDTH-1 : 0] 		vector_num_recap;
	reg 					recap_start;

	// for loop
	integer i;
	genvar j;
	
	// how long interrupt out will be held 1'b1 (1 cycle or till termination condition)
	generate
	    if(IRQ_TRIGGERD == "EDGE")
		assign irq_out = irq_out_ff & ~irq_out_ff_d & msi_enable;
	    else if(IRQ_TRIGGERD == "LEVEL")
		assign irq_out = irq_out_ff & msi_enable;
	    else // "NOT"
		assign irq_out = 1'b0;
	endgenerate

	// termination condition, when next interrupt can be IRQ_TRIGGERD
	generate
	    if(IRQ_RECAP == "FAST")
		for(j = 0; j < IRQ_WIDTH; j = j + 1) 
		  assign fsm_condition[j] = ~msi_grant & irq_in_ff[j];
	    else if(IRQ_RECAP == "SLOW")
		for(j = 0; j < IRQ_WIDTH; j = j + 1) 
		  assign fsm_condition[j] = irq_in_ff[j];
	    else // "NORMAL"
		for(j = 0; j < IRQ_WIDTH; j = j + 1) 
		  assign fsm_condition[j] = ~msi_grant;
	endgenerate

	// start counting, when flag active
	always @( posedge axi_aclk )
	begin
	  if ( axi_aresetn == 1'b0 )
	    begin
	      delay_counter <= 0;
	    end
	  else
	    begin
	      if(delay_start == 1'b1)
	      	delay_counter <= delay_counter + 1;
	      else
		delay_counter <= 0;
	    end
	end

	// start counting, when flag active
	always @( posedge axi_aclk )
	begin
	  if ( axi_aresetn == 1'b0 )
	    begin
	      timeout_counter <= 0;
	    end
	  else
	    begin
	      if(timeout_start == 1'b1)
	      	timeout_counter <= timeout_counter + 1;
	      else
		timeout_counter <= 0;
	    end
	end

	// remember state, when timeout is activated,
	// where it came from
	always @( posedge axi_aclk )
	begin
	  if ( axi_aresetn == 1'b0 )
	    begin
	      state_recap <= IDLE;
	      vector_num_recap <= 0;
	    end
	  else
	    begin
	      if( recap_start == 1'b1 )
		begin
		  state_recap <= state_intr;
		  vector_num_recap <= msi_vector_num;
		end
	    end
	end

	// next_state_intr synchron to clk
	// dealy output by one cycle to generate single pulse
	always @( posedge axi_aclk )
	begin
	  if ( axi_aresetn == 1'b0 )
	    begin
	      state_intr <= IDLE;
	      irq_out_ff_d <= 1'b0;
	    end
	  else
	    begin
	      state_intr <= next_state_intr;
	      irq_out_ff_d <= irq_out_ff;
	    end
	end

	// fsm waits for irq_in_ff priority based
	// next irq can be fired, when msi_grant or ~irq_inf_ff or timeout
	always @( * )
	begin
	  msi_vector_num = 0;
	  irq_out_ff = 1'b0;
	  delay_start = 1'b0;
	  timeout_start = 1'b0;
	  recap_start = 1'b0;
	  next_state_intr = IDLE;

	  case(state_intr)

	    IDLE:
	      begin
		// irq_in_ff[0] will be checked lastly == highest priority
		for(i = IRQ_WIDTH - 1; i >= 0; i = i - 1) 
		  begin
		    if( irq_in_ff[i] == 1'b1 && irq_granted[i] == 1'b0 )
		      next_state_intr = i;
		  end
	      end

	    INT_0:
	      begin
		msi_vector_num = 0;
	  	timeout_start = 1'b1;
	  	irq_out_ff = 1'b1;
		// irq not granted yet, but timeout occurs
		// probably msi packet got dropped silently
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		// irq after condition still wanted
		else if( fsm_condition[0] )
		  next_state_intr = INT_0;
		else
		// irq handled by pcie controller
		// next irq can be fired after delay
		  next_state_intr = DELAY;
	      end

	    INT_1:
	      begin
		msi_vector_num = 1;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[1] )
		  next_state_intr = INT_1;
		else
		  next_state_intr = DELAY;
	      end

	    INT_2:
	      begin
		msi_vector_num = 2;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[2] )
		  next_state_intr = INT_2;
		else
		  next_state_intr = DELAY;
	      end

	    INT_3:
	      begin
		msi_vector_num = 3;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[3] )
		  next_state_intr = INT_3;
		else
		  next_state_intr = DELAY;
	      end

	    INT_4:
	      begin
		msi_vector_num = 4;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[4] )
		  next_state_intr = INT_4;
		else
		  next_state_intr = DELAY;
	      end

	    INT_5:
	      begin
		msi_vector_num = 5;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[5] )
		  next_state_intr = INT_5;
		else
		  next_state_intr = DELAY;
	      end

	    INT_6:
	      begin
		msi_vector_num = 6;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[6] )
		  next_state_intr = INT_6;
		else
		  next_state_intr = DELAY;
	      end

	    INT_7:
	      begin
		msi_vector_num = 7;
	  	irq_out_ff = 1'b1;
	  	timeout_start = 1'b1;
		if( timeout_counter == IRQ_TIMEOUT )
		  begin
		    recap_start = 1'b1;
		    next_state_intr = RECAP;
		  end
		else if( fsm_condition[7] )
		  next_state_intr = INT_7;
		else
		  next_state_intr = DELAY;
	      end

	    DELAY:
	      begin
		// wait before next irq can be handled 
		delay_start = 1'b1;
		if( delay_counter == IRQ_DELAY )
		  next_state_intr = IDLE;
		else
		  next_state_intr = DELAY;
	      end

	    RECAP:
	      begin
		// recap last state of fsm to restore this
		// basically done to trigger one more irq 1-0-1 transition
		msi_vector_num = vector_num_recap;
		// only if interrupt still wanted by hardware
		if(~IRQ_RECAP_CHECK || irq_in_ff[state_recap] == 1'b1)
			next_state_intr = state_recap;
		else
			next_state_intr = IDLE;
	      end
		
	    default:
	      next_state_intr = IDLE;

	  endcase
	end

	// remember which interrupts already got granted on msi but not handled by host
	always @( posedge axi_aclk )
	begin
	  if ( axi_aresetn == 1'b0 )
	    begin
	      irq_granted <= 0;
	    end
	  else
	    begin
	      for(i = 0; i < IRQ_WIDTH; i = i + 1) 
		begin
		  if( msi_grant == 1'b1 && msi_vector_num == i )
		    irq_granted[i] <= 1'b1;
		  if( irq_in_ff[i] == 1'b0 )
		    irq_granted[i] <= 1'b0;
		end
	    end
	end

	// get all irqs in ff
	always @( posedge axi_aclk )
	begin
	  if ( axi_aresetn == 1'b0 )
	    begin
	      irq_in_ff	<= 0;
	    end
	  else
	    begin
	      irq_in_ff	<= {irq_in_7, irq_in_6, irq_in_5, irq_in_4, irq_in_3, irq_in_2, irq_in_1, irq_in_0};
	    end
	end

	// User logic ends

	endmodule
