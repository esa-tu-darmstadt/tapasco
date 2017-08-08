// 
// Copyright (C) 2015 Evopro Innovation Kft (Budapest, Hungary) 
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
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
// GNU Lesser General Public License for more details. 
// 
// You should have received a copy of the GNU Lesser General Public License 
// along with Tapasco. If not, see <http://www.gnu.org/licenses/>. 
// 

	module buffer #
	(
		// Width of data bus
		parameter integer C_DATA_WIDTH	= 32,
		// Width of address bus
		parameter integer C_ADDR_WIDTH	= 32,
        // number of lines in the internal buffer
        parameter integer C_INT_BUFF_DEPTH     = 256,
        // RAM configuration
        parameter C_RAM_TYPE = "block" // "distributed"
	)
	(
	    // Global Clock Signal
		input wire  clk,
		// Global Reset Signal
		input wire  reset,
		
	    // address
		input wire [C_ADDR_WIDTH-1 : 0] addr,
		// Write strobe. This signal indicates which byte
        // lanes hold valid data. There is one write strobe
        // bit for each eight bits of the write data bus.
		input wire [(C_DATA_WIDTH/8)-1 : 0] wr_strb,
	    // Write Data
		input wire [C_DATA_WIDTH-1 : 0] wr_data,
		// Write enable. This signal indicates that valid write
        // data and strobes are available.
		input wire  wr_en,
    	// Read Data
		output wire [C_DATA_WIDTH-1 : 0] rd_data
	);

    genvar mem_byte_index;	
	
	// WIRES & REGISTERS
	wire [C_ADDR_WIDTH-1:0] mem_address;
    reg  [C_DATA_WIDTH-1:0] mem_data_out;
	

    assign mem_address = addr;
    
	// Implement RAM
	generate 
        begin: RAM_GEN
	        // generate RAM byte-by-byte
            for(mem_byte_index=0; mem_byte_index<= (C_DATA_WIDTH/8-1); mem_byte_index=mem_byte_index+1)
            begin: BYTE_BRAM_GEN
                wire [7:0] data_in;
                wire [7:0] data_out;
                (* ram_style = C_RAM_TYPE *) reg [7:0] byte_ram [0 : (C_INT_BUFF_DEPTH-1)];
             
                //assigning 8 bit data
                assign data_in  = wr_data[(mem_byte_index*8+7) : (mem_byte_index*8+0)];
                assign data_out = byte_ram[mem_address];
             
                // write in process
                always @( posedge clk )
                begin
                    if (wr_en && wr_strb[mem_byte_index]) begin
                        byte_ram[mem_address] <= data_in;
                    end
                end    
              
                // read out process
                always @( posedge clk )
                begin
                    mem_data_out[(mem_byte_index*8+7) : (mem_byte_index*8+0)] <= data_out;
                end    
            end
        end       
    endgenerate
    
    // connect memory to output
    assign rd_data = mem_data_out;
	
endmodule
