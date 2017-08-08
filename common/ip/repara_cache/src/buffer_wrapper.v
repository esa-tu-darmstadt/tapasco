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

	module buffer_wrapper #
	(
		// Width of data bus
		parameter integer C_DATA_WIDTH	    = 32,
		// Width of address bus
		parameter integer C_ADDR_WIDTH	    = 32,
        // number of lines in the internal buffer
        parameter integer C_INT_BUFF_DEPTH  = 256,
        // RAM configuration
        parameter C_RAM_TYPE                = "block" // "distributed"
	)
	(
	    // Global Clock Signal
		input wire                          clk,
		// Global Reset Signal
		input wire                          reset,
		
	    // address ports
		input wire [C_ADDR_WIDTH-1 : 0]     lut_ib_addr,
		input wire [C_ADDR_WIDTH-1 : 0]     ctrl_ib_addr,
	    // Write Data ports 
		input wire [C_DATA_WIDTH-1 : 0]     axi_wr_data,
		input wire [C_DATA_WIDTH-1 : 0]     ctrl_wr_data,
		// Write enables 
		input wire                          ctrl_wr_en,
		input wire                          rwm_wr_en,
        input wire [(C_DATA_WIDTH/8)-1 : 0] rwm_wr_strb,
    
    	// Read Data
		output wire [C_DATA_WIDTH-1 : 0]    rd_data,
        
        //MUX select signal
		input wire                          ctrl_sel
        
	);
    
    wire [C_ADDR_WIDTH-1 : 0]       addr;
    wire [C_DATA_WIDTH-1 : 0]       wr_data;
    wire                            wr_en;
    wire [(C_DATA_WIDTH/8)-1 : 0]   wr_strb;
    
    //-------------------------------------------------
    // Address MUX
    //-------------------------------------------------
    assign addr = ctrl_sel ? ctrl_ib_addr : lut_ib_addr;

    //-------------------------------------------------
    // Wr Data MUX
    //-------------------------------------------------
    assign wr_data = ctrl_sel ? ctrl_wr_data : axi_wr_data;
    assign wr_en   = ctrl_sel ? ctrl_wr_en   : rwm_wr_en;
    assign wr_strb = ctrl_sel ? {(C_DATA_WIDTH/8){1'b1}} : rwm_wr_strb;
    
    //-------------------------------------------------
    // buffer instance
    //-------------------------------------------------
    buffer #
    (
        .C_DATA_WIDTH(C_DATA_WIDTH),
        .C_ADDR_WIDTH(C_ADDR_WIDTH),
        .C_INT_BUFF_DEPTH(C_INT_BUFF_DEPTH),
        .C_RAM_TYPE(C_RAM_TYPE) //"distributed" / "block"
    ) buff (
        .clk(clk),
        .reset(reset),
        .addr(addr),
        .wr_strb(wr_strb),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .rd_data(rd_data)
    );
    
endmodule    
