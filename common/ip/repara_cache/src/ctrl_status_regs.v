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
`timescale 1 ns / 1 ps

    module ctrl_status_regs #
    (
        // Width of S_AXI data bus
        parameter integer C_S_AXI_DATA_WIDTH  = 32,
        // Width of S_AXI address bus
        parameter integer C_S_AXI_ADDR_WIDTH  = 32
    )
    (
        // Global Clock Signal
        input wire  clk,
        // Global Reset Signal
        input wire  reset,
        
        // write from AXI
        input wire  [C_S_AXI_ADDR_WIDTH-1 : 0]      WR_ADDR,
        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      WR_DATA,
        input wire                                  WR_EN,
        
        // read from AXI
        input wire  [C_S_AXI_ADDR_WIDTH-1 : 0]      RD_ADDR,
        output reg  [C_S_AXI_DATA_WIDTH-1 : 0]      RD_DATA,
        
        // lookup IF
        output reg                                  conf_invalidate,
        output reg                                  conf_flush,
        output reg  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_addr_start,
        output reg  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_erase_num,
                   
//        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_empty_cnt,
        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_hit_cnt,
        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_miss_cnt,
        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_stall_cnt,      
        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      conf_ctrl_status
    );
    
    // Used address range of the AXI address:  
    //  C_REG_ADDR_WIDTH-1 : 0
    localparam integer C_REG_ADDR_WIDTH = 12;
    
    //register address defined as local paramters
    localparam INVALIDATE_ADDR =                    'h00;          // WRITING to this register to invalidate one or more line with init value
                                                                   // bit 31-0: AXI address to be invalidated
    
    localparam FLUSH_ADDR =                         'h04;          // WRITING to this register to invalidate one or more line with init value
                                                                   // bit 31-0: AXI address to be flushed  
                                                                   
    localparam ERASE_NUM_ADDR =                     'h08;          // WRITING to this register to give number of inv./flushed lines
                                                                   // bit 31-0: AXI address to be flushed     

    localparam STATUS_ADDR =                        'h20;          // READING from this register to get number of unused lines in internal buffer
                                                                   // bit 31-0: 
                                                    
//    localparam EMPTY_CNT_ADDR =                     'h24;          // READING from this register to get number of unused lines in internal buffer
                                                                   // bit 31-0: counter value of unused lines
                                                                    
    localparam HIT_CNT_ADDR =                       'h28;          // READING from this register to get number of buffer hits
                                                                   // bit 31-0: counter value of hits
                                                    
    localparam MISS_CNT_ADDR =                      'h2C;          // READING from this register to get number of misses
                                                                   // bit 31-0: counter value of misses
                                                    
    localparam STALL_CNT_ADDR =                     'h30;          // READING from this register to get number of stall cycles
                                                                   // bit 31-0: counter value of stall cycles
                                                                                                                  
    
    // registers & wires
/*    reg [C_S_AXI_DATA_WIDTH-1:0]    store_no_init_val;
    reg [C_S_AXI_DATA_WIDTH-1:0]    init_val;
    reg [C_S_AXI_DATA_WIDTH-1:0]    store_init_val;
    reg [C_S_AXI_DATA_WIDTH-1:0]    invalidate_val;
    reg [C_S_AXI_DATA_WIDTH-1:0]    flush_val;
*/   
//    reg [C_S_AXI_DATA_WIDTH-1:0]    empty_cnt_tmp;
    reg [C_S_AXI_DATA_WIDTH-1:0]    hit_cnt_tmp;
    reg [C_S_AXI_DATA_WIDTH-1:0]    miss_cnt_tmp;
    reg [C_S_AXI_DATA_WIDTH-1:0]    stall_cnt_tmp;
    reg [C_S_AXI_DATA_WIDTH-1:0]    status_tmp;
    
    //---------------------------------------
    // control registers 
    //---------------------------------------
    always @( posedge clk )
    begin
        if ( reset == 1'b1 ) begin
            conf_addr_start <= 'b0;
            conf_erase_num  <= 'b0;
            conf_invalidate <= 1'b0;
            conf_flush      <= 1'b0; 
        end 
        else begin
            if (WR_EN == 1'b1) begin
                case (WR_ADDR[C_REG_ADDR_WIDTH-1 : 0])
                    ERASE_NUM_ADDR: begin
                        conf_erase_num <= WR_DATA;
                    end  
                    INVALIDATE_ADDR: begin
                        conf_addr_start <= WR_DATA;
                        conf_invalidate <= 1'b1;
                    end  
                    FLUSH_ADDR: begin
                        conf_addr_start <= WR_DATA;
                        conf_flush      <= 1'b1; 
                    end  
                endcase
            end    
            else begin
                //make cmd output only pulses
                conf_invalidate <= 1'b0;
                conf_flush      <= 1'b0;    
            end
        end
    end  
    
    
    //----------------------------------------
    // register counter inputs
    //----------------------------------------
    always @( posedge clk )
    begin
        if ( reset == 1'b1 ) begin
//            empty_cnt_tmp   <= 'b0;
            hit_cnt_tmp     <= 'b0;
            miss_cnt_tmp    <= 'b0;
            stall_cnt_tmp   <= 'b0;      
            status_tmp      <= 1'b0;         
        end 
        else begin
//            empty_cnt_tmp   <= conf_empty_cnt;
            hit_cnt_tmp     <= conf_hit_cnt;
            miss_cnt_tmp    <= conf_miss_cnt;
            stall_cnt_tmp   <= conf_stall_cnt;
            status_tmp      <= conf_ctrl_status;     
        end
    end


    // register read logic
    // !!! no output buffering !!!
    // buffering is done in AXI slave module.
    always @(*)
    begin
        // Address decoding for other status registers
        case ( RD_ADDR[C_REG_ADDR_WIDTH-1 : 0] )
            ERASE_NUM_ADDR      : RD_DATA <= conf_erase_num;
 //           EMPTY_CNT_ADDR      : RD_DATA <= empty_cnt_tmp;
            HIT_CNT_ADDR        : RD_DATA <= hit_cnt_tmp;
            MISS_CNT_ADDR       : RD_DATA <= miss_cnt_tmp;
            STALL_CNT_ADDR      : RD_DATA <= stall_cnt_tmp;
            STATUS_ADDR         : RD_DATA <= status_tmp;
            default             : RD_DATA <= 'hFF00AA55;
        endcase
    end      
    
endmodule
