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

	module dual_dma_v1_0 #
	(
		// Users to add parameters here

		parameter integer STREAM_ENABLE	= 0,

		parameter integer C_M_AXIS_BURST_LEN	= 16,
		parameter integer C_S_AXIS_BURST_LEN	= 16,

		parameter integer M64_IS_ASYNC	= 0,
		parameter integer M32_IS_ASYNC	= 0,
		parameter integer STR_IS_ASYNC	= 0,
		parameter integer FIFO_SYNC_STAGES	= 2,

		parameter integer CMD_STS_FIFO_DEPTH	= 16,
		parameter integer DATA_FIFO_DEPTH	= 16,
		parameter integer DATA_FIFO_MODE	= 1,

		parameter integer M64_READ_MAX_REQ	= 4,
		parameter integer M64_WRITE_MAX_REQ	= 4,

		parameter integer M32_READ_MAX_REQ	= 4,
		parameter integer M32_WRITE_MAX_REQ	= 4,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Parameters of Axi Slave Bus Interface S_AXI
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		parameter integer C_S_AXI_ADDR_WIDTH	= 7,

		// Parameters of Axi Master Bus Interface M64_AXI
		parameter integer C_M64_AXI_BURST_LEN	= 16,
		parameter integer C_M64_AXI_ID_WIDTH	= 1,
		parameter integer C_M64_AXI_ADDR_WIDTH	= 64,
		parameter integer C_M64_AXI_DATA_WIDTH	= 32,
		parameter integer C_M64_AXI_AWUSER_WIDTH	= 1,
		parameter integer C_M64_AXI_ARUSER_WIDTH	= 1,
		parameter integer C_M64_AXI_WUSER_WIDTH	= 1,
		parameter integer C_M64_AXI_RUSER_WIDTH	= 1,
		parameter integer C_M64_AXI_BUSER_WIDTH	= 1,

		// Parameters of Axi Master Bus Interface M32_AXI
		parameter integer C_M32_AXI_BURST_LEN	= 16,
		parameter integer C_M32_AXI_ID_WIDTH	= 1,
		parameter integer C_M32_AXI_ADDR_WIDTH	= 32,
		parameter integer C_M32_AXI_DATA_WIDTH	= 32,
		parameter integer C_M32_AXI_AWUSER_WIDTH	= 1,
		parameter integer C_M32_AXI_ARUSER_WIDTH	= 1,
		parameter integer C_M32_AXI_WUSER_WIDTH	= 1,
		parameter integer C_M32_AXI_RUSER_WIDTH	= 1,
		parameter integer C_M32_AXI_BUSER_WIDTH	= 1,

		// Parameters of Axi Slave Bus Interface S_AXIS
		parameter integer C_S_AXIS_TDATA_WIDTH	= 32,

		// Parameters of Axi Master Bus Interface M_AXIS
		parameter integer C_M_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here

		output wire IRQ,

		// User ports ends
		// Do not modify the ports beyond this line

		// Ports of Axi Slave Bus Interface S_AXI
		input wire  s_axi_aclk,
		input wire  s_axi_aresetn,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
		input wire [2 : 0] s_axi_awprot,
		input wire  s_axi_awvalid,
		output wire  s_axi_awready,
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
		input wire  s_axi_wvalid,
		output wire  s_axi_wready,
		output wire [1 : 0] s_axi_bresp,
		output wire  s_axi_bvalid,
		input wire  s_axi_bready,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
		input wire [2 : 0] s_axi_arprot,
		input wire  s_axi_arvalid,
		output wire  s_axi_arready,
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
		output wire [1 : 0] s_axi_rresp,
		output wire  s_axi_rvalid,
		input wire  s_axi_rready,

		// Ports of Axi Master Bus Interface M64_AXI
		input wire  m64_axi_aclk,
		input wire  m64_axi_aresetn,
		output wire [C_M64_AXI_ID_WIDTH-1 : 0] m64_axi_awid,
		output wire [C_M64_AXI_ADDR_WIDTH-1 : 0] m64_axi_awaddr,
		output wire [7 : 0] m64_axi_awlen,
		output wire [2 : 0] m64_axi_awsize,
		output wire [1 : 0] m64_axi_awburst,
		output wire  m64_axi_awlock,
		output wire [3 : 0] m64_axi_awcache,
		output wire [2 : 0] m64_axi_awprot,
		output wire [3 : 0] m64_axi_awqos,
		output wire [C_M64_AXI_AWUSER_WIDTH-1 : 0] m64_axi_awuser,
		output wire  m64_axi_awvalid,
		input wire  m64_axi_awready,
		output wire [C_M64_AXI_DATA_WIDTH-1 : 0] m64_axi_wdata,
		output wire [C_M64_AXI_DATA_WIDTH/8-1 : 0] m64_axi_wstrb,
		output wire  m64_axi_wlast,
		output wire [C_M64_AXI_WUSER_WIDTH-1 : 0] m64_axi_wuser,
		output wire  m64_axi_wvalid,
		input wire  m64_axi_wready,
		input wire [C_M64_AXI_ID_WIDTH-1 : 0] m64_axi_bid,
		input wire [1 : 0] m64_axi_bresp,
		input wire [C_M64_AXI_BUSER_WIDTH-1 : 0] m64_axi_buser,
		input wire  m64_axi_bvalid,
		output wire  m64_axi_bready,
		output wire [C_M64_AXI_ID_WIDTH-1 : 0] m64_axi_arid,
		output wire [C_M64_AXI_ADDR_WIDTH-1 : 0] m64_axi_araddr,
		output wire [7 : 0] m64_axi_arlen,
		output wire [2 : 0] m64_axi_arsize,
		output wire [1 : 0] m64_axi_arburst,
		output wire  m64_axi_arlock,
		output wire [3 : 0] m64_axi_arcache,
		output wire [2 : 0] m64_axi_arprot,
		output wire [3 : 0] m64_axi_arqos,
		output wire [C_M64_AXI_ARUSER_WIDTH-1 : 0] m64_axi_aruser,
		output wire  m64_axi_arvalid,
		input wire  m64_axi_arready,
		input wire [C_M64_AXI_ID_WIDTH-1 : 0] m64_axi_rid,
		input wire [C_M64_AXI_DATA_WIDTH-1 : 0] m64_axi_rdata,
		input wire [1 : 0] m64_axi_rresp,
		input wire  m64_axi_rlast,
		input wire [C_M64_AXI_RUSER_WIDTH-1 : 0] m64_axi_ruser,
		input wire  m64_axi_rvalid,
		output wire  m64_axi_rready,

		// Ports of Axi Master Bus Interface M32_AXI
		input wire  m32_axi_aclk,
		input wire  m32_axi_aresetn,
		output wire [C_M32_AXI_ID_WIDTH-1 : 0] m32_axi_awid,
		output wire [C_M32_AXI_ADDR_WIDTH-1 : 0] m32_axi_awaddr,
		output wire [7 : 0] m32_axi_awlen,
		output wire [2 : 0] m32_axi_awsize,
		output wire [1 : 0] m32_axi_awburst,
		output wire  m32_axi_awlock,
		output wire [3 : 0] m32_axi_awcache,
		output wire [2 : 0] m32_axi_awprot,
		output wire [3 : 0] m32_axi_awqos,
		output wire [C_M32_AXI_AWUSER_WIDTH-1 : 0] m32_axi_awuser,
		output wire  m32_axi_awvalid,
		input wire  m32_axi_awready,
		output wire [C_M32_AXI_DATA_WIDTH-1 : 0] m32_axi_wdata,
		output wire [C_M32_AXI_DATA_WIDTH/8-1 : 0] m32_axi_wstrb,
		output wire  m32_axi_wlast,
		output wire [C_M32_AXI_WUSER_WIDTH-1 : 0] m32_axi_wuser,
		output wire  m32_axi_wvalid,
		input wire  m32_axi_wready,
		input wire [C_M32_AXI_ID_WIDTH-1 : 0] m32_axi_bid,
		input wire [1 : 0] m32_axi_bresp,
		input wire [C_M32_AXI_BUSER_WIDTH-1 : 0] m32_axi_buser,
		input wire  m32_axi_bvalid,
		output wire  m32_axi_bready,
		output wire [C_M32_AXI_ID_WIDTH-1 : 0] m32_axi_arid,
		output wire [C_M32_AXI_ADDR_WIDTH-1 : 0] m32_axi_araddr,
		output wire [7 : 0] m32_axi_arlen,
		output wire [2 : 0] m32_axi_arsize,
		output wire [1 : 0] m32_axi_arburst,
		output wire  m32_axi_arlock,
		output wire [3 : 0] m32_axi_arcache,
		output wire [2 : 0] m32_axi_arprot,
		output wire [3 : 0] m32_axi_arqos,
		output wire [C_M32_AXI_ARUSER_WIDTH-1 : 0] m32_axi_aruser,
		output wire  m32_axi_arvalid,
		input wire  m32_axi_arready,
		input wire [C_M32_AXI_ID_WIDTH-1 : 0] m32_axi_rid,
		input wire [C_M32_AXI_DATA_WIDTH-1 : 0] m32_axi_rdata,
		input wire [1 : 0] m32_axi_rresp,
		input wire  m32_axi_rlast,
		input wire [C_M32_AXI_RUSER_WIDTH-1 : 0] m32_axi_ruser,
		input wire  m32_axi_rvalid,
		output wire  m32_axi_rready,

		// Ports of Axi Slave Bus Interface S_AXIS
		input wire  s_axis_aclk,
		input wire  s_axis_aresetn,
		output wire  s_axis_tready,
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] s_axis_tdata,
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] s_axis_tstrb,
		input wire  s_axis_tlast,
		input wire  s_axis_tvalid,

		// Ports of Axi Master Bus Interface M_AXIS
		input wire  m_axis_aclk,
		input wire  m_axis_aresetn,
		output wire  m_axis_tvalid,
		output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] m_axis_tdata,
		output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] m_axis_tstrb,
		output wire  m_axis_tlast,
		input wire  m_axis_tready
	);

	`include "global_defs.vh"
	
	localparam integer C_CMD_UL_FIFO_WIDTH = (STREAM_ENABLE == 0) ? `CMD_32_FIFO_WIDTH : `CMD_STR_FIFO_WIDTH;
	localparam integer C_STS_UL_FIFO_WIDTH = (STREAM_ENABLE == 0) ? `STS_32_FIFO_WIDTH : `STS_STR_FIFO_WIDTH;
	localparam integer C_UL_READ_AXI_DATA_WIDTH = (STREAM_ENABLE == 0) ? C_M32_AXI_DATA_WIDTH : C_S_AXIS_TDATA_WIDTH;
	localparam integer C_UL_WRITE_AXI_DATA_WIDTH = (STREAM_ENABLE == 0) ? C_M32_AXI_DATA_WIDTH : C_M_AXIS_TDATA_WIDTH;
	localparam integer UL_IS_ASYNC = (STREAM_ENABLE == 0) ? M32_IS_ASYNC : STR_IS_ASYNC;

	// signal from cmd fifos for 64 bit engine
	wire cmd_read_m64_s_axis_tvalid;
	wire cmd_read_m64_s_axis_tready;
	wire [`CMD_64_FIFO_WIDTH - 1 : 0] cmd_read_m64_s_axis_tdata;

	wire cmd_read_m64_m_axis_tvalid;
	wire cmd_read_m64_m_axis_tready;
	wire [`CMD_64_FIFO_WIDTH - 1 : 0] cmd_read_m64_m_axis_tdata;

	wire cmd_write_m64_s_axis_tvalid;
	wire cmd_write_m64_s_axis_tready;
	wire [`CMD_64_FIFO_WIDTH - 1 : 0] cmd_write_m64_s_axis_tdata;

	wire cmd_write_m64_m_axis_tvalid;
	wire cmd_write_m64_m_axis_tready;
	wire [`CMD_64_FIFO_WIDTH - 1 : 0] cmd_write_m64_m_axis_tdata;

	// signal from sts fifos for slave register
	wire sts_read_m64_s_axis_tvalid;
	wire sts_read_m64_s_axis_tready;
	wire [`STS_64_FIFO_WIDTH - 1 : 0] sts_read_m64_s_axis_tdata;

	wire sts_read_m64_m_axis_tvalid;
	wire sts_read_m64_m_axis_tready;
	wire [`STS_64_FIFO_WIDTH - 1 : 0] sts_read_m64_m_axis_tdata;

	wire sts_write_m64_s_axis_tvalid;
	wire sts_write_m64_s_axis_tready;
	wire [`STS_64_FIFO_WIDTH - 1 : 0] sts_write_m64_s_axis_tdata;

	wire sts_write_m64_m_axis_tvalid;
	wire sts_write_m64_m_axis_tready;
	wire [`STS_64_FIFO_WIDTH - 1 : 0] sts_write_m64_m_axis_tdata;

	// signal from cmd fifos for ul engine
	wire cmd_read_ul_s_axis_tvalid;
	wire cmd_read_ul_s_axis_tready;
	wire [C_CMD_UL_FIFO_WIDTH - 1 : 0] cmd_read_ul_s_axis_tdata;

	wire cmd_read_ul_m_axis_tvalid;
	wire cmd_read_ul_m_axis_tready;
	wire [C_CMD_UL_FIFO_WIDTH - 1 : 0] cmd_read_ul_m_axis_tdata;

	wire cmd_write_ul_s_axis_tvalid;
	wire cmd_write_ul_s_axis_tready;
	wire [C_CMD_UL_FIFO_WIDTH - 1 : 0] cmd_write_ul_s_axis_tdata;

	wire cmd_write_ul_m_axis_tvalid;
	wire cmd_write_ul_m_axis_tready;
	wire [C_CMD_UL_FIFO_WIDTH - 1 : 0] cmd_write_ul_m_axis_tdata;

	// signal from sts fifos for slave register
	wire sts_read_ul_s_axis_tvalid;
	wire sts_read_ul_s_axis_tready;
	wire [C_STS_UL_FIFO_WIDTH - 1 : 0] sts_read_ul_s_axis_tdata;

	wire sts_read_ul_m_axis_tvalid;
	wire sts_read_ul_m_axis_tready;
	wire [C_STS_UL_FIFO_WIDTH - 1 : 0] sts_read_ul_m_axis_tdata;

	wire sts_write_ul_s_axis_tvalid;
	wire sts_write_ul_s_axis_tready;
	wire [C_STS_UL_FIFO_WIDTH - 1 : 0] sts_write_ul_s_axis_tdata;

	wire sts_write_ul_m_axis_tvalid;
	wire sts_write_ul_m_axis_tready;
	wire [C_STS_UL_FIFO_WIDTH - 1 : 0] sts_write_ul_m_axis_tdata;

	// signals for data width conferion m64 to ul
	wire [C_M64_AXI_DATA_WIDTH/8-1:0] 	m64_to_ul_dwc_s_axis_tstrb;
	wire                              	m64_to_ul_dwc_m_axis_tvalid;
	wire                              	m64_to_ul_dwc_m_axis_tready;
	wire [C_UL_WRITE_AXI_DATA_WIDTH-1:0]   	m64_to_ul_dwc_m_axis_tdata;
	wire [C_UL_WRITE_AXI_DATA_WIDTH/8-1:0] 	m64_to_ul_dwc_m_axis_tstrb;
	wire                              	m64_to_ul_dwc_m_axis_tlast;

	// signals for clock domain crossing ul to m64
	wire [C_UL_READ_AXI_DATA_WIDTH/8-1:0] 	ul_to_m64_cdc_s_axis_tstrb;
	wire                              	ul_to_m64_cdc_m_axis_tvalid;
	wire                              	ul_to_m64_cdc_m_axis_tready;
	wire [C_UL_READ_AXI_DATA_WIDTH-1:0]   	ul_to_m64_cdc_m_axis_tdata;
	wire [C_UL_READ_AXI_DATA_WIDTH/8-1:0] 	ul_to_m64_cdc_m_axis_tstrb;
	wire                              	ul_to_m64_cdc_m_axis_tlast;

	// signals to switch between clocks for chosen ul
	wire s_axi_aclk_new;
	wire m64_axi_aclk_new;
	wire ul_read_axi_aclk_new;
	wire ul_write_axi_aclk_new;
	wire ul_read_axi_aresetn_new;
	wire ul_write_axi_aresetn_new;

	// signals for data path between chosen ul
	wire ul_axi_rvalid;
	wire ul_axi_rready;
	wire ul_axi_rlast;
	wire [C_UL_WRITE_AXI_DATA_WIDTH-1:0] ul_axi_rdata;

	wire ul_axi_wvalid;
	wire ul_axi_wready;
	wire ul_axi_wlast;
	wire [(C_UL_WRITE_AXI_DATA_WIDTH)/8-1:0] ul_axi_wstrb;
	wire [C_UL_WRITE_AXI_DATA_WIDTH-1:0] ul_axi_wdata;

// Instantiation of Axi Bus Interface S_AXI
	dual_dma_v1_0_S_AXI # ( 
		.C_S_AXI_CMD_64_WIDTH(`CMD_64_FIFO_WIDTH),
		.C_S_AXI_CMD_UL_WIDTH(C_CMD_UL_FIFO_WIDTH),
		.C_S_AXI_STS_64_WIDTH(`STS_64_FIFO_WIDTH),
		.C_S_AXI_STS_UL_WIDTH(C_STS_UL_FIFO_WIDTH),
		.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
	) dual_dma_v1_0_S_AXI_inst (
		.IRQ(IRQ),

		.cmd_read_m64_s_axis_tvalid(cmd_read_m64_s_axis_tvalid),
		.cmd_read_m64_s_axis_tready(cmd_read_m64_s_axis_tready),
		.cmd_read_m64_s_axis_tdata(cmd_read_m64_s_axis_tdata),
		.cmd_write_m64_s_axis_tvalid(cmd_write_m64_s_axis_tvalid),
		.cmd_write_m64_s_axis_tready(cmd_write_m64_s_axis_tready),
		.cmd_write_m64_s_axis_tdata(cmd_write_m64_s_axis_tdata),

		.cmd_read_ul_s_axis_tvalid(cmd_read_ul_s_axis_tvalid),
		.cmd_read_ul_s_axis_tready(cmd_read_ul_s_axis_tready),
		.cmd_read_ul_s_axis_tdata(cmd_read_ul_s_axis_tdata),
		.cmd_write_ul_s_axis_tvalid(cmd_write_ul_s_axis_tvalid),
		.cmd_write_ul_s_axis_tready(cmd_write_ul_s_axis_tready),
		.cmd_write_ul_s_axis_tdata(cmd_write_ul_s_axis_tdata),

		.sts_read_m64_m_axis_tvalid(sts_read_m64_m_axis_tvalid),
		.sts_read_m64_m_axis_tready(sts_read_m64_m_axis_tready),
		.sts_read_m64_m_axis_tdata(sts_read_m64_m_axis_tdata),
		.sts_write_m64_m_axis_tvalid(sts_write_m64_m_axis_tvalid),
		.sts_write_m64_m_axis_tready(sts_write_m64_m_axis_tready),
		.sts_write_m64_m_axis_tdata(sts_write_m64_m_axis_tdata),

		.sts_read_ul_m_axis_tvalid(sts_read_ul_m_axis_tvalid),
		.sts_read_ul_m_axis_tready(sts_read_ul_m_axis_tready),
		.sts_read_ul_m_axis_tdata(sts_read_ul_m_axis_tdata),
		.sts_write_ul_m_axis_tvalid(sts_write_ul_m_axis_tvalid),
		.sts_write_ul_m_axis_tready(sts_write_ul_m_axis_tready),
		.sts_write_ul_m_axis_tdata(sts_write_ul_m_axis_tdata),

		.S_AXI_ACLK(s_axi_aclk),
		.S_AXI_ARESETN(s_axi_aresetn),
		.S_AXI_AWADDR(s_axi_awaddr),
		.S_AXI_AWPROT(s_axi_awprot),
		.S_AXI_AWVALID(s_axi_awvalid),
		.S_AXI_AWREADY(s_axi_awready),
		.S_AXI_WDATA(s_axi_wdata),
		.S_AXI_WSTRB(s_axi_wstrb),
		.S_AXI_WVALID(s_axi_wvalid),
		.S_AXI_WREADY(s_axi_wready),
		.S_AXI_BRESP(s_axi_bresp),
		.S_AXI_BVALID(s_axi_bvalid),
		.S_AXI_BREADY(s_axi_bready),
		.S_AXI_ARADDR(s_axi_araddr),
		.S_AXI_ARPROT(s_axi_arprot),
		.S_AXI_ARVALID(s_axi_arvalid),
		.S_AXI_ARREADY(s_axi_arready),
		.S_AXI_RDATA(s_axi_rdata),
		.S_AXI_RRESP(s_axi_rresp),
		.S_AXI_RVALID(s_axi_rvalid),
		.S_AXI_RREADY(s_axi_rready)
	);

// Instantiation of Axi Bus Interface M64_AXI
	dual_dma_v1_0_M64_AXI # ( 
		.C_M_AXI_CMD_64_WIDTH(`CMD_64_FIFO_WIDTH),
		.C_M_AXI_STS_64_WIDTH(`STS_64_FIFO_WIDTH),
		.READ_MAX_REQ(M64_READ_MAX_REQ),
		.WRITE_MAX_REQ(M64_WRITE_MAX_REQ),
		.C_M_AXI_BURST_LEN(C_M64_AXI_BURST_LEN),
		.C_M_AXI_ID_WIDTH(C_M64_AXI_ID_WIDTH),
		.C_M_AXI_ADDR_WIDTH(C_M64_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M64_AXI_DATA_WIDTH),
		.C_M_AXI_AWUSER_WIDTH(C_M64_AXI_AWUSER_WIDTH),
		.C_M_AXI_ARUSER_WIDTH(C_M64_AXI_ARUSER_WIDTH),
		.C_M_AXI_WUSER_WIDTH(C_M64_AXI_WUSER_WIDTH),
		.C_M_AXI_RUSER_WIDTH(C_M64_AXI_RUSER_WIDTH),
		.C_M_AXI_BUSER_WIDTH(C_M64_AXI_BUSER_WIDTH)
	) dual_dma_v1_0_M64_AXI_inst (
		.cmd_read_m64_m_axis_tvalid(cmd_read_m64_m_axis_tvalid),
		.cmd_read_m64_m_axis_tready(cmd_read_m64_m_axis_tready),
		.cmd_read_m64_m_axis_tdata(cmd_read_m64_m_axis_tdata),
		.cmd_write_m64_m_axis_tvalid(cmd_write_m64_m_axis_tvalid),
		.cmd_write_m64_m_axis_tready(cmd_write_m64_m_axis_tready),
		.cmd_write_m64_m_axis_tdata(cmd_write_m64_m_axis_tdata),

		.sts_read_m64_s_axis_tvalid(sts_read_m64_s_axis_tvalid),
		.sts_read_m64_s_axis_tready(sts_read_m64_s_axis_tready),
		.sts_read_m64_s_axis_tdata(sts_read_m64_s_axis_tdata),
		.sts_write_m64_s_axis_tvalid(sts_write_m64_s_axis_tvalid),
		.sts_write_m64_s_axis_tready(sts_write_m64_s_axis_tready),
		.sts_write_m64_s_axis_tdata(sts_write_m64_s_axis_tdata),

		.m64_to_m32_dwc_s_axis_tstrb(m64_to_ul_dwc_s_axis_tstrb),

		.M_AXI_ACLK(m64_axi_aclk),
		.M_AXI_ARESETN(m64_axi_aresetn),
		.M_AXI_AWID(m64_axi_awid),
		.M_AXI_AWADDR(m64_axi_awaddr),
		.M_AXI_AWLEN(m64_axi_awlen),
		.M_AXI_AWSIZE(m64_axi_awsize),
		.M_AXI_AWBURST(m64_axi_awburst),
		.M_AXI_AWLOCK(m64_axi_awlock),
		.M_AXI_AWCACHE(m64_axi_awcache),
		.M_AXI_AWPROT(m64_axi_awprot),
		.M_AXI_AWQOS(m64_axi_awqos),
		.M_AXI_AWUSER(m64_axi_awuser),
		.M_AXI_AWVALID(m64_axi_awvalid),
		.M_AXI_AWREADY(m64_axi_awready),
		//.M_AXI_WDATA(m64_axi_wdata),
		//.M_AXI_WSTRB(m64_axi_wstrb),
		.M_AXI_WLAST(m64_axi_wlast),
		.M_AXI_WUSER(m64_axi_wuser),
		.M_AXI_WVALID(m64_axi_wvalid),
		.M_AXI_WREADY(m64_axi_wready),
		.M_AXI_BID(m64_axi_bid),
		.M_AXI_BRESP(m64_axi_bresp),
		.M_AXI_BUSER(m64_axi_buser),
		.M_AXI_BVALID(m64_axi_bvalid),
		.M_AXI_BREADY(m64_axi_bready),
		.M_AXI_ARID(m64_axi_arid),
		.M_AXI_ARADDR(m64_axi_araddr),
		.M_AXI_ARLEN(m64_axi_arlen),
		.M_AXI_ARSIZE(m64_axi_arsize),
		.M_AXI_ARBURST(m64_axi_arburst),
		.M_AXI_ARLOCK(m64_axi_arlock),
		.M_AXI_ARCACHE(m64_axi_arcache),
		.M_AXI_ARPROT(m64_axi_arprot),
		.M_AXI_ARQOS(m64_axi_arqos),
		.M_AXI_ARUSER(m64_axi_aruser),
		.M_AXI_ARVALID(m64_axi_arvalid),
		.M_AXI_ARREADY(m64_axi_arready),
		.M_AXI_RID(m64_axi_rid),
		//.M_AXI_RDATA(m64_axi_rdata),
		.M_AXI_RRESP(m64_axi_rresp),
		.M_AXI_RLAST(m64_axi_rlast),
		.M_AXI_RUSER(m64_axi_ruser),
		.M_AXI_RVALID(m64_axi_rvalid),
		.M_AXI_RREADY(m64_axi_rready)
	);

// Instantiation of Axi Bus Interface M32_AXI
    generate
      if(STREAM_ENABLE == 0)
	begin: m32_module

	dual_dma_v1_0_M32_AXI # ( 
		.C_M_AXI_CMD_32_WIDTH(`CMD_32_FIFO_WIDTH),
		.C_M_AXI_STS_32_WIDTH(`STS_32_FIFO_WIDTH),
		.READ_MAX_REQ(M32_READ_MAX_REQ),
		.WRITE_MAX_REQ(M32_WRITE_MAX_REQ),
		.C_M_AXI_BURST_LEN(C_M32_AXI_BURST_LEN),
		.C_M_AXI_ID_WIDTH(C_M32_AXI_ID_WIDTH),
		.C_M_AXI_ADDR_WIDTH(C_M32_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M32_AXI_DATA_WIDTH),
		.C_M_AXI_AWUSER_WIDTH(C_M32_AXI_AWUSER_WIDTH),
		.C_M_AXI_ARUSER_WIDTH(C_M32_AXI_ARUSER_WIDTH),
		.C_M_AXI_WUSER_WIDTH(C_M32_AXI_WUSER_WIDTH),
		.C_M_AXI_RUSER_WIDTH(C_M32_AXI_RUSER_WIDTH),
		.C_M_AXI_BUSER_WIDTH(C_M32_AXI_BUSER_WIDTH)
	) dual_dma_v1_0_M32_AXI_inst (
		.cmd_read_m32_m_axis_tvalid(cmd_read_ul_m_axis_tvalid),
		.cmd_read_m32_m_axis_tready(cmd_read_ul_m_axis_tready),
		.cmd_read_m32_m_axis_tdata(cmd_read_ul_m_axis_tdata),
		.cmd_write_m32_m_axis_tvalid(cmd_write_ul_m_axis_tvalid),
		.cmd_write_m32_m_axis_tready(cmd_write_ul_m_axis_tready),
		.cmd_write_m32_m_axis_tdata(cmd_write_ul_m_axis_tdata),

		.sts_read_m32_s_axis_tvalid(sts_read_ul_s_axis_tvalid),
		.sts_read_m32_s_axis_tready(sts_read_ul_s_axis_tready),
		.sts_read_m32_s_axis_tdata(sts_read_ul_s_axis_tdata),
		.sts_write_m32_s_axis_tvalid(sts_write_ul_s_axis_tvalid),
		.sts_write_m32_s_axis_tready(sts_write_ul_s_axis_tready),
		.sts_write_m32_s_axis_tdata(sts_write_ul_s_axis_tdata),

		.m32_to_m64_cdc_s_axis_tstrb(ul_to_m64_cdc_s_axis_tstrb),

		.M_AXI_ACLK(m32_axi_aclk),
		.M_AXI_ARESETN(m32_axi_aresetn),
		.M_AXI_AWID(m32_axi_awid),
		.M_AXI_AWADDR(m32_axi_awaddr),
		.M_AXI_AWLEN(m32_axi_awlen),
		.M_AXI_AWSIZE(m32_axi_awsize),
		.M_AXI_AWBURST(m32_axi_awburst),
		.M_AXI_AWLOCK(m32_axi_awlock),
		.M_AXI_AWCACHE(m32_axi_awcache),
		.M_AXI_AWPROT(m32_axi_awprot),
		.M_AXI_AWQOS(m32_axi_awqos),
		.M_AXI_AWUSER(m32_axi_awuser),
		.M_AXI_AWVALID(m32_axi_awvalid),
		.M_AXI_AWREADY(m32_axi_awready),
		//.M_AXI_WDATA(m32_axi_wdata),
		//.M_AXI_WSTRB(m32_axi_wstrb),
		.M_AXI_WLAST(m32_axi_wlast),
		.M_AXI_WUSER(m32_axi_wuser),
		.M_AXI_WVALID(m32_axi_wvalid),
		.M_AXI_WREADY(m32_axi_wready),
		.M_AXI_BID(m32_axi_bid),
		.M_AXI_BRESP(m32_axi_bresp),
		.M_AXI_BUSER(m32_axi_buser),
		.M_AXI_BVALID(m32_axi_bvalid),
		.M_AXI_BREADY(m32_axi_bready),
		.M_AXI_ARID(m32_axi_arid),
		.M_AXI_ARADDR(m32_axi_araddr),
		.M_AXI_ARLEN(m32_axi_arlen),
		.M_AXI_ARSIZE(m32_axi_arsize),
		.M_AXI_ARBURST(m32_axi_arburst),
		.M_AXI_ARLOCK(m32_axi_arlock),
		.M_AXI_ARCACHE(m32_axi_arcache),
		.M_AXI_ARPROT(m32_axi_arprot),
		.M_AXI_ARQOS(m32_axi_arqos),
		.M_AXI_ARUSER(m32_axi_aruser),
		.M_AXI_ARVALID(m32_axi_arvalid),
		.M_AXI_ARREADY(m32_axi_arready),
		.M_AXI_RID(m32_axi_rid),
		//.M_AXI_RDATA(m32_axi_rdata),
		.M_AXI_RRESP(m32_axi_rresp),
		.M_AXI_RLAST(m32_axi_rlast),
		.M_AXI_RUSER(m32_axi_ruser),
		.M_AXI_RVALID(m32_axi_rvalid),
		.M_AXI_RREADY(m32_axi_rready)
	);

	end
      else
	begin :str_modules

// Instantiation of Axi Bus Interface S_AXIS
	dual_dma_v1_0_S_AXIS # ( 
		.C_M_AXI_CMD_STR_WIDTH(`CMD_STR_FIFO_WIDTH),
		.C_M_AXI_STS_STR_WIDTH(`STS_STR_FIFO_WIDTH),
		.C_M64_AXI_DATA_WIDTH(C_M64_AXI_DATA_WIDTH),
		.C_S_AXIS_BURST_LEN(C_S_AXIS_BURST_LEN),
		.C_S_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH)
	) dual_dma_v1_0_S_AXIS_inst (
		.cmd_read_str_m_axis_tvalid(cmd_read_ul_m_axis_tvalid),
		.cmd_read_str_m_axis_tready(cmd_read_ul_m_axis_tready),
		.cmd_read_str_m_axis_tdata(cmd_read_ul_m_axis_tdata),

		.sts_read_str_s_axis_tvalid(sts_read_ul_s_axis_tvalid),
		.sts_read_str_s_axis_tready(sts_read_ul_s_axis_tready),
		.sts_read_str_s_axis_tdata(sts_read_ul_s_axis_tdata),

		.str_to_m64_cdc_s_axis_tstrb(ul_to_m64_cdc_s_axis_tstrb),
		.ul_axi_rready(ul_axi_rready),
		.ul_axi_rvalid(ul_axi_rvalid),
		.ul_axi_rlast(ul_axi_rlast),

		.S_AXIS_ACLK(s_axis_aclk),
		.S_AXIS_ARESETN(s_axis_aresetn),
		.S_AXIS_TREADY(s_axis_tready),
		//.S_AXIS_TDATA(s_axis_tdata),
		//.S_AXIS_TSTRB(s_axis_tstrb),
		//.S_AXIS_TLAST(s_axis_tlast),
		.S_AXIS_TVALID(s_axis_tvalid)
	);

// Instantiation of Axi Bus Interface M_AXIS
	dual_dma_v1_0_M_AXIS # ( 
		.C_M_AXI_CMD_STR_WIDTH(`CMD_STR_FIFO_WIDTH),
		.C_M_AXI_STS_STR_WIDTH(`STS_STR_FIFO_WIDTH),
		.C_M_AXIS_BURST_LEN(C_M_AXIS_BURST_LEN),
		.C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH)
	) dual_dma_v1_0_M_AXIS_inst (
		.cmd_write_str_m_axis_tvalid(cmd_write_ul_m_axis_tvalid),
		.cmd_write_str_m_axis_tready(cmd_write_ul_m_axis_tready),
		.cmd_write_str_m_axis_tdata(cmd_write_ul_m_axis_tdata),

		.sts_write_str_s_axis_tvalid(sts_write_ul_s_axis_tvalid),
		.sts_write_str_s_axis_tready(sts_write_ul_s_axis_tready),
		.sts_write_str_s_axis_tdata(sts_write_ul_s_axis_tdata),

		.ul_axi_wready(ul_axi_wready),
		.ul_axi_wvalid(ul_axi_wvalid),
		.ul_axi_wlast(ul_axi_wlast),

		.M_AXIS_ACLK(m_axis_aclk),
		.M_AXIS_ARESETN(m_axis_aresetn),
		.M_AXIS_TVALID(m_axis_tvalid),
		//.M_AXIS_TDATA(m_axis_tdata),
		//.M_AXIS_TSTRB(m_axis_tstrb),
		.M_AXIS_TLAST(m_axis_tlast),
		.M_AXIS_TREADY(m_axis_tready)
	);

	end
    endgenerate

	// Add user logic here

	// FIFO parameter

	// C_AXIS_SIGNAL_SET: each bit if enabled specifies which axis optional signals are present
	//   [0] => TREADY present
	//   [1] => TDATA present
	//   [2] => TSTRB present, TDATA must be present
	//   [3] => TKEEP present, TDATA must be present
	//   [4] => TLAST present
	//   [5] => TID present
	//   [6] => TDEST present
	//   [7] => TUSER present

	// C_FIFO_MODE Values: 
	//   0 == N0 FIFO
	//   1 == Regular FIFO
	//   2 == Store and Forward FIFO (Packet Mode). Requires TLAST.

	// C_IS_ACLK_ASYNC
	//  Enables async clock cross when 1.

	// C_SYNCHRONIZER_STAGE
	// Specifies the number of synchronization stages to implement

	// C_ACLKEN_CONV_MODE: Determines how to handle the clock enable pins during
	// clock conversion
	// 0 -- Clock enables not converted
	// 1 -- S_AXIS_ACLKEN can toggle,  M_AXIS_ACLKEN always high.
	// 2 -- S_AXIS_ACLKEN always high, M_AXIS_ACLKEN can toggle.
	// 3 -- S_AXIS_ACLKEN can toggle,  M_AXIS_ACLKEN can toggle.

	// FIXME: Workaround, otherwise simulation bfm complains, 
	// that reset does not comeback correctly???

	assign s_axi_aclk_new = s_axi_aclk;
	assign m64_axi_aclk_new = m64_axi_aclk;

    generate
      if(STREAM_ENABLE == 0)
	begin :m32_wires

	assign ul_read_axi_aclk_new = m32_axi_aclk;
	assign ul_write_axi_aclk_new = m32_axi_aclk;
	assign ul_read_axi_aresetn_new = m32_axi_aresetn;
	assign ul_write_axi_aresetn_new = m32_axi_aresetn;

	end
      else
	begin :str_wires

	assign ul_read_axi_aclk_new = s_axis_aclk;
	assign ul_write_axi_aclk_new = m_axis_aclk;
	assign ul_read_axi_aresetn_new = s_axis_aresetn;
	assign ul_write_axi_aresetn_new = m_axis_aresetn;

	end
    endgenerate

	// cmd fifos to m64
	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(`CMD_64_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(M64_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) cmd_read_fifo_m64 (
	    .s_axis_aresetn(s_axi_aresetn),
	    .m_axis_aresetn(m64_axi_aresetn),
	    .s_axis_aclk(s_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(cmd_read_m64_s_axis_tvalid),
	    .s_axis_tready(cmd_read_m64_s_axis_tready),
	    .s_axis_tdata(cmd_read_m64_s_axis_tdata),
	    .s_axis_tstrb({`CMD_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({`CMD_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(m64_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(cmd_read_m64_m_axis_tvalid),
	    .m_axis_tready(cmd_read_m64_m_axis_tready),
	    .m_axis_tdata(cmd_read_m64_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );	

	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(`CMD_64_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(M64_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) cmd_write_fifo_m64 (
	    .s_axis_aresetn(s_axi_aresetn),
	    .m_axis_aresetn(m64_axi_aresetn),
	    .s_axis_aclk(s_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(cmd_write_m64_s_axis_tvalid),
	    .s_axis_tready(cmd_write_m64_s_axis_tready),
	    .s_axis_tdata(cmd_write_m64_s_axis_tdata),
	    .s_axis_tstrb({`CMD_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({`CMD_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(m64_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(cmd_write_m64_m_axis_tvalid),
	    .m_axis_tready(cmd_write_m64_m_axis_tready),
	    .m_axis_tdata(cmd_write_m64_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	// cmd fifos to ul
	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(C_CMD_UL_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(UL_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) cmd_read_fifo_ul (
	    .s_axis_aresetn(s_axi_aresetn),
	    .m_axis_aresetn(ul_read_axi_aresetn_new),
	    .s_axis_aclk(s_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(cmd_read_ul_s_axis_tvalid),
	    .s_axis_tready(cmd_read_ul_s_axis_tready),
	    .s_axis_tdata(cmd_read_ul_s_axis_tdata),
	    .s_axis_tstrb({C_CMD_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({C_CMD_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(ul_read_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(cmd_read_ul_m_axis_tvalid),
	    .m_axis_tready(cmd_read_ul_m_axis_tready),
	    .m_axis_tdata(cmd_read_ul_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(C_CMD_UL_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(UL_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) cmd_write_fifo_ul (
	    .s_axis_aresetn(s_axi_aresetn),
	    .m_axis_aresetn(ul_write_axi_aresetn_new),
	    .s_axis_aclk(s_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(cmd_write_ul_s_axis_tvalid),
	    .s_axis_tready(cmd_write_ul_s_axis_tready),
	    .s_axis_tdata(cmd_write_ul_s_axis_tdata),
	    .s_axis_tstrb({C_CMD_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({C_CMD_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(ul_write_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(cmd_write_ul_m_axis_tvalid),
	    .m_axis_tready(cmd_write_ul_m_axis_tready),
	    .m_axis_tdata(cmd_write_ul_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	// sts fifos to m64
	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(`STS_64_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(M64_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) sts_read_fifo_m64 (
	    .s_axis_aresetn(m64_axi_aresetn),
	    .m_axis_aresetn(s_axi_aresetn),
	    .s_axis_aclk(m64_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(sts_read_m64_s_axis_tvalid),
	    .s_axis_tready(sts_read_m64_s_axis_tready),
	    .s_axis_tdata(sts_read_m64_s_axis_tdata),
	    .s_axis_tstrb({`STS_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({`STS_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(s_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(sts_read_m64_m_axis_tvalid),
	    .m_axis_tready(sts_read_m64_m_axis_tready),
	    .m_axis_tdata(sts_read_m64_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );	

	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(`STS_64_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(M64_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) sts_write_fifo_m64 (
	    .s_axis_aresetn(m64_axi_aresetn),
	    .m_axis_aresetn(s_axi_aresetn),
	    .s_axis_aclk(m64_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(sts_write_m64_s_axis_tvalid),
	    .s_axis_tready(sts_write_m64_s_axis_tready),
	    .s_axis_tdata(sts_write_m64_s_axis_tdata),
	    .s_axis_tstrb({`STS_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({`STS_64_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(s_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(sts_write_m64_m_axis_tvalid),
	    .m_axis_tready(sts_write_m64_m_axis_tready),
	    .m_axis_tdata(sts_write_m64_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	// sts fifos to ul
	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(C_STS_UL_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(UL_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) sts_read_fifo_ul (
	    .s_axis_aresetn(ul_read_axi_aresetn_new),
	    .m_axis_aresetn(s_axi_aresetn),
	    .s_axis_aclk(ul_read_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(sts_read_ul_s_axis_tvalid),
	    .s_axis_tready(sts_read_ul_s_axis_tready),
	    .s_axis_tdata(sts_read_ul_s_axis_tdata),
	    .s_axis_tstrb({C_STS_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({C_STS_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(s_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(sts_read_ul_m_axis_tvalid),
	    .m_axis_tready(sts_read_ul_m_axis_tready),
	    .m_axis_tdata(sts_read_ul_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(C_STS_UL_FIFO_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h03),
	    .C_FIFO_DEPTH(CMD_STS_FIFO_DEPTH),
	    .C_FIFO_MODE(1),
	    .C_IS_ACLK_ASYNC(UL_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) sts_write_fifo_ul (
	    .s_axis_aresetn(ul_write_axi_aresetn_new),
	    .m_axis_aresetn(s_axi_aresetn),
	    .s_axis_aclk(ul_write_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(sts_write_ul_s_axis_tvalid),
	    .s_axis_tready(sts_write_ul_s_axis_tready),
	    .s_axis_tdata(sts_write_ul_s_axis_tdata),
	    .s_axis_tstrb({C_STS_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tkeep({C_STS_UL_FIFO_WIDTH/8{1'b1}}),
	    .s_axis_tlast(1'b1),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(s_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(sts_write_ul_m_axis_tvalid),
	    .m_axis_tready(sts_write_ul_m_axis_tready),
	    .m_axis_tdata(sts_write_ul_m_axis_tdata),
	    .m_axis_tstrb(),
	    .m_axis_tkeep(),
	    .m_axis_tlast(),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	// C_AXIS_SIGNAL_SET: each bit if enabled specifies which axis optional signals are present
	//   [0] => TREADY present (Required)
	//   [1] => TDATA present (Required, used to calculate ratios)
	//   [2] => TSTRB present, TDATA must be present
	//   [3] => TKEEP present, TDATA must be present (Required if TLAST, TID,
	//   TDEST present
	//   [4] => TLAST present
	//   [5] => TID present
	//   [6] => TDEST present
	//   [7] => TUSER present
	// Ratio of C_S_AXIS_TDATA_WIDTH : C_M_AXIS_TDATA_WIDTH must be the same as 
	// the ratio of C_S_AXIS_TUSER_WIDTH : C_M_AXIS_TUSER_WIDTH if USER signals are present.

    generate
      if(STREAM_ENABLE == 0)
	begin :m32_data

	assign ul_axi_rvalid = m32_axi_rvalid;
	assign m32_axi_rready = ul_axi_rready;
	assign ul_axi_rlast = m32_axi_rlast;
	assign ul_axi_rdata = m32_axi_rdata;

	assign m32_axi_wvalid = ul_axi_wvalid;
	assign ul_axi_wready = m32_axi_wready;
	assign m32_axi_wlast = ul_axi_wlast;
	assign m32_axi_wstrb = ul_axi_wstrb;
	assign m32_axi_wdata = ul_axi_wdata;

	end
      else
	begin :str_data

	//Overwrite from fsm of S_AXIS to capsulate each data transfer
	//assign ul_axi_rvalid = s_axis_tvalid;
	//assign s_axis_tready = ul_axi_rready;
	//assign ul_axi_rlast = s_axis_tlast;
	assign ul_axi_rdata = s_axis_tdata;

	//Overwrite from fsm of S_AXIS to capsulate each data transfer
	//assign m_axis_tvalid = ul_axi_wvalid;
	//assign ul_axi_wready = m_axis_tready;
	//assign m_axis_tlast = ul_axi_wlast;
	assign m_axis_tstrb = ul_axi_wstrb;
	assign m_axis_tdata = ul_axi_wdata;

	end
    endgenerate

	// data width conversion for m64 to ul	
	axis_dwidth_converter_v1_1_6_axis_dwidth_converter #(
	    .C_FAMILY("virtex"),
	    .C_S_AXIS_TDATA_WIDTH(C_M64_AXI_DATA_WIDTH),
	    .C_M_AXIS_TDATA_WIDTH(C_UL_WRITE_AXI_DATA_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_S_AXIS_TUSER_WIDTH(1),
	    .C_M_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h1F)
	) m64_to_ul_dwidth_converter (
	    .aclk(m64_axi_aclk_new),
	    .aresetn(m64_axi_aresetn),
	    .aclken(1'b1),
	    .s_axis_tvalid(m64_axi_rvalid),
	    .s_axis_tready(m64_axi_rready),
	    .s_axis_tdata(m64_axi_rdata),
	    .s_axis_tstrb(m64_to_ul_dwc_s_axis_tstrb),
	    //.s_axis_tkeep({(C_M64_AXI_DATA_WIDTH/8){1'b1}}),
	    .s_axis_tkeep(m64_to_ul_dwc_s_axis_tstrb),
	    .s_axis_tlast(m64_axi_rlast),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_tvalid(m64_to_ul_dwc_m_axis_tvalid),
	    .m_axis_tready(m64_to_ul_dwc_m_axis_tready),
	    .m_axis_tdata(m64_to_ul_dwc_m_axis_tdata),
	    .m_axis_tstrb(m64_to_ul_dwc_m_axis_tstrb),
	    .m_axis_tkeep(),
	    .m_axis_tlast(m64_to_ul_dwc_m_axis_tlast),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser()
	);

	// clock conversion from m64_to_ul_dwc to ul	
	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(C_UL_WRITE_AXI_DATA_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h1F),
	    .C_FIFO_DEPTH(DATA_FIFO_DEPTH),
	    .C_FIFO_MODE(DATA_FIFO_MODE),
	    .C_IS_ACLK_ASYNC(UL_IS_ASYNC || M64_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) data_fifo_m64_to_ul (
	    .s_axis_aresetn(m64_axi_aresetn),
	    .m_axis_aresetn(ul_write_axi_aresetn_new),
	    .s_axis_aclk(m64_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(m64_to_ul_dwc_m_axis_tvalid),
	    .s_axis_tready(m64_to_ul_dwc_m_axis_tready),
	    .s_axis_tdata(m64_to_ul_dwc_m_axis_tdata),
	    .s_axis_tstrb(m64_to_ul_dwc_m_axis_tstrb),
	    .s_axis_tkeep(m64_to_ul_dwc_m_axis_tstrb),
	    .s_axis_tlast(m64_to_ul_dwc_m_axis_tlast),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(ul_write_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(ul_axi_wvalid),
	    .m_axis_tready(ul_axi_wready),
	    .m_axis_tdata(ul_axi_wdata),
	    .m_axis_tstrb(ul_axi_wstrb),
	    .m_axis_tkeep(),
	    .m_axis_tlast(ul_axi_wlast),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	// clock conversion from ul to ul_to_m64_cdc	
	axis_data_fifo_v1_1_8_axis_data_fifo #(
	    .C_FAMILY("virtex"),
	    .C_AXIS_TDATA_WIDTH(C_UL_READ_AXI_DATA_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h1F),
	    .C_FIFO_DEPTH(DATA_FIFO_DEPTH),
	    .C_FIFO_MODE(DATA_FIFO_MODE),
	    .C_IS_ACLK_ASYNC(UL_IS_ASYNC || M64_IS_ASYNC),
	    .C_SYNCHRONIZER_STAGE(FIFO_SYNC_STAGES),
	    .C_ACLKEN_CONV_MODE(0)
	  ) data_fifo_ul_to_m64 (
	    .s_axis_aresetn(ul_read_axi_aresetn_new),
	    .m_axis_aresetn(m64_axi_aresetn),
	    .s_axis_aclk(ul_read_axi_aclk_new),
	    .s_axis_aclken(1'b1),
	    .s_axis_tvalid(ul_axi_rvalid),
	    .s_axis_tready(ul_axi_rready),
	    .s_axis_tdata(ul_axi_rdata),
	    .s_axis_tstrb(ul_to_m64_cdc_s_axis_tstrb),
	    //.s_axis_tkeep({(C_M32_AXI_DATA_WIDTH/8){1'b1}}),
	    .s_axis_tkeep(ul_to_m64_cdc_s_axis_tstrb),
	    .s_axis_tlast(ul_axi_rlast),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_aclk(m64_axi_aclk_new),
	    .m_axis_aclken(1'b1),
	    .m_axis_tvalid(ul_to_m64_cdc_m_axis_tvalid),
	    .m_axis_tready(ul_to_m64_cdc_m_axis_tready),
	    .m_axis_tdata(ul_to_m64_cdc_m_axis_tdata),
	    .m_axis_tstrb(ul_to_m64_cdc_m_axis_tstrb),
	    .m_axis_tkeep(),
	    .m_axis_tlast(ul_to_m64_cdc_m_axis_tlast),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser(),
	    .axis_data_count(),
	    .axis_wr_data_count(),
	    .axis_rd_data_count()
	  );

	// converting data width from ul_to_m64_cdc to m64	
	axis_dwidth_converter_v1_1_6_axis_dwidth_converter #(
	    .C_FAMILY("virtex"),
	    .C_S_AXIS_TDATA_WIDTH(C_UL_READ_AXI_DATA_WIDTH),
	    .C_M_AXIS_TDATA_WIDTH(C_M64_AXI_DATA_WIDTH),
	    .C_AXIS_TID_WIDTH(1),
	    .C_AXIS_TDEST_WIDTH(1),
	    .C_S_AXIS_TUSER_WIDTH(1),
	    .C_M_AXIS_TUSER_WIDTH(1),
	    .C_AXIS_SIGNAL_SET(32'h1F)
	) ul_to_m64_dwidth_converter (
	    .aclk(m64_axi_aclk_new),
	    .aresetn(m64_axi_aresetn),
	    .aclken(1'b1),
	    .s_axis_tvalid(ul_to_m64_cdc_m_axis_tvalid),
	    .s_axis_tready(ul_to_m64_cdc_m_axis_tready),
	    .s_axis_tdata(ul_to_m64_cdc_m_axis_tdata),
	    .s_axis_tstrb(ul_to_m64_cdc_m_axis_tstrb),
	    .s_axis_tkeep(ul_to_m64_cdc_m_axis_tstrb),
	    .s_axis_tlast(ul_to_m64_cdc_m_axis_tlast),
	    .s_axis_tid(1'b0),
	    .s_axis_tdest(1'b0),
	    .s_axis_tuser(1'b0),
	    .m_axis_tvalid(m64_axi_wvalid),
	    .m_axis_tready(m64_axi_wready),
	    .m_axis_tdata(m64_axi_wdata),
	    .m_axis_tstrb(m64_axi_wstrb),
	    .m_axis_tkeep(),
	    .m_axis_tlast(m64_axi_wlast),
	    .m_axis_tid(),
	    .m_axis_tdest(),
	    .m_axis_tuser()
	);

	// User logic ends

	endmodule
