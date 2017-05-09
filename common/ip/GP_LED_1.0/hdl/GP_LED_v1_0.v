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

	module GP_LED_v1_0 #
	(
		// Users to add parameters here

		parameter integer LED_WIDTH	= 8

		// User parameters ends
		// Do not modify the parameters beyond this line
	)
	(
		// Users to add ports here

		input wire IN_0,
		input wire IN_1,
		input wire IN_2,
		input wire IN_3,
		input wire IN_4,
		input wire IN_5,
		output wire [LED_WIDTH - 1 : 0] LED_Port,

		// User ports ends
		// Do not modify the ports beyond this line

		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  aclk,
		input wire  aresetn
	);

	// Add user logic here

	// Clock LED Heartbeat
	reg [31:0] counter;
	reg heart_beat;

	  // Create a Clock Heartbeat

	always @( posedge aclk )
	begin
	  if ( aresetn == 1'b0 )
	    begin
	      counter  <= 32'h0;
	      heart_beat  <= 1'b0;
	    end 
	  else
	    begin
	      if (counter < 32'd100000000)
	        begin
	          counter <= counter + 1'b1;
	        end
	      else
		begin
		  counter <= 0;
	      	  heart_beat  <= ~heart_beat;
		end
	    end
	end

	OBUF   led_0_obuf (.O(LED_Port[0]), .I(aresetn));
	OBUF   led_1_obuf (.O(LED_Port[1]), .I(heart_beat));
	OBUF   led_2_obuf (.O(LED_Port[2]), .I(IN_0));
	OBUF   led_3_obuf (.O(LED_Port[3]), .I(IN_1));
	OBUF   led_4_obuf (.O(LED_Port[4]), .I(IN_2));
	OBUF   led_5_obuf (.O(LED_Port[5]), .I(IN_3));
	OBUF   led_6_obuf (.O(LED_Port[6]), .I(IN_4));
	OBUF   led_7_obuf (.O(LED_Port[7]), .I(IN_5));

	// User logic ends

	endmodule
