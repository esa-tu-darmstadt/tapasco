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

`timescale 1ns / 1ps

module axi_m_bfm#
    (
        parameter integer C_AXI_nLITE_OR_FULL       = 0,    // 0=lite, 1=full
        parameter integer C_AXI_ADDR_WIDTH          = 16,
        parameter integer C_AXI_DATA_WIDTH          = 32,
        parameter integer C_AXI_BURST_LEN           = 16,
        parameter integer C_TIMEOUT_AXI_RESPONSE    = 256,
        parameter integer C_AXI_ID_WIDTH            = 1,
        parameter integer C_TB_ERROR_CONTINUE       = 0
    )
    (
        //axi signals
        input wire                                              clk,
        input wire                                              resetn,
        output reg  [C_AXI_ID_WIDTH-1 : 0]                      m_axi_awid,
        output reg  [C_AXI_ADDR_WIDTH-1 : 0]                    m_axi_awaddr,
        output reg  [7 : 0]                                     m_axi_awlen,
        output reg  [2 : 0]                                     m_axi_awsize,
        output reg  [1 : 0]                                     m_axi_awburst,
        output reg                                              m_axi_awvalid,
        input wire                                              m_axi_awready,
        output reg  [C_AXI_DATA_WIDTH-1 : 0]                    m_axi_wdata,
        output reg  [(C_AXI_DATA_WIDTH/8)-1 : 0]                m_axi_wstrb,
        output reg                                              m_axi_wlast,
        output reg                                              m_axi_wvalid,
        input wire                                              m_axi_wready,
        input wire  [C_AXI_ID_WIDTH-1 : 0]                      m_axi_bid,
        input wire  [1 : 0]                                     m_axi_bresp,
        input wire                                              m_axi_bvalid,
        output reg                                              m_axi_bready,
        output reg  [C_AXI_ID_WIDTH-1 : 0]                      m_axi_arid,
        output reg  [C_AXI_ADDR_WIDTH-1 : 0]                    m_axi_araddr,
        output reg  [7 : 0]                                     m_axi_arlen,
        output reg  [2 : 0]                                     m_axi_arsize,
        output reg  [1 : 0]                                     m_axi_arburst,
        output reg                                              m_axi_arvalid,
        input wire                                              m_axi_arready,
        input wire  [C_AXI_ID_WIDTH-1 : 0]                      m_axi_rid,
        input wire  [C_AXI_DATA_WIDTH-1 : 0]                    m_axi_rdata,
        input wire  [1 : 0]                                     m_axi_rresp,
        input wire                                              m_axi_rlast,
        input wire                                              m_axi_rvalid,
        output reg                                              m_axi_rready,
        //control signals       
        input wire                                              send_wr,
        input wire                                              send_rd,
        input wire [C_AXI_ADDR_WIDTH-1 : 0]                     addr,
        input wire [C_AXI_BURST_LEN*C_AXI_DATA_WIDTH-1 : 0]     wr_data_bits,
        input wire [7 : 0]                                      len,
        input wire                                              invalid,  //0-normal transfer, 1-force invalid transfer
        input wire                                              do_wait,  //0-compact transfer, 1-do random wait cycles
        output wire [C_AXI_BURST_LEN*C_AXI_DATA_WIDTH-1 : 0]    rd_data_bits,
        output reg                                              busy_rd,
        output reg                                              busy_wr
    );

    

    // function called clogb2 that returns an integer which has the 
    // value of the ceiling of the log base 2.                      
    function integer clogb2 (input integer bit_depth);              
    begin                                                           
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
            bit_depth = bit_depth >> 1;                                 
        end                                                           
    endfunction  

    localparam integer ADDR_LSB = clogb2( C_AXI_DATA_WIDTH/8 -1 );
        
    reg  [C_AXI_BURST_LEN*C_AXI_DATA_WIDTH-1 : 0]   i_wr_data_bits;
    wire [C_AXI_DATA_WIDTH-1 : 0]                   i_wr_data       [C_AXI_BURST_LEN-1:0];

    reg [C_AXI_DATA_WIDTH-1 : 0]                    i_rd_data       [C_AXI_BURST_LEN-1:0];
    reg [15:0]                                      timeout;
    reg [7 : 0]                                     rd_cnt, wr_cnt;
    reg [31:0]                                      rand=0;
    reg [31:0]                                      random_wait=0;
    
    //unfold the input bit vector to an array, fold output array into bitvector
    genvar i; generate for (i = 0; i < C_AXI_BURST_LEN; i = i+1) begin: unfold
        assign i_wr_data[i] = i_wr_data_bits[C_AXI_DATA_WIDTH*(i+1) -1 : i*C_AXI_DATA_WIDTH]; 
        assign rd_data_bits[C_AXI_DATA_WIDTH*(i+1) -1 : i*C_AXI_DATA_WIDTH] = i_rd_data[i];
    end endgenerate
    



    
    //------------------------
    // AXI init signals
    //------------------------
    initial begin
        //--- write address channel
        m_axi_awaddr     <= 0;
        m_axi_awburst    <= 0; // 1-INCR
        m_axi_awid       <= 0;
        m_axi_awlen      <= 0; // x - no of beats
        m_axi_awsize     <= 0; // 2^x - no of bytes
        m_axi_awvalid    <= 0;
        //--- write data channel
        m_axi_wdata      <= 0;
        m_axi_wvalid     <= 0;
        m_axi_wlast      <= 0;
        m_axi_wstrb      <= 0;
        //--- write response channel
        m_axi_bready     <= 0;
        //--- read address channel
        m_axi_araddr     <= 0;
        m_axi_arburst    <= 0; // 1-INCR
        m_axi_arid       <= 0;
        m_axi_arlen      <= 0; // x - no of beats
        m_axi_arsize     <= 0; // 2^x - no of bytes
        m_axi_arvalid    <= 0;
        //--- read data channel
        m_axi_rready     <= 0; 
        //control
        busy_rd          <= 0; 
        busy_wr          <= 0;
    end

    //------------------------
    // AXI write
    //------------------------
    always@(posedge send_wr) begin
        
        $display("Write start");
         //signal start of operation
        @(posedge clk);
        busy_wr                <= 1;
        //store transfer parameters
        i_wr_data_bits      <= wr_data_bits;
                
        @(posedge clk) ;
        //--- write address channel
        //drive write address, transfer info
        //only aligned address
        m_axi_awaddr     <= {addr[C_AXI_ADDR_WIDTH-1:ADDR_LSB],{ADDR_LSB{1'b0}} };
        m_axi_awburst    <= 1; // 1-INCR
        m_axi_awid       <= 0;
        m_axi_wlast      <= 0;
        if (C_AXI_nLITE_OR_FULL==0) begin
            //lite
            m_axi_awlen     <= 0; // always do singles
            if (len != 0) $display("Wrong WR Length. In Lite mode it must be 0.");
        end else begin
            //full
            m_axi_awlen     <= len; 
        end
        m_axi_awsize     <= clogb2((C_AXI_DATA_WIDTH/8)-1);
        m_axi_awvalid    <= ~invalid;

        @(posedge clk) ;

        fork 
            // thread 1 -- write address channel
            begin
                if (~invalid) begin
                    //wait for ready = 1; 
                    while (m_axi_awready != 1 ) @(posedge clk);
                end else begin
                    //dummy wait
                    @(posedge clk) ;
                end
                //deassert valid after slave rec'd the transfer
                m_axi_awvalid    <= 0;
            end
            // thread 2 --- write data channel
            begin
                //drive write address, transfer info
                for (wr_cnt=0; wr_cnt <= m_axi_awlen; wr_cnt = wr_cnt + 1) begin
                    //random_wait
                    if (do_wait) begin
                        m_axi_wvalid     <= 0;
                        rand = $random(rand) % 1024; random_wait = rand %4 ;
                        $display("********** random_wait = %0d ***********",random_wait);
                        repeat (random_wait) @(posedge clk) ;
                    end
                    m_axi_wdata      <= i_wr_data[wr_cnt];
                    m_axi_wvalid     <= ~invalid;
                    if (wr_cnt == m_axi_awlen ) begin
                        //reached last beat
                        m_axi_wlast      <= 1;
                    end
                    //always use all byte lanes, no unaligned or narrow transfer
                    m_axi_wstrb      <= (1 << (C_AXI_DATA_WIDTH/8) ) -1;
                    //wait for ready = 1; 
                    @(posedge clk) ;
                    timeout = 0; 
                    if (~invalid) begin
                        //normal transfer
                        fork : wait_or_timeout_wready
                          begin : timeout_wready
                            repeat(C_TIMEOUT_AXI_RESPONSE) @(posedge clk) ;
                            $display("ERROR: Timeout when waiting for m_axi_wready");
                            if (!C_TB_ERROR_CONTINUE) $finish;
                            disable wait_for_wready;
                          end
                          begin :wait_for_wready
                            while (m_axi_wready != 1) @(posedge clk) ;
                            disable timeout_wready;
                          end
                        join
                        
                    end else begin
                        //dummy wait
                        @(posedge clk) ;
                    end
                    //deassert valid after slave rec'd the transfer
                    m_axi_wvalid     <= 0;
                    m_axi_wlast      <= 0;
                end //for
            end
        join   

        
        //--- write response channel
        //wait for ack from slave
        m_axi_bready     <= 1;
        @(posedge clk) ;
        timeout = 0;
        if (~invalid) begin
            //normal transfer
            fork : wait_or_timeout_bvalid
              begin : timeout_bvalid
                repeat(C_TIMEOUT_AXI_RESPONSE) @(posedge clk) ;
                $display("ERROR: Timeout when waiting for m_axi_bvalid");
                if (!C_TB_ERROR_CONTINUE) $finish;
                disable wait_for_bvalid;
              end
              begin :wait_for_bvalid
                while (m_axi_bvalid != 1) @(posedge clk);
                disable timeout_bvalid;
              end
            join            
        end else begin
            //dummy wait
            @(posedge clk) ;
        end
        //discard the response... dont do anything with it
        //just remove ready
        m_axi_bready     <= 0;
        busy_wr          <= 0;
        $display("write done.");
    end
 
    //------------------------
    // AXI read
    //------------------------
    always@(posedge send_rd) begin
        
        $display("Read start");
         //signal start of operation
        @(posedge clk);
        busy_rd                <= 1;
                
        @(posedge clk) ;
        //--- read address channel
        //drive read address, transfer info
        //only aligned address
        m_axi_araddr     <= {addr[C_AXI_ADDR_WIDTH-1:ADDR_LSB],{ADDR_LSB{1'b0}} };
        m_axi_arburst    <= 1; // 1-INCR
        m_axi_arid       <= 0;
        if (C_AXI_nLITE_OR_FULL==0) begin
            //lite
            m_axi_arlen     <= 0; // always do singles
            if (len != 0) $display("Wrong RD Length. In Lite mode it must be 0.");
        end else begin
            //full
            m_axi_arlen     <= len; 
        end
        
        m_axi_arsize     <= clogb2((C_AXI_DATA_WIDTH/8)-1);
        m_axi_arvalid    <= ~invalid;
                
        @(posedge clk) ;

        fork 
            // thread 1 -- read address channel
            begin
                if (~invalid) begin
                    //wait for ready = 1; 
                    while (m_axi_arready != 1 ) @(posedge clk);
                end else begin
                    //dummy wait
                    @(posedge clk) ;
                end
                //deassert valid after slave rec'd the transfer
                m_axi_arvalid    <= 0;
            end
            // thread 2 --- read data channel
            begin
                //drive write address, transfer info
                for (rd_cnt=0; rd_cnt <= m_axi_arlen; rd_cnt = rd_cnt + 1) begin
                    //random_wait
                    if (do_wait) begin
                        m_axi_rready     <= 0;
                        rand = $random(rand) % 1024; random_wait = rand % 4;
                        $display("********** random_wait = %0d ***********",random_wait);
                        repeat (random_wait) @(posedge clk) ;
                    end
                    m_axi_rready     <= 1;
                    
                    //wait for valid from slave
                    @(posedge clk) ;
                    timeout = 0;
                    if (~invalid) begin
                        fork : wait_or_timeout_rvalid
                          begin : timeout_rvalid
                            repeat(C_TIMEOUT_AXI_RESPONSE) @(posedge clk) ;
                            $display("ERROR: Timeout when waiting for m_axi_rvalid");
                            if (!C_TB_ERROR_CONTINUE) $finish;
                            disable wait_for_rvalid;
                          end
                          begin :wait_for_rvalid
                            while (m_axi_rvalid != 1) @(posedge clk) ;
                            disable timeout_rvalid;
                          end
                        join

                    end else begin
                        //dummy wait
                        @(posedge clk) ;
                    end
                    //store read data
                    i_rd_data[rd_cnt]   <= m_axi_rdata;
                    if (~invalid && m_axi_rlast==0 && rd_cnt == m_axi_arlen) begin
                        $display("ERROR: AXI_RLAST was not asserted at the end of the transfer.");
                        if (!C_TB_ERROR_CONTINUE) $finish;
                    end
                    
                end //for
            end
        join  

        //signal end of operation
        @(posedge clk);
        busy_rd                 <= 0;
        m_axi_rready            <= 0; 
        $display("read done.");
    end
    
endmodule
