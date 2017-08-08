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

module l1_top #
    (

        // Parameters of Axi LITE Slave Bus Interface SL_AXI
        parameter integer C_SL_AXI_ADDR_WIDTH           = 32,
        parameter integer C_SL_AXI_DATA_WIDTH           = 32,        

        // Parameters of Axi FULL Slave Bus Interface SF_AXI
        parameter integer C_SF_AXI_ADDR_WIDTH           = 32,   //valid: 32, 64
        parameter integer C_SF_AXI_DATA_WIDTH           = 32,   //valid: 32, 64, 128, 256, 512
        
        // Parameters of Axi FULL Master Bus Interface MF_AXI
        parameter integer C_MF_AXI_ADDR_WIDTH           = 32,   //valid: 32, 64
        parameter integer C_MF_AXI_DATA_WIDTH           = 128,   //valid: 32, 64, 128, 256, 512
        parameter integer C_MF_AXI_BURST_LEN            = 16,
        parameter integer C_AXI_ID_WIDTH                = 1,
        parameter integer C_AXI_USER_WIDTH              = 1,
        
        // Width of one cache line
        parameter integer C_CACHELINE_DATA_WIDTH        = 256,
        // Number of lines in the cache
        parameter integer C_CACHELINE_DEPTH             = 64,

        // RAM configuration "block", "distributed"
        parameter C_RAM_TYPE                            = "block",

        // Write strategy: "WR_THROUGH", "WR_BACK"
        parameter C_WR_STRATEGY                         = "WR_THROUGH"         
    )
    (

        // Global Clock Signal
        input wire  clk,
        // Global Reset Signal
        input wire  resetn,
        
        // single bit interface
        input  wire invalidate_all,
        input  wire flush_all,
        output wire module_busy,

        // Ports of Axi Slave Bus Interface SL_AXI
        input wire [C_SL_AXI_ADDR_WIDTH-1 : 0] sl_axi_awaddr,
        input wire [2 : 0] sl_axi_awprot,
        input wire  sl_axi_awvalid,
        output wire  sl_axi_awready,
        input wire [C_SL_AXI_DATA_WIDTH-1 : 0] sl_axi_wdata,
        input wire [(C_SL_AXI_DATA_WIDTH/8)-1 : 0] sl_axi_wstrb,
        input wire  sl_axi_wvalid,
        output wire  sl_axi_wready,
        output wire [1 : 0] sl_axi_bresp,
        output wire  sl_axi_bvalid,
        input wire  sl_axi_bready,
        input wire [C_SL_AXI_ADDR_WIDTH-1 : 0] sl_axi_araddr,
        input wire [2 : 0] sl_axi_arprot,
        input wire  sl_axi_arvalid,
        output wire  sl_axi_arready,
        output wire [C_SL_AXI_DATA_WIDTH-1 : 0] sl_axi_rdata,
        output wire [1 : 0] sl_axi_rresp,
        output wire  sl_axi_rvalid,
        input wire  sl_axi_rready,

        // Ports of Axi Slave Bus Interface SF_AXI
        input wire [C_AXI_ID_WIDTH-1 : 0] sf_axi_awid,
        input wire [C_SF_AXI_ADDR_WIDTH-1 : 0] sf_axi_awaddr,
        input wire [7 : 0] sf_axi_awlen,
        input wire [2 : 0] sf_axi_awsize,
        input wire [1 : 0] sf_axi_awburst,
        input wire  sf_axi_awlock,
        input wire [3 : 0] sf_axi_awcache,
        input wire [2 : 0] sf_axi_awprot,
        input wire [3 : 0] sf_axi_awqos,
        input wire [3 : 0] sf_axi_awregion,
        input wire [C_AXI_USER_WIDTH-1 : 0] sf_axi_awuser,
        input wire  sf_axi_awvalid,
        output wire  sf_axi_awready,
        input wire [C_SF_AXI_DATA_WIDTH-1 : 0] sf_axi_wdata,
        input wire [(C_SF_AXI_DATA_WIDTH/8)-1 : 0] sf_axi_wstrb,
        input wire  sf_axi_wlast,
        input wire [C_AXI_USER_WIDTH-1 : 0] sf_axi_wuser,
        input wire  sf_axi_wvalid,
        output wire  sf_axi_wready,
        output wire [C_AXI_ID_WIDTH-1 : 0] sf_axi_bid,
        output wire [1 : 0] sf_axi_bresp,
        output wire [C_AXI_USER_WIDTH-1 : 0] sf_axi_buser,
        output wire  sf_axi_bvalid,
        input wire  sf_axi_bready,
        input wire [C_AXI_ID_WIDTH-1 : 0] sf_axi_arid,
        input wire [C_SF_AXI_ADDR_WIDTH-1 : 0] sf_axi_araddr,
        input wire [7 : 0] sf_axi_arlen,
        input wire [2 : 0] sf_axi_arsize,
        input wire [1 : 0] sf_axi_arburst,
        input wire  sf_axi_arlock,
        input wire [3 : 0] sf_axi_arcache,
        input wire [2 : 0] sf_axi_arprot,
        input wire [3 : 0] sf_axi_arqos,
        input wire [3 : 0] sf_axi_arregion,
        input wire [C_AXI_USER_WIDTH-1 : 0] sf_axi_aruser,
        input wire  sf_axi_arvalid,
        output wire  sf_axi_arready,
        output wire [C_AXI_ID_WIDTH-1 : 0] sf_axi_rid,
        output wire [C_SF_AXI_DATA_WIDTH-1 : 0] sf_axi_rdata,
        output wire [1 : 0] sf_axi_rresp,
        output wire  sf_axi_rlast,
        output wire [C_AXI_USER_WIDTH-1 : 0] sf_axi_ruser,
        output wire  sf_axi_rvalid,
        input wire  sf_axi_rready,
        
        // Ports of Axi Master Bus Interface MF_AXI
        output wire [C_AXI_ID_WIDTH-1 : 0] mf_axi_awid,
        output wire [C_MF_AXI_ADDR_WIDTH-1 : 0] mf_axi_awaddr,
        output wire [7 : 0] mf_axi_awlen,
        output wire [2 : 0] mf_axi_awsize,
        output wire [1 : 0] mf_axi_awburst,
        output wire  mf_axi_awlock,
        output wire [3 : 0] mf_axi_awcache,
        output wire [2 : 0] mf_axi_awprot,
        output wire [3 : 0] mf_axi_awqos,
        output wire [C_AXI_USER_WIDTH-1 : 0] mf_axi_awuser,
        output wire  mf_axi_awvalid,
        input wire  mf_axi_awready,
        output wire [C_MF_AXI_DATA_WIDTH-1 : 0] mf_axi_wdata,
        output wire [C_MF_AXI_DATA_WIDTH/8-1 : 0] mf_axi_wstrb,
        output wire  mf_axi_wlast,
        output wire [C_AXI_USER_WIDTH-1 : 0] mf_axi_wuser,
        output wire  mf_axi_wvalid,
        input wire  mf_axi_wready,
        input wire [C_AXI_ID_WIDTH-1 : 0] mf_axi_bid,
        input wire [1 : 0] mf_axi_bresp,
        input wire [C_AXI_USER_WIDTH-1 : 0] mf_axi_buser,
        input wire  mf_axi_bvalid,
        output wire  mf_axi_bready,
        output wire [C_AXI_ID_WIDTH-1 : 0] mf_axi_arid,
        output wire [C_MF_AXI_ADDR_WIDTH-1 : 0] mf_axi_araddr,
        output wire [7 : 0] mf_axi_arlen,
        output wire [2 : 0] mf_axi_arsize,
        output wire [1 : 0] mf_axi_arburst,
        output wire  mf_axi_arlock,
        output wire [3 : 0] mf_axi_arcache,
        output wire [2 : 0] mf_axi_arprot,
        output wire [3 : 0] mf_axi_arqos,
        output wire [C_AXI_USER_WIDTH-1 : 0] mf_axi_aruser,
        output wire  mf_axi_arvalid,
        input wire  mf_axi_arready,
        input wire [C_AXI_ID_WIDTH-1 : 0] mf_axi_rid,
        input wire [C_MF_AXI_DATA_WIDTH-1 : 0] mf_axi_rdata,
        input wire [1 : 0] mf_axi_rresp,
        input wire  mf_axi_rlast,
        input wire [C_AXI_USER_WIDTH-1 : 0] mf_axi_ruser,
        input wire  mf_axi_rvalid,
        output wire  mf_axi_rready
    );
    
    // function called clogb2 that returns an integer which has the 
    // value of the ceiling of the log base 2.                      
    function integer clogb2 (input integer bit_depth);              
    begin                                                           
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
            bit_depth = bit_depth >> 1;                                 
    end
    endfunction   

    // generate constants for port widths
    localparam integer C_CL_SF_RATIO            = C_CACHELINE_DATA_WIDTH/C_SF_AXI_DATA_WIDTH;
    localparam integer C_CL_MF_RATIO            = C_CACHELINE_DATA_WIDTH/C_MF_AXI_DATA_WIDTH;
    localparam integer C_MF_SF_RATIO            = C_MF_AXI_DATA_WIDTH/C_SF_AXI_DATA_WIDTH;
    localparam integer C_IDX                    = clogb2(C_CACHELINE_DEPTH-1);
    localparam integer C_IDX_OFFS               = clogb2(C_CL_SF_RATIO)-1;                      // because ratio is power of 2
    localparam integer C_SF_ADDR_LSB            = clogb2(C_SF_AXI_DATA_WIDTH/8)-1;              // because data width is power of 2
    localparam integer C_MF_ADDR_LSB            = clogb2(C_MF_AXI_DATA_WIDTH/8)-1;              // because data width is power of 2

    localparam integer C_TAGLINE_DATA_WIDTH     = C_SF_AXI_ADDR_WIDTH - C_IDX - C_IDX_OFFS - C_SF_ADDR_LSB;
    localparam integer C_TAGLINE_ADDR_WIDTH     = clogb2(C_CACHELINE_DEPTH-1);
    localparam integer C_TAG_DEPTH              = C_CACHELINE_DEPTH;
    localparam integer C_CACHELINE_ADDR_WIDTH   = clogb2(C_CACHELINE_DEPTH*C_CL_SF_RATIO-1);
    
    
    localparam integer C_VALID_FLAG_CHECK_NUM = 16; //C_TAG_DEPTH;

    //invert reset for AXI IF's
    wire reset;
    assign reset   = ~resetn;

    wire [C_SF_AXI_ADDR_WIDTH-1 : 0]    sf_ext_addr;
    wire                                sf_ext_addr_valid;
    wire                                sf_ext_addr_ready;        
                                           
    wire [C_SF_AXI_DATA_WIDTH-1 : 0]    sf_ext_rd_data;
    wire                                sf_ext_rd_valid;
    wire                                sf_ext_rd_ready;        
    
    wire [C_SF_AXI_DATA_WIDTH-1 : 0]    sf_ext_wr_data;
    wire                                sf_ext_wr_valid;
    wire                                sf_ext_wr_ready;        

    wire [C_SL_AXI_ADDR_WIDTH-1 : 0]    sl_ctrl_wr_addr;
    wire [C_SL_AXI_DATA_WIDTH-1 : 0]    sl_ctrl_wr_data;
    wire                                sl_ctrl_wr_en;
    wire [C_SL_AXI_ADDR_WIDTH-1 : 0]    sl_ctrl_rd_addr;
    wire [C_SL_AXI_DATA_WIDTH-1 : 0]    sl_ctrl_rd_data;    
    
    //-------------------------------------------------
    // Instantiation of Axi Bus Interface SL_AXI
    //-------------------------------------------------
    AXI_Lite_Slave_if # ( 
        .C_S_AXI_DATA_WIDTH(C_SL_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_SL_AXI_ADDR_WIDTH)
    ) SL_AXI_inst (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(resetn),
        
        .S_AXI_AWADDR(sl_axi_awaddr),
        .S_AXI_AWPROT(sl_axi_awprot),
        .S_AXI_AWVALID(sl_axi_awvalid),
        .S_AXI_AWREADY(sl_axi_awready),
        
        .S_AXI_WDATA(sl_axi_wdata),
        .S_AXI_WSTRB(sl_axi_wstrb),
        .S_AXI_WVALID(sl_axi_wvalid),
        .S_AXI_WREADY(sl_axi_wready),
        
        .S_AXI_BRESP(sl_axi_bresp),
        .S_AXI_BVALID(sl_axi_bvalid),
        .S_AXI_BREADY(sl_axi_bready),
        
        .S_AXI_ARADDR(sl_axi_araddr),
        .S_AXI_ARPROT(sl_axi_arprot),
        .S_AXI_ARVALID(sl_axi_arvalid),
        .S_AXI_ARREADY(sl_axi_arready),
        
        .S_AXI_RDATA(sl_axi_rdata),
        .S_AXI_RRESP(sl_axi_rresp),
        .S_AXI_RVALID(sl_axi_rvalid),
        .S_AXI_RREADY(sl_axi_rready),
        
        .WR_ADDR(sl_ctrl_wr_addr  ),
        .WR_DATA(sl_ctrl_wr_data  ),
        .WR_EN  (sl_ctrl_wr_en    ),
        .RD_ADDR(sl_ctrl_rd_addr  ),
        .RD_DATA(sl_ctrl_rd_data  )
        
    );

    //-------------------------------------------------
    // Instantiation of Axi Bus Interface SF_AXI
    //-------------------------------------------------
    AXI_Full_Slave_if # ( 
        .C_S_AXI_ID_WIDTH(C_AXI_ID_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_SF_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_SF_AXI_ADDR_WIDTH),
        .C_S_AXI_AWUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_S_AXI_ARUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_S_AXI_WUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_S_AXI_RUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_S_AXI_BUSER_WIDTH(C_AXI_USER_WIDTH)
    ) SF_AXI_inst (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(resetn),
        
        .S_AXI_AWID(sf_axi_awid),
        .S_AXI_AWADDR(sf_axi_awaddr),
        .S_AXI_AWLEN(sf_axi_awlen),
        .S_AXI_AWSIZE(sf_axi_awsize),
        .S_AXI_AWBURST(sf_axi_awburst),
        .S_AXI_AWLOCK(sf_axi_awlock),
        .S_AXI_AWCACHE(sf_axi_awcache),
        .S_AXI_AWPROT(sf_axi_awprot),
        .S_AXI_AWQOS(sf_axi_awqos),
        .S_AXI_AWREGION(sf_axi_awregion),
        .S_AXI_AWUSER(sf_axi_awuser),
        .S_AXI_AWVALID(sf_axi_awvalid),
        .S_AXI_AWREADY(sf_axi_awready),
        
        .S_AXI_WDATA(sf_axi_wdata),
        .S_AXI_WSTRB(sf_axi_wstrb),
        .S_AXI_WLAST(sf_axi_wlast),
        .S_AXI_WUSER(sf_axi_wuser),
        .S_AXI_WVALID(sf_axi_wvalid),
        .S_AXI_WREADY(sf_axi_wready),
        
        .S_AXI_BID(sf_axi_bid),
        .S_AXI_BRESP(sf_axi_bresp),
        .S_AXI_BUSER(sf_axi_buser),
        .S_AXI_BVALID(sf_axi_bvalid),
        .S_AXI_BREADY(sf_axi_bready),
        
        .S_AXI_ARID(sf_axi_arid),
        .S_AXI_ARADDR(sf_axi_araddr),
        .S_AXI_ARLEN(sf_axi_arlen),
        .S_AXI_ARSIZE(sf_axi_arsize),
        .S_AXI_ARBURST(sf_axi_arburst),
        .S_AXI_ARLOCK(sf_axi_arlock),
        .S_AXI_ARCACHE(sf_axi_arcache),
        .S_AXI_ARPROT(sf_axi_arprot),
        .S_AXI_ARQOS(sf_axi_arqos),
        .S_AXI_ARREGION(sf_axi_arregion),
        .S_AXI_ARUSER(sf_axi_aruser),
        .S_AXI_ARVALID(sf_axi_arvalid),
        .S_AXI_ARREADY(sf_axi_arready),
        
        .S_AXI_RID(sf_axi_rid),
        .S_AXI_RDATA(sf_axi_rdata),
        .S_AXI_RRESP(sf_axi_rresp),
        .S_AXI_RLAST(sf_axi_rlast),
        .S_AXI_RUSER(sf_axi_ruser),
        .S_AXI_RVALID(sf_axi_rvalid),
        .S_AXI_RREADY(sf_axi_rready),
        .EXT_ADDR           ( sf_ext_addr          ),
        .EXT_ADDR_VALID     ( sf_ext_addr_valid    ),    
        .EXT_ADDR_READY     ( sf_ext_addr_ready    ),    
        .EXT_RD_DATA        ( sf_ext_rd_data       ), 
        .EXT_RD_VALID       ( sf_ext_rd_valid      ),  
        .EXT_RD_READY       ( sf_ext_rd_ready      ),  
        .EXT_WR_DATA        ( sf_ext_wr_data       ), 
        .EXT_WR_VALID       ( sf_ext_wr_valid      ),  
        .EXT_WR_READY       ( sf_ext_wr_ready      )
    );

    reg  [C_MF_AXI_ADDR_WIDTH-1 : 0]    axi_m_ext_addr;
    reg  [7 : 0]                        axi_m_ext_len;
    reg                                 axi_m_ext_addr_valid;
    wire                                axi_m_ext_addr_ready;
    reg  [C_MF_AXI_DATA_WIDTH-1 : 0]    axi_m_ext_wr_data;
    reg  [C_MF_AXI_DATA_WIDTH/8-1 : 0]  axi_m_ext_wr_strb;
    reg                                 axi_m_ext_wr_valid;
    wire                                axi_m_ext_wr_ready;
    wire [C_MF_AXI_DATA_WIDTH-1 : 0]    axi_m_ext_rd_data;
    wire                                axi_m_ext_rd_valid;
    wire                                axi_m_ext_rd_ready;
    
    wire [C_MF_AXI_ADDR_WIDTH-1 : 0]    ctrl_ext_addr;
    wire [7 : 0]                        ctrl_ext_len;

    wire                                ctrl_ext_addr_valid;
    wire                                ctrl_ext_addr_ready;
    wire [C_MF_AXI_DATA_WIDTH-1 : 0]    ctrl_ext_wr_data;
    wire                                ctrl_ext_wr_valid;
    wire                                ctrl_ext_wr_ready;
    
    wire [C_MF_AXI_ADDR_WIDTH-1 : 0]    rwm_ext_addr;
    wire [7 : 0]                        rwm_ext_len = 0;
    wire                                rwm_ext_addr_valid;
    wire                                rwm_ext_addr_ready;
    wire [C_MF_AXI_DATA_WIDTH-1 : 0]    rwm_ext_wr_data;
    wire [C_MF_AXI_DATA_WIDTH/8-1 : 0]  rwm_ext_wr_strb;
    wire                                rwm_ext_wr_valid;
    wire                                rwm_ext_wr_ready;
    wire [C_MF_AXI_DATA_WIDTH-1 : 0]    rwm_ext_rd_data;
    wire                                rwm_ext_rd_valid;
    wire                                rwm_ext_rd_ready;

    //-------------------------------------------------
    // Instantiation of Axi Bus Interface MF_AXI
    //-------------------------------------------------
    AXI_Full_Master_if # ( 
        .C_M_AXI_BURST_LEN(C_MF_AXI_BURST_LEN),
        .C_M_AXI_ID_WIDTH(C_AXI_ID_WIDTH),
        .C_M_AXI_ADDR_WIDTH(C_MF_AXI_ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(C_MF_AXI_DATA_WIDTH),
        .C_M_AXI_AWUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_M_AXI_ARUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_M_AXI_WUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_M_AXI_RUSER_WIDTH(C_AXI_USER_WIDTH),
        .C_M_AXI_BUSER_WIDTH(C_AXI_USER_WIDTH)
    ) MF_AXI_inst (
        .EXT_ADDR           ( axi_m_ext_addr                ),
        .EXT_LEN            ( axi_m_ext_len                 ),
        .EXT_ADDR_VALID     ( axi_m_ext_addr_valid          ),
        .EXT_ADDR_READY     ( axi_m_ext_addr_ready          ),
        .EXT_WR_DATA        ( axi_m_ext_wr_data             ),
        .EXT_WR_STRB        ( axi_m_ext_wr_strb             ),
        .EXT_WR_VALID       ( axi_m_ext_wr_valid            ),
        .EXT_WR_READY       ( axi_m_ext_wr_ready            ),
        .EXT_RD_DATA        ( axi_m_ext_rd_data             ),
        .EXT_RD_VALID       ( axi_m_ext_rd_valid            ),
        .EXT_RD_READY       ( axi_m_ext_rd_ready            ),
        .M_AXI_ACLK(clk),
        .M_AXI_ARESETN(resetn),
        
        .M_AXI_AWID(mf_axi_awid),
        .M_AXI_AWADDR(mf_axi_awaddr),
        .M_AXI_AWLEN(mf_axi_awlen),
        .M_AXI_AWSIZE(mf_axi_awsize),
        .M_AXI_AWBURST(mf_axi_awburst),
        .M_AXI_AWLOCK(mf_axi_awlock),
        .M_AXI_AWCACHE(mf_axi_awcache),
        .M_AXI_AWPROT(mf_axi_awprot),
        .M_AXI_AWQOS(mf_axi_awqos),
        .M_AXI_AWUSER(mf_axi_awuser),
        .M_AXI_AWVALID(mf_axi_awvalid),
        .M_AXI_AWREADY(mf_axi_awready),
        
        .M_AXI_WDATA(mf_axi_wdata),
        .M_AXI_WSTRB(mf_axi_wstrb),
        .M_AXI_WLAST(mf_axi_wlast),
        .M_AXI_WUSER(mf_axi_wuser),
        .M_AXI_WVALID(mf_axi_wvalid),
        .M_AXI_WREADY(mf_axi_wready),
        
        .M_AXI_BID(mf_axi_bid),
        .M_AXI_BRESP(mf_axi_bresp),
        .M_AXI_BUSER(mf_axi_buser),
        .M_AXI_BVALID(mf_axi_bvalid),
        .M_AXI_BREADY(mf_axi_bready),
        
        .M_AXI_ARID(mf_axi_arid),
        .M_AXI_ARADDR(mf_axi_araddr),
        .M_AXI_ARLEN(mf_axi_arlen),
        .M_AXI_ARSIZE(mf_axi_arsize),
        .M_AXI_ARBURST(mf_axi_arburst),
        .M_AXI_ARLOCK(mf_axi_arlock),
        .M_AXI_ARCACHE(mf_axi_arcache),
        .M_AXI_ARPROT(mf_axi_arprot),
        .M_AXI_ARQOS(mf_axi_arqos),
        .M_AXI_ARUSER(mf_axi_aruser),
        .M_AXI_ARVALID(mf_axi_arvalid),
        .M_AXI_ARREADY(mf_axi_arready),
        
        .M_AXI_RID(mf_axi_rid),
        .M_AXI_RDATA(mf_axi_rdata),
        .M_AXI_RRESP(mf_axi_rresp),
        .M_AXI_RLAST(mf_axi_rlast),
        .M_AXI_RUSER(mf_axi_ruser),
        .M_AXI_RVALID(mf_axi_rvalid),
        .M_AXI_RREADY(mf_axi_rready)
    );
    
    assign rwm_ext_rd_data     = axi_m_ext_rd_data;
    assign rwm_ext_rd_valid    = axi_m_ext_rd_valid;
    assign axi_m_ext_rd_ready  = rwm_ext_rd_ready;
    
    assign ctrl_ext_addr_ready = axi_m_ext_addr_ready;
    assign rwm_ext_addr_ready  = axi_m_ext_addr_ready;
    assign ctrl_ext_wr_ready   = axi_m_ext_wr_ready;
    assign rwm_ext_wr_ready    = axi_m_ext_wr_ready;
    
    always @(*) begin
        case(lookup_sel)
        1'b1: begin
            axi_m_ext_addr       <= ctrl_ext_addr;     
            axi_m_ext_addr_valid <= ctrl_ext_addr_valid;  
            axi_m_ext_wr_data    <= ctrl_ext_wr_data;     
            axi_m_ext_wr_valid   <= ctrl_ext_wr_valid;     
            axi_m_ext_wr_strb    <= {(C_MF_AXI_DATA_WIDTH/8){1'b1}}; 
            axi_m_ext_len        <= ctrl_ext_len;   
        end
        default: begin
            axi_m_ext_addr       <= rwm_ext_addr;     
            axi_m_ext_addr_valid <= rwm_ext_addr_valid;   
            axi_m_ext_wr_data    <= rwm_ext_wr_data;   
            axi_m_ext_wr_valid   <= rwm_ext_wr_valid;  
            axi_m_ext_wr_strb    <= rwm_ext_wr_strb;
            axi_m_ext_len        <= rwm_ext_len;   
        end        
        endcase
    end

    wire                                  conf_invalidate;
    wire                                  conf_flush;
    wire  [C_SL_AXI_DATA_WIDTH-1 : 0]     conf_addr_start;
    wire  [C_SL_AXI_DATA_WIDTH-1 : 0]     conf_erase_num;
    wire  [C_SL_AXI_DATA_WIDTH-1 : 0]     conf_ctrl_status;
        
    //-------------------------------------------------
    // Control and Status Registers
    //-------------------------------------------------
    ctrl_status_regs #
    (
        //connected to AXI Slave Lite            
        .C_S_AXI_DATA_WIDTH         ( C_SL_AXI_DATA_WIDTH           ),
        .C_S_AXI_ADDR_WIDTH         ( C_SL_AXI_ADDR_WIDTH           )
    ) ctrl_status_regs     
    (       
        .clk                        ( clk                           ),
        .reset                      ( reset                         ),
        //from/to AXI lite          
        .WR_ADDR                    ( sl_ctrl_wr_addr               ),
        .WR_DATA                    ( sl_ctrl_wr_data               ),
        .WR_EN                      ( sl_ctrl_wr_en                 ),
        .RD_ADDR                    ( sl_ctrl_rd_addr               ),
        .RD_DATA                    ( sl_ctrl_rd_data               ),
        // cmds to lookup           
        .conf_invalidate            ( conf_invalidate               ),
        .conf_flush                 ( conf_flush                    ),
        .conf_addr_start            ( conf_addr_start               ),
        .conf_erase_num             ( conf_erase_num                ),
        //status counters from RW FSM       
        .conf_hit_cnt               (  'h22                         ),
        .conf_miss_cnt              (  'h33                         ),
        .conf_stall_cnt             (  'h44                         ), 
        .conf_ctrl_status           ( conf_ctrl_status              )
    );
   

    wire                                    rwm_busy_flag;
    wire                                    ctrl_busy_flag;
    wire [2+C_SF_AXI_ADDR_WIDTH-1 : 0]      ctrl_wr_tag_line;                  
    wire                                    ctrl_wr_tag_line_en;       
    wire [C_TAGLINE_DATA_WIDTH+1 : 0]       ctrl_rd_tag_line;                  
    wire                                    ctrl_rd_tag_flush_vsign;           
    wire                                    ctrl_delete_whole_table;           
    wire                                    lut_hit;
    wire                                    lut_dirty;
    wire [C_TAGLINE_DATA_WIDTH-1 : 0]       lut_ib_tag;
    wire                                    lookup_sel;
    wire [C_CACHELINE_ADDR_WIDTH-1 : 0]     ctrl_ib_addr;
    wire [C_SF_AXI_DATA_WIDTH-1 : 0]        ib_rd_data;
    
    //-------------------------------------------------
    // Lookup Control FSM
    //-------------------------------------------------
    l1_lookup_ctrl #
    (
        .C_AXI_ADDR_WIDTH           ( C_SF_AXI_ADDR_WIDTH           ),
        .C_AXI_SL_DATA_WIDTH        ( C_SL_AXI_DATA_WIDTH           ),  
        .C_AXI_SF_DATA_WIDTH        ( C_SF_AXI_DATA_WIDTH           ),  
        .C_AXI_MF_DATA_WIDTH        ( C_MF_AXI_DATA_WIDTH           ),  
        .C_TAGLINE_DATA_WIDTH       ( C_TAGLINE_DATA_WIDTH          ),
        .C_TAGLINE_ADDR_WIDTH       ( C_TAGLINE_ADDR_WIDTH          ),
        .C_TAG_DEPTH                ( C_TAG_DEPTH                   ),
        .C_CACHELINE_DATA_WIDTH     ( C_CACHELINE_DATA_WIDTH        ),
        .C_CACHELINE_ADDR_WIDTH     ( C_CACHELINE_ADDR_WIDTH        ), 
        .MF_SF_RATIO                ( C_MF_SF_RATIO                 ),
        .CL_SF_RATIO                ( C_CL_SF_RATIO                 ),
        .OFFS                       ( C_SF_ADDR_LSB                 ),
        .IDX_OFFS                   ( C_IDX_OFFS                    ),
        .C_VALID_FLAG_CHECK_NUM     ( C_VALID_FLAG_CHECK_NUM        ),
        .C_WR_STRATEGY              ( C_WR_STRATEGY                 )   
    ) lookup_ctrl
    (
        .clk                        ( clk                           ), 
        .reset                      ( reset                         ), 
        .rwm_busy_flag              ( rwm_busy_flag                 ),
        .ctrl_busy_flag             ( ctrl_busy_flag                ),
        // single bit interface
        .invalidate_all             ( invalidate_all                ),
        .flush_all                  ( flush_all                     ),
        .module_busy                ( module_busy                   ),
        // lookup control signals                                   
        .conf_invalidate            ( conf_invalidate               ), 
        .conf_flush                 ( conf_flush                    ), 
        .conf_addr_start            ( conf_addr_start               ), 
        .conf_erase_num             ( conf_erase_num                ), 
        .conf_ctrl_status           ( conf_ctrl_status              ), 
        // from/to lookup_table                                     
        .delete_whole_table         ( ctrl_delete_whole_table       ),
        .wr_tag_line                ( ctrl_wr_tag_line              ),
        .wr_tag_line_en             ( ctrl_wr_tag_line_en           ),
        .rd_tag_line                ( ctrl_rd_tag_line              ),
        .rd_tag_flush_valid_sign    ( ctrl_rd_tag_flush_vsign       ),
        .lut_hit                    ( lut_hit                       ),
        .lut_dirty                  ( lut_dirty                     ),
        .lut_ib_tag                 ( lut_ib_tag                    ),
        // to internal buffer       
        .lookup_sel                 ( lookup_sel                    ),
        .ib_rd_addr                 ( ctrl_ib_addr                  ),
        .ib_rd_data                 ( ib_rd_data                    ),
        // to AXI master            
        .axi_m_addr_data            ( ctrl_ext_addr                 ),
        .axi_m_addr_burstlen        ( ctrl_ext_len                  ),
        .axi_m_addr_valid           ( ctrl_ext_addr_valid           ),
        .axi_m_addr_ready           ( ctrl_ext_addr_ready           ),
        .axi_m_wr_data              ( ctrl_ext_wr_data              ),
        .axi_m_wr_valid             ( ctrl_ext_wr_valid             ),
        .axi_m_wr_ready             ( ctrl_ext_wr_ready             )
    );


    wire [C_CACHELINE_ADDR_WIDTH-1 : 0]     rwm_ib_addr;
    wire                                    lut_valid;
    wire [C_SF_AXI_ADDR_WIDTH-1 : 0]        rwm_ib_addr_s;
    wire [2+C_SF_AXI_ADDR_WIDTH-1 : 0]      rwm_wr_tag_line;                  
    wire                                    rwm_wr_tag_line_en; 
    wire [C_SF_AXI_DATA_WIDTH-1 : 0]        rwm_wr_data;
    wire                                    rwm_wr_en; 

    assign rwm_ib_addr = rwm_ib_addr_s[(C_SF_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1) : C_SF_ADDR_LSB];
//                                        32                  - 24 - 1                : 2
//                                        7: 2
//                              abba0008
//                                    0000 0000 0000 1000  >> [7:2]= 0000 10 = 0x2
//    
    //-------------------------------------------------
    // Read Write Module
    //-------------------------------------------------
	l1_rwm #
    (
        .C_AXI_ADDR_WIDTH           ( C_SF_AXI_ADDR_WIDTH           ), 
        .C_AXI_MF_DATA_WIDTH        ( C_MF_AXI_DATA_WIDTH           ), 
        .C_AXI_SF_DATA_WIDTH        ( C_SF_AXI_DATA_WIDTH           ), 
        .C_TAGLINE_DATA_WIDTH       ( C_TAGLINE_DATA_WIDTH          ),
        .C_CACHELINE_DATA_WIDTH     ( C_CACHELINE_DATA_WIDTH        ),
        .C_MF_SF_RATIO              ( C_MF_SF_RATIO                 ),
        .C_CL_SF_RATIO              ( C_CL_SF_RATIO                 ),
        .C_CL_MF_RATIO              ( C_CL_MF_RATIO                 ),
        .C_SF_ADDR_LSB              ( C_SF_ADDR_LSB                 ),
        .C_MF_ADDR_LSB              ( C_MF_ADDR_LSB                 ),
        .C_IDX_OFFS                 ( C_IDX_OFFS                    ),
        .C_WR_STRATEGY              ( C_WR_STRATEGY                 )
        
    ) rwm
    (
        .clk                        ( clk                           ),
        .reset                      ( reset                         ), 
        .rwm_busy_flag              ( rwm_busy_flag                 ),
        .ctrl_busy_flag             ( ctrl_busy_flag                ),
        // from/to AXI Full slave
        .axi_s_addr                 ( sf_ext_addr                   ),
        .axi_s_addr_valid           ( sf_ext_addr_valid             ),
        .axi_s_addr_ready           ( sf_ext_addr_ready             ),
        .axi_s_wr_data              ( sf_ext_wr_data                ),
        .axi_s_wr_valid             ( sf_ext_wr_valid               ),
        .axi_s_wr_ready             ( sf_ext_wr_ready               ),
        .axi_s_rd_data              ( sf_ext_rd_data                ),
        .axi_s_rd_valid             ( sf_ext_rd_valid               ),
        .axi_s_rd_ready             ( sf_ext_rd_ready               ),
        // from/to lookup
        .lut_hit                    ( lut_hit                       ),                               
        .lut_dirty                  ( lut_dirty                     ),    
        .lut_ib_tag                 ( lut_ib_tag                    ),
        .lut_wr_tag_line            ( rwm_wr_tag_line               ),
        .lut_wr_tag_line_en         ( rwm_wr_tag_line_en            ),
        // to int. buffer
        .ib_addr                    ( rwm_ib_addr_s                 ),
        .ib_wr_data                 ( rwm_wr_data                   ),
        .ib_wr_en                   ( rwm_wr_en                     ),
        .ib_rd_data                 ( ib_rd_data                    ),            
        // to AXI master
        .axi_m_addr                 ( rwm_ext_addr                  ),
        .axi_m_addr_valid           ( rwm_ext_addr_valid            ),
        .axi_m_addr_ready           ( rwm_ext_addr_ready            ),
        .axi_m_wr_data              ( rwm_ext_wr_data               ),
        .axi_m_wr_valid             ( rwm_ext_wr_valid              ),
        .axi_m_wr_strb              ( rwm_ext_wr_strb               ),
        .axi_m_wr_ready             ( rwm_ext_wr_ready              ),
        .axi_m_rd_data              ( rwm_ext_rd_data               ),
        .axi_m_rd_valid             ( rwm_ext_rd_valid              ),
        .axi_m_rd_ready             ( rwm_ext_rd_ready              )
    );
    
    //-------------------------------------------------
    // Lookup Table
    //-------------------------------------------------
    l1_lookup_table #
    (
        .C_AXI_ADDR_WIDTH           ( C_SF_AXI_ADDR_WIDTH           ),
        .C_TAGLINE_DATA_WIDTH       ( C_TAGLINE_DATA_WIDTH          ),
        .C_TAGLINE_ADDR_WIDTH       ( C_TAGLINE_ADDR_WIDTH          ),
        .C_TAG_DEPTH                ( C_TAG_DEPTH                   ),
        .C_VALID_FLAG_CHECK_NUM     ( C_VALID_FLAG_CHECK_NUM        )
    ) lookup_table
    (
        .clk                        ( clk                           ), 
        .reset                      ( reset                         ), 
        .reset_flags                ( ctrl_delete_whole_table       ), 
        // from AXI Full slave & Lookup ctrl
        .input_sel                  ( lookup_sel                    ),        
        .rwm_axi_addr_n_flags       ( rwm_wr_tag_line               ),
        .rwm_wr_tag_line_en         ( rwm_wr_tag_line_en            ),
        .ctrl_axi_addr_n_flags      ( ctrl_wr_tag_line              ),
        .ctrl_wr_tag_line_en        ( ctrl_wr_tag_line_en           ),
        .rd_tag_line                ( ctrl_rd_tag_line              ),
        .rd_tag_flush_valid_sign    ( ctrl_rd_tag_flush_vsign       ),
        // look-up outputs
        .lut_ib_tag                 ( lut_ib_tag                    ),
        .lut_hit                    ( lut_hit                       ),
        .lut_dirty                  ( lut_dirty                     )
    );

    //-------------------------------------------------
    // Internal buffer
    //-------------------------------------------------
    buffer_wrapper #
    (
        .C_DATA_WIDTH               ( C_SF_AXI_DATA_WIDTH           ), 
        .C_ADDR_WIDTH               ( C_CACHELINE_ADDR_WIDTH        ),
        .C_INT_BUFF_DEPTH           ( C_CACHELINE_DEPTH*C_CL_SF_RATIO ),
        .C_RAM_TYPE                 ( C_RAM_TYPE                    ) 
    ) internal_buffer (
        .clk                        ( clk                           ),
        .reset                      ( reset                         ),
        .lut_ib_addr                ( rwm_ib_addr                   ),
		.ctrl_ib_addr               ( ctrl_ib_addr                  ),
	    .axi_wr_data                ( rwm_wr_data                   ),
		.ctrl_wr_data               ( 0                             ),
		.ctrl_wr_en                 ( 1'b0                          ),
		.rwm_wr_en                  ( rwm_wr_en                     ),
        .rwm_wr_strb                ( {(C_SF_AXI_DATA_WIDTH/8){1'b1}} ),
    	.rd_data                    ( ib_rd_data                    ),
        .ctrl_sel                   ( lookup_sel                    )
    );
  
    //-------------------------------------------------
    // Parameter validation checks
    //-------------------------------------------------
    wire [1:0] dummy_for_illegal_param_chk;
    
    generate
        //AXI SL: data width must be 32 or 64, address width must be at least 12
        if( ~( (C_SL_AXI_DATA_WIDTH == 32 || C_SL_AXI_DATA_WIDTH == 64) && C_SL_AXI_ADDR_WIDTH >= 12 ) ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;
            
        //AXI MF and SF must have the same address width
        if( ~(C_SF_AXI_ADDR_WIDTH == C_MF_AXI_ADDR_WIDTH) )
            assign dummy_for_illegal_param_chk[-1:0] = 1;
            
        //AXI SF can have these addr width: 32, 64
        if( ~(  C_SF_AXI_ADDR_WIDTH == 32  || 
                C_SF_AXI_ADDR_WIDTH == 64       )   ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;

        //Cache line width must be greater or equal to MF
        if ( ~( C_MF_AXI_DATA_WIDTH <= C_CACHELINE_DATA_WIDTH) ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;
            
        //AXI MF data width must be greater or equal to SF
        if ( ~( C_SF_AXI_DATA_WIDTH <= C_MF_AXI_DATA_WIDTH) ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;

            //AXI SF can have these data width: 32, 64, 128, 256, 512
        if( ~(  C_SF_AXI_DATA_WIDTH == 32  || 
                C_SF_AXI_DATA_WIDTH == 64  || 
                C_SF_AXI_DATA_WIDTH == 128 || 
                C_SF_AXI_DATA_WIDTH == 256 || 
                C_SF_AXI_DATA_WIDTH == 512      )   ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;
            
        //AXI MF can have these data width: 32, 64, 128, 256, 512
        if( ~(  C_MF_AXI_DATA_WIDTH == 32  || 
                C_MF_AXI_DATA_WIDTH == 64  || 
                C_MF_AXI_DATA_WIDTH == 128 || 
                C_MF_AXI_DATA_WIDTH == 256 || 
                C_MF_AXI_DATA_WIDTH == 512      )   ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;
        
        //Cache line width must be from these values: 32, 64, 128, 256, 512
        if( ~(  C_CACHELINE_DATA_WIDTH == 32  || 
                C_CACHELINE_DATA_WIDTH == 64  || 
                C_CACHELINE_DATA_WIDTH == 128 || 
                C_CACHELINE_DATA_WIDTH == 256 || 
                C_CACHELINE_DATA_WIDTH == 512      )   ) 
            assign dummy_for_illegal_param_chk[-1:0] = 1;

    endgenerate

endmodule
