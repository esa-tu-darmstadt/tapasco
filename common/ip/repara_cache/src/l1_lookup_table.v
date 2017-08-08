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

    module l1_lookup_table #
    (
        // Width of input address bus
        parameter integer C_AXI_ADDR_WIDTH          = 32,

        // Width of tagline 
        parameter integer C_TAGLINE_DATA_WIDTH      = 32,        
        // Width of tag buffer's address bus
        parameter integer C_TAGLINE_ADDR_WIDTH      = 8,
        // number of lines in the internal buffer
        parameter integer C_TAG_DEPTH               = 64,
        
        // number of lines of valid flags to be ored
        parameter integer C_VALID_FLAG_CHECK_NUM    = 64,
        
        // RAM configuration "block", "distributed"
        parameter C_RAM_TYPE                        = "block"
    )
    (
        // Global Clock Signal
        input wire                                  clk,
        // Global Reset Signal
        input wire                                  reset,
        input wire                                  reset_flags,

        // select signal: RWM vs. CTRL
        input  wire                                 input_sel, 
        
        // lookup interface, to check a given AXI address
        input  wire [2+C_AXI_ADDR_WIDTH-1 : 0]      rwm_axi_addr_n_flags,           // 2bit flag + axi addr
        input  wire                                 rwm_wr_tag_line_en,
        input  wire [2+C_AXI_ADDR_WIDTH-1 : 0]      ctrl_axi_addr_n_flags,          // 2bit flag + axi addr
        input  wire                                 ctrl_wr_tag_line_en, 
        // lookup result            
        output wire [C_TAGLINE_DATA_WIDTH-1 : 0]    lut_ib_tag,             // tag content 
        output wire                                 lut_hit,                // hit: cl is stored
        output reg                                  lut_dirty,              // dirty: the cache line has been modified in int. buf.
        // full tag line content
        output wire [C_TAGLINE_DATA_WIDTH+1 : 0]    rd_tag_line,          
        output reg                                  rd_tag_flush_valid_sign           
    );

	// function called clogb2 that returns an integer which has the 
    // value of the ceiling of the log base 2.                      
    function integer clogb2 (input integer bit_depth);              
    begin                                                           
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
            bit_depth = bit_depth >> 1;                                 
    end
    endfunction  
    
    function integer pow2 (input integer bit_depth);              
    begin         
        pow2 = 1 << clogb2(bit_depth);                                 
    end
    endfunction  

    localparam integer  C_TAGLINE_DATA_WIDTH_ROUND = pow2(C_TAGLINE_DATA_WIDTH-1);          // calculate bit width of data width
  

    integer line_index;    
    genvar row_index;    
   
    localparam integer TAG_MSB     = (C_AXI_ADDR_WIDTH-1);
    localparam integer TAG_LSB     = (C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH);
    localparam integer IDX_MSB     = (C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1);
    localparam integer IDX_LSB     = (C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-C_TAGLINE_ADDR_WIDTH);
    
    localparam integer VALID_WIDTH = clogb2(C_VALID_FLAG_CHECK_NUM-1);                                     
    
    // WIRES & REGISTERS

    wire [(C_TAGLINE_DATA_WIDTH-1) : 0]     input_tag_async;
    reg  [(C_TAGLINE_DATA_WIDTH-1) : 0]     input_tag_sync;
    wire [1 : 0]                            input_flag;
    wire [(C_TAGLINE_ADDR_WIDTH-1) : 0]     input_idx;
    wire                                    input_wr_en;

    reg  [1 : 0]                            flag_table [0 : (C_TAG_DEPTH-1)];
   
    wire [C_TAG_DEPTH-1 : 0]                valid_vector;
    wire [VALID_WIDTH-1 : 0]                valid_or;
    wire                                    valid_sign_async;

    wire                                    int_hit_async;
    reg                                     int_valid_sync;
    
    wire [C_TAGLINE_DATA_WIDTH-1 : 0]       rd_tag_line_tag; 
    reg [1 : 0]                             rd_tag_line_flags;
   
    // LOOKUP TABLE LOGIC 
    // lookup tag address, index, wr_en MUX
    assign input_idx       = input_sel ? ctrl_axi_addr_n_flags[IDX_MSB:IDX_LSB]     : rwm_axi_addr_n_flags[IDX_MSB:IDX_LSB]; 
    assign input_tag_async = input_sel ? ctrl_axi_addr_n_flags[TAG_MSB:TAG_LSB]     : rwm_axi_addr_n_flags[TAG_MSB:TAG_LSB];     
    assign input_flag      = input_sel ? ctrl_axi_addr_n_flags[2+TAG_MSB:TAG_MSB+1] : rwm_axi_addr_n_flags[2+TAG_MSB:TAG_MSB+1];     
    assign input_wr_en     = input_sel ? ctrl_wr_tag_line_en                        : rwm_wr_tag_line_en;
        
    always @(posedge clk) begin
        input_tag_sync <= input_sel ? ctrl_axi_addr_n_flags[TAG_MSB:TAG_LSB] : rwm_axi_addr_n_flags[TAG_MSB:TAG_LSB];     
    end   
        
    // reset and write flag table
    always @(posedge clk) begin
        if (reset | reset_flags) begin 
            for (line_index=0; line_index<C_TAG_DEPTH; line_index=line_index+1) begin
                flag_table[line_index][1:0] <= 'b0;
            end
        end
        else begin
            if (input_wr_en == 1'b1) begin                                              
                flag_table[input_idx][1:0] <= input_flag;
            end
        end        
    end 
    
    buffer_wrapper #
    (
        .C_DATA_WIDTH               ( C_TAGLINE_DATA_WIDTH_ROUND    ),
        .C_ADDR_WIDTH               ( C_TAGLINE_ADDR_WIDTH          ),
        .C_INT_BUFF_DEPTH           ( C_TAG_DEPTH                   ),
        .C_RAM_TYPE                 ( C_RAM_TYPE                    ) 
    ) 
    tag_table (
        .clk                        ( clk                           ),
        .reset                      ( reset                         ),
        .lut_ib_addr                ( input_idx                     ),
        .axi_wr_data                ( input_tag_async               ),
        .rwm_wr_en                  ( input_wr_en                   ),
        .rwm_wr_strb                ( {(C_TAGLINE_DATA_WIDTH_ROUND/8){1'b1}}),
        .ctrl_ib_addr               ( 'h0                           ),
        .ctrl_wr_data               ( 'h0                           ),
        .ctrl_wr_en                 ( 'b0                           ),
        .rd_data                    ( rd_tag_line_tag               ),
        .ctrl_sel                   ( 'b0                           )
    );
    
    // generate 1 BIT hit, valid and dirty signal
    assign int_hit_async = ((rd_tag_line_tag == input_tag_sync)? 1:0);
    
    // put valid bits into one vector
    generate
        for (row_index=0; row_index<(C_TAG_DEPTH); row_index=row_index+1) begin
            assign valid_vector[row_index] = flag_table[row_index][0];
        end    
    endgenerate 
    
    // or const. set of valid flags
    generate
        if (C_TAG_DEPTH == C_VALID_FLAG_CHECK_NUM) begin 
            assign valid_sign_async  = |valid_vector[C_VALID_FLAG_CHECK_NUM-1 : 0];
        end
        else begin
            for (row_index=0; row_index<VALID_WIDTH; row_index=row_index+1) begin
                assign valid_or[row_index] = |valid_vector[((row_index*C_VALID_FLAG_CHECK_NUM)+C_VALID_FLAG_CHECK_NUM-1) : (row_index*C_VALID_FLAG_CHECK_NUM)];
            end   
            assign valid_sign_async = valid_or[input_idx[C_TAGLINE_ADDR_WIDTH-1 : VALID_WIDTH]];
        end     
    endgenerate 
    
    // register combinatioral signals
    always @(posedge clk) begin
        int_valid_sync          <= flag_table[input_idx][0];
        lut_dirty               <= flag_table[input_idx][1];
        rd_tag_flush_valid_sign <= valid_sign_async;
        rd_tag_line_flags       <= flag_table[input_idx];
    end
    
    assign rd_tag_line = {rd_tag_line_flags, rd_tag_line_tag};
    assign lut_ib_tag  = rd_tag_line_tag;     
    assign lut_hit     = int_hit_async & int_valid_sync;
    
endmodule
