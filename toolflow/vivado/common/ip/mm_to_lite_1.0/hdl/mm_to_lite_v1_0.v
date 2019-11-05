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

	module mm_to_lite_v1_0 #
	(
		// Users to add parameters here

		parameter integer MM_SLICE_ENABLE	= 0,

		parameter integer MM_CONFIG_AW	= 0,
		parameter integer MM_CONFIG_W	= 0,
		parameter integer MM_CONFIG_B	= 0,
		parameter integer MM_CONFIG_AR	= 0,
		parameter integer MM_CONFIG_R	= 0,

		parameter integer LITE_SLICE_ENABLE	= 0,

		parameter integer LITE_CONFIG_AW	= 0,
		parameter integer LITE_CONFIG_W		= 0,
		parameter integer LITE_CONFIG_B		= 0,
		parameter integer LITE_CONFIG_AR	= 0,
		parameter integer LITE_CONFIG_R		= 0,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Parameters of Axi Slave Bus Interface S_AXI
		parameter integer C_S_AXI_ID_WIDTH	= 1,
		parameter integer C_S_AXI_DATA_WIDTH	= 256,
		parameter integer C_S_AXI_ADDR_WIDTH	= 32,

		// Parameters of Axi Slave User Signals
		parameter integer C_S_AXI_AWUSER_WIDTH	= 1,
		parameter integer C_S_AXI_ARUSER_WIDTH	= 1,
		parameter integer C_S_AXI_WUSER_WIDTH	= 1,
		parameter integer C_S_AXI_RUSER_WIDTH	= 1,
		parameter integer C_S_AXI_BUSER_WIDTH	= 1,

		// Parameters of Axi Master Bus Interface M_AXI_LITE
		parameter  C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		parameter integer C_M_AXI_LITE_ADDR_WIDTH	= 32,
		parameter integer C_M_AXI_LITE_DATA_WIDTH	= 32
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Ports of Axi Slave Bus Interface S_AXI
		input wire  s_axi_aclk,
		input wire  s_axi_aresetn,
		input wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_awid,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
		input wire [7 : 0] s_axi_awlen,
		input wire [2 : 0] s_axi_awsize,
		input wire [1 : 0] s_axi_awburst,
		input wire  s_axi_awlock,
		input wire [3 : 0] s_axi_awcache,
		input wire [2 : 0] s_axi_awprot,
		//input wire [3 : 0] s_axi_awqos,
		input wire [3 : 0] s_axi_awregion,
		input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] s_axi_awuser,
		input wire  s_axi_awvalid,
		output wire  s_axi_awready,
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
		input wire  s_axi_wlast,
		input wire [C_S_AXI_WUSER_WIDTH-1 : 0] s_axi_wuser,
		input wire  s_axi_wvalid,
		output wire  s_axi_wready,
		output wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_bid,
		output wire [1 : 0] s_axi_bresp,
		output wire [C_S_AXI_BUSER_WIDTH-1 : 0] s_axi_buser,
		output wire  s_axi_bvalid,
		input wire  s_axi_bready,
		input wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_arid,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
		input wire [7 : 0] s_axi_arlen,
		input wire [2 : 0] s_axi_arsize,
		input wire [1 : 0] s_axi_arburst,
		input wire  s_axi_arlock,
		input wire [3 : 0] s_axi_arcache,
		input wire [2 : 0] s_axi_arprot,
		//input wire [3 : 0] s_axi_arqos,
		input wire [3 : 0] s_axi_arregion,
		input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] s_axi_aruser,
		input wire  s_axi_arvalid,
		output wire  s_axi_arready,
		output wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_rid,
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
		output wire [1 : 0] s_axi_rresp,
		output wire  s_axi_rlast,
		output wire [C_S_AXI_RUSER_WIDTH-1 : 0] s_axi_ruser,
		output wire  s_axi_rvalid,
		input wire  s_axi_rready,

		// Ports of Axi Master Bus Interface M_AXI_LITE
		input wire  m_axi_lite_aclk,
		input wire  m_axi_lite_aresetn,
		output wire [C_M_AXI_LITE_ADDR_WIDTH-1 : 0] m_axi_lite_awaddr,
		output wire [2 : 0] m_axi_lite_awprot,
		output wire  m_axi_lite_awvalid,
		input wire  m_axi_lite_awready,
		output wire [C_M_AXI_LITE_DATA_WIDTH-1 : 0] m_axi_lite_wdata,
		output wire [C_M_AXI_LITE_DATA_WIDTH/8-1 : 0] m_axi_lite_wstrb,
		output wire  m_axi_lite_wvalid,
		input wire  m_axi_lite_wready,
		input wire [1 : 0] m_axi_lite_bresp,
		input wire  m_axi_lite_bvalid,
		output wire  m_axi_lite_bready,
		output wire [C_M_AXI_LITE_ADDR_WIDTH-1 : 0] m_axi_lite_araddr,
		output wire [2 : 0] m_axi_lite_arprot,
		output wire  m_axi_lite_arvalid,
		input wire  m_axi_lite_arready,
		input wire [C_M_AXI_LITE_DATA_WIDTH-1 : 0] m_axi_lite_rdata,
		input wire [1 : 0] m_axi_lite_rresp,
		input wire  m_axi_lite_rvalid,
		output wire  m_axi_lite_rready
	);

	// wires for S_AXI direct/register-slice connection
	wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_dd_awid;
	wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_dd_awaddr;
	wire [7 : 0] s_axi_dd_awlen;
	wire [2 : 0] s_axi_dd_awsize;
	wire [1 : 0] s_axi_dd_awburst;
	wire  s_axi_dd_awlock;
	wire [3 : 0] s_axi_dd_awcache;
	wire [2 : 0] s_axi_dd_awprot;
	wire [3 : 0] s_axi_dd_awqos;
	wire [3 : 0] s_axi_dd_awregion;
	wire [C_S_AXI_AWUSER_WIDTH-1 : 0] s_axi_dd_awuser;
	wire  s_axi_dd_awvalid;
	wire  s_axi_dd_awready;
	wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_dd_wdata;
	wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_dd_wstrb;
	wire  s_axi_dd_wlast;
	wire [C_S_AXI_WUSER_WIDTH-1 : 0] s_axi_dd_wuser;
	wire  s_axi_dd_wvalid;
	wire  s_axi_dd_wready;
	wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_dd_bid;
	wire [1 : 0] s_axi_dd_bresp;
	wire [C_S_AXI_BUSER_WIDTH-1 : 0] s_axi_dd_buser;
	wire  s_axi_dd_bvalid;
	wire  s_axi_dd_bready;
	wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_dd_arid;
	wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_dd_araddr;
	wire [7 : 0] s_axi_dd_arlen;
	wire [2 : 0] s_axi_dd_arsize;
	wire [1 : 0] s_axi_dd_arburst;
	wire  s_axi_dd_arlock;
	wire [3 : 0] s_axi_dd_arcache;
	wire [2 : 0] s_axi_dd_arprot;
	wire [3 : 0] s_axi_dd_arqos;
	wire [3 : 0] s_axi_dd_arregion;
	wire [C_S_AXI_ARUSER_WIDTH-1 : 0] s_axi_dd_aruser;
	wire  s_axi_dd_arvalid;
	wire  s_axi_dd_arready;
	wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_dd_rid;
	wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_dd_rdata;
	wire [1 : 0] s_axi_dd_rresp;
	wire  s_axi_dd_rlast;
	wire [C_S_AXI_RUSER_WIDTH-1 : 0] s_axi_dd_ruser;
	wire  s_axi_dd_rvalid;
	wire  s_axi_dd_rready;

	// qos currently not supported, held locally to supress critical warning
	wire [3 : 0] s_axi_arqos;
	wire [3 : 0] s_axi_awqos;
	assign s_axi_arqos = 4'b0000;
	assign s_axi_awqos = 4'b0000;

	// wires for M_AXI_LITE direct/register-slice connection
	wire [C_M_AXI_LITE_ADDR_WIDTH-1 : 0] m_axi_dd_lite_awaddr;
	wire [2 : 0] m_axi_dd_lite_awprot;
	wire  m_axi_dd_lite_awvalid;
	wire  m_axi_dd_lite_awready;
	wire [C_M_AXI_LITE_DATA_WIDTH-1 : 0] m_axi_dd_lite_wdata;
	wire [C_M_AXI_LITE_DATA_WIDTH/8-1 : 0] m_axi_dd_lite_wstrb;
	wire  m_axi_dd_lite_wvalid;
	wire  m_axi_dd_lite_wready;
	wire [1 : 0] m_axi_dd_lite_bresp;
	wire  m_axi_dd_lite_bvalid;
	wire  m_axi_dd_lite_bready;
	wire [C_M_AXI_LITE_ADDR_WIDTH-1 : 0] m_axi_dd_lite_araddr;
	wire [2 : 0] m_axi_dd_lite_arprot;
	wire  m_axi_dd_lite_arvalid;
	wire  m_axi_dd_lite_arready;
	wire [C_M_AXI_LITE_DATA_WIDTH-1 : 0] m_axi_dd_lite_rdata;
	wire [1 : 0] m_axi_dd_lite_rresp;
	wire  m_axi_dd_lite_rvalid;
	wire  m_axi_dd_lite_rready;

	wire start_write;
	wire [C_M_AXI_LITE_ADDR_WIDTH-1 : 0] s_axi_awaddr_dd;
	wire [C_M_AXI_LITE_DATA_WIDTH-1 : 0] s_axi_wdata_dd;
	wire end_write;

	wire start_read;
	wire [C_M_AXI_LITE_ADDR_WIDTH-1 : 0] s_axi_araddr_dd;
	wire [C_M_AXI_LITE_DATA_WIDTH-1 : 0] m_axi_rdata_dd;
	wire end_read;

	// Instantiation of Axi Bus Interface S_AXI
	mm_to_lite_v1_0_S_AXI # ( 
		.C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
		.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M_AXI_LITE_DATA_WIDTH),
		.C_S_AXI_AWUSER_WIDTH(C_S_AXI_AWUSER_WIDTH),
		.C_S_AXI_ARUSER_WIDTH(C_S_AXI_ARUSER_WIDTH),
		.C_S_AXI_WUSER_WIDTH(C_S_AXI_WUSER_WIDTH),
		.C_S_AXI_RUSER_WIDTH(C_S_AXI_RUSER_WIDTH),
		.C_S_AXI_BUSER_WIDTH(C_S_AXI_BUSER_WIDTH)
	) mm_to_lite_v1_0_S_AXI_inst (
		.start_write(start_write),
		.s_axi_awaddr_dd(s_axi_awaddr_dd),
		.s_axi_wdata_dd(s_axi_wdata_dd),
		.end_write(end_write),
		.start_read(start_read),
		.s_axi_araddr_dd(s_axi_araddr_dd),
		.m_axi_rdata_dd(m_axi_rdata_dd),
		.end_read(end_read),
		.S_AXI_ACLK(s_axi_aclk),
		.S_AXI_ARESETN(s_axi_aresetn),
		.S_AXI_AWID(s_axi_dd_awid),
		.S_AXI_AWADDR(s_axi_dd_awaddr),
		.S_AXI_AWLEN(s_axi_dd_awlen),
		.S_AXI_AWSIZE(s_axi_dd_awsize),
		.S_AXI_AWBURST(s_axi_dd_awburst),
		.S_AXI_AWLOCK(s_axi_dd_awlock),
		.S_AXI_AWCACHE(s_axi_dd_awcache),
		.S_AXI_AWPROT(s_axi_dd_awprot),
		.S_AXI_AWQOS(s_axi_dd_awqos),
		.S_AXI_AWREGION(s_axi_dd_awregion),
		.S_AXI_AWUSER(s_axi_dd_awuser),
		.S_AXI_AWVALID(s_axi_dd_awvalid),
		.S_AXI_AWREADY(s_axi_dd_awready),
		.S_AXI_WDATA(s_axi_dd_wdata),
		.S_AXI_WSTRB(s_axi_dd_wstrb),
		.S_AXI_WLAST(s_axi_dd_wlast),
		.S_AXI_WUSER(s_axi_dd_wuser),
		.S_AXI_WVALID(s_axi_dd_wvalid),
		.S_AXI_WREADY(s_axi_dd_wready),
		.S_AXI_BID(s_axi_dd_bid),
		.S_AXI_BRESP(s_axi_dd_bresp),
		.S_AXI_BUSER(s_axi_dd_buser),
		.S_AXI_BVALID(s_axi_dd_bvalid),
		.S_AXI_BREADY(s_axi_dd_bready),
		.S_AXI_ARID(s_axi_dd_arid),
		.S_AXI_ARADDR(s_axi_dd_araddr),
		.S_AXI_ARLEN(s_axi_dd_arlen),
		.S_AXI_ARSIZE(s_axi_dd_arsize),
		.S_AXI_ARBURST(s_axi_dd_arburst),
		.S_AXI_ARLOCK(s_axi_dd_arlock),
		.S_AXI_ARCACHE(s_axi_dd_arcache),
		.S_AXI_ARPROT(s_axi_dd_arprot),
		.S_AXI_ARQOS(s_axi_dd_arqos),
		.S_AXI_ARREGION(s_axi_dd_arregion),
		.S_AXI_ARUSER(s_axi_dd_aruser),
		.S_AXI_ARVALID(s_axi_dd_arvalid),
		.S_AXI_ARREADY(s_axi_dd_arready),
		.S_AXI_RID(s_axi_dd_rid),
		.S_AXI_RDATA(s_axi_dd_rdata),
		.S_AXI_RRESP(s_axi_dd_rresp),
		.S_AXI_RLAST(s_axi_dd_rlast),
		.S_AXI_RUSER(s_axi_dd_ruser),
		.S_AXI_RVALID(s_axi_dd_rvalid),
		.S_AXI_RREADY(s_axi_dd_rready)
	);

	// Instantiation of Axi Bus Interface M_AXI_LITE
	mm_to_lite_v1_0_M_AXI_LITE # ( 
		.C_M_TARGET_SLAVE_BASE_ADDR(C_M_AXI_LITE_TARGET_SLAVE_BASE_ADDR),
		.C_M_AXI_ADDR_WIDTH(C_M_AXI_LITE_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M_AXI_LITE_DATA_WIDTH)
	) mm_to_lite_v1_0_M_AXI_LITE_inst (
		.start_write(start_write),
		.s_axi_awaddr_dd(s_axi_awaddr_dd),
		.s_axi_wdata_dd(s_axi_wdata_dd),
		.end_write(end_write),
		.start_read(start_read),
		.s_axi_araddr_dd(s_axi_araddr_dd),
		.m_axi_rdata_dd(m_axi_rdata_dd),
		.end_read(end_read),
		.M_AXI_ACLK(m_axi_lite_aclk),
		.M_AXI_ARESETN(m_axi_lite_aresetn),
		.M_AXI_AWADDR(m_axi_dd_lite_awaddr),
		.M_AXI_AWPROT(m_axi_dd_lite_awprot),
		.M_AXI_AWVALID(m_axi_dd_lite_awvalid),
		.M_AXI_AWREADY(m_axi_dd_lite_awready),
		.M_AXI_WDATA(m_axi_dd_lite_wdata),
		.M_AXI_WSTRB(m_axi_dd_lite_wstrb),
		.M_AXI_WVALID(m_axi_dd_lite_wvalid),
		.M_AXI_WREADY(m_axi_dd_lite_wready),
		.M_AXI_BRESP(m_axi_dd_lite_bresp),
		.M_AXI_BVALID(m_axi_dd_lite_bvalid),
		.M_AXI_BREADY(m_axi_dd_lite_bready),
		.M_AXI_ARADDR(m_axi_dd_lite_araddr),
		.M_AXI_ARPROT(m_axi_dd_lite_arprot),
		.M_AXI_ARVALID(m_axi_dd_lite_arvalid),
		.M_AXI_ARREADY(m_axi_dd_lite_arready),
		.M_AXI_RDATA(m_axi_dd_lite_rdata),
		.M_AXI_RRESP(m_axi_dd_lite_rresp),
		.M_AXI_RVALID(m_axi_dd_lite_rvalid),
		.M_AXI_RREADY(m_axi_dd_lite_rready)
	);

	// Add user logic here

	// C_REG_CONFIG_*:
	//   0 => BYPASS    = The channel is just wired through the module.
	//   1 => FWD_REV   = Both FWD and REV (fully-registered)
	//   2 => FWD       = The master VALID and payload signals are registrated. 
	//   3 => REV       = The slave ready signal is registrated
	//   4 => SLAVE_FWD = All slave side signals and master VALID and payload are registrated.
	//   5 => SLAVE_RDY = All slave side signals and master READY are registrated.
	//   6 => INPUTS    = Slave and Master side inputs are registrated.
	//   7 => LIGHT_WT  = 1-stage pipeline register with bubble cycle, both FWD and REV pipelining

	// choose between register slice or direct ports of axi mm side
    generate
      if(MM_SLICE_ENABLE == 1)
	begin: full_regiser_slice

	// Instantiation of Register Slice for Full AXI4 Slave
	axi_register_slice_v2_1_axi_register_slice # ( 
		.C_FAMILY("virtex"),
		.C_AXI_PROTOCOL(0), //0 == AXI4 - 1 == AXI3 - 2 == AXI4LITE
		.C_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
		.C_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
		.C_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.C_AXI_SUPPORTS_USER_SIGNALS(0),
		.C_AXI_AWUSER_WIDTH(1),
		.C_AXI_ARUSER_WIDTH(1),
		.C_AXI_WUSER_WIDTH(1),
		.C_AXI_RUSER_WIDTH(1),
		.C_AXI_BUSER_WIDTH(1),
		.C_REG_CONFIG_AW(MM_CONFIG_AW),
		.C_REG_CONFIG_W(MM_CONFIG_W),
		.C_REG_CONFIG_B(MM_CONFIG_B),
		.C_REG_CONFIG_AR(MM_CONFIG_AR),
		.C_REG_CONFIG_R(MM_CONFIG_R)
	) axi_register_slice_v2_1_axi_register_slice_full (
		.aclk(s_axi_aclk),
		.aresetn(s_axi_aresetn),

   		// Slave Interface Write Address Ports
		.s_axi_awid(s_axi_awid),
		.s_axi_awaddr(s_axi_awaddr),
		.s_axi_awlen(s_axi_awlen),
		.s_axi_awsize(s_axi_awsize),
		.s_axi_awburst(s_axi_awburst),
		.s_axi_awlock(s_axi_awlock),
		.s_axi_awcache(s_axi_awcache),
		.s_axi_awprot(s_axi_awprot),
		.s_axi_awregion(s_axi_awregion),
		.s_axi_awqos(s_axi_awqos),
		.s_axi_awuser(s_axi_awuser),
		.s_axi_awvalid(s_axi_awvalid),
		.s_axi_awready(s_axi_awready),

		// Slave Interface Write Data Ports
		.s_axi_wid(s_axi_wid),
		.s_axi_wdata(s_axi_wdata),
		.s_axi_wstrb(s_axi_wstrb),
		.s_axi_wlast(s_axi_wlast),
		.s_axi_wuser(s_axi_wuser),
		.s_axi_wvalid(s_axi_wvalid),
		.s_axi_wready(s_axi_wready),

		// Slave Interface Write Response Ports
		.s_axi_bid(s_axi_bid),
		.s_axi_bresp(s_axi_bresp),
		.s_axi_buser(s_axi_buser),
		.s_axi_bvalid(s_axi_bvalid),
		.s_axi_bready(s_axi_bready),

		// Slave Interface Read Address Ports
		.s_axi_arid(s_axi_arid),
		.s_axi_araddr(s_axi_araddr),
		.s_axi_arlen(s_axi_arlen),
		.s_axi_arsize(s_axi_arsize),
		.s_axi_arburst(s_axi_arburst),
		.s_axi_arlock(s_axi_arlock),
		.s_axi_arcache(s_axi_arcache),
		.s_axi_arprot(s_axi_arprot),
		.s_axi_arregion(s_axi_arregion),
		.s_axi_arqos(s_axi_arqos),
		.s_axi_aruser(s_axi_aruser),
		.s_axi_arvalid(s_axi_arvalid),
		.s_axi_arready(s_axi_arready),

		// Slave Interface Read Data Ports
		.s_axi_rid(s_axi_rid),
		.s_axi_rdata(s_axi_rdata),
		.s_axi_rresp(s_axi_rresp),
		.s_axi_rlast(s_axi_rlast),
		.s_axi_ruser(s_axi_ruser),
		.s_axi_rvalid(s_axi_rvalid),
		.s_axi_rready(s_axi_rready),

		// Master Interface Write Address Ports
		.m_axi_awid(s_axi_dd_awid),
		.m_axi_awaddr(s_axi_dd_awaddr),
		.m_axi_awlen(s_axi_dd_awlen),
		.m_axi_awsize(s_axi_dd_awsize),
		.m_axi_awburst(s_axi_dd_awburst),
		.m_axi_awlock(s_axi_dd_awlock),
		.m_axi_awcache(s_axi_dd_awcache),
		.m_axi_awprot(s_axi_dd_awprot),
		.m_axi_awregion(s_axi_dd_awregion),
		.m_axi_awqos(s_axi_dd_awqos),
		.m_axi_awuser(s_axi_dd_awuser),
		.m_axi_awvalid(s_axi_dd_awvalid),
		.m_axi_awready(s_axi_dd_awready),

		// Master Interface Write Data Ports
		.m_axi_wid(s_axi_dd_wid),
		.m_axi_wdata(s_axi_dd_wdata),
		.m_axi_wstrb(s_axi_dd_wstrb),
		.m_axi_wlast(s_axi_dd_wlast),
		.m_axi_wuser(s_axi_dd_wuser),
		.m_axi_wvalid(s_axi_dd_wvalid),
		.m_axi_wready(s_axi_dd_wready),

		// Master Interface Write Response Ports
		.m_axi_bid(s_axi_dd_bid),
		.m_axi_bresp(s_axi_dd_bresp),
		.m_axi_buser(s_axi_dd_buser),
		.m_axi_bvalid(s_axi_dd_bvalid),
		.m_axi_bready(s_axi_dd_bready),

		// Master Interface Read Address Ports
		.m_axi_arid(s_axi_dd_arid),
		.m_axi_araddr(s_axi_dd_araddr),
		.m_axi_arlen(s_axi_dd_arlen),
		.m_axi_arsize(s_axi_dd_arsize),
		.m_axi_arburst(s_axi_dd_arburst),
		.m_axi_arlock(s_axi_dd_arlock),
		.m_axi_arcache(s_axi_dd_arcache),
		.m_axi_arprot(s_axi_dd_arprot),
		.m_axi_arregion(s_axi_dd_arregion),
		.m_axi_arqos(s_axi_dd_arqos),
		.m_axi_aruser(s_axi_dd_aruser),
		.m_axi_arvalid(s_axi_dd_arvalid),
		.m_axi_arready(s_axi_dd_arready),

		// Master Interface Read Data Ports
		.m_axi_rid(s_axi_dd_rid),
		.m_axi_rdata(s_axi_dd_rdata),
		.m_axi_rresp(s_axi_dd_rresp),
		.m_axi_rlast(s_axi_dd_rlast),
		.m_axi_ruser(s_axi_dd_ruser),
		.m_axi_rvalid(s_axi_dd_rvalid),
		.m_axi_rready(s_axi_dd_rready)
	);

	end
      else
	begin: full_direct_declaration

	// assign wires for direct forwarding
	assign s_axi_dd_awid = s_axi_awid;
	assign s_axi_dd_awaddr = s_axi_awaddr;
	assign s_axi_dd_awlen = s_axi_awlen;
	assign s_axi_dd_awsize = s_axi_awsize;
	assign s_axi_dd_awburst = s_axi_awburst;
	assign s_axi_dd_awlock = s_axi_awlock;
	assign s_axi_dd_awcache = s_axi_awcache;
	assign s_axi_dd_awprot = s_axi_awprot;
	assign s_axi_dd_awqos = s_axi_awqos;
	assign s_axi_dd_awregion = s_axi_awregion;
	assign s_axi_dd_awuser = s_axi_awuser;
	assign s_axi_dd_awvalid = s_axi_awvalid;
	assign s_axi_awready = s_axi_dd_awready;
	assign s_axi_dd_wdata = s_axi_wdata;
	assign s_axi_dd_wstrb = s_axi_wstrb;
	assign s_axi_dd_wlast = s_axi_wlast;
	assign s_axi_dd_wuser = s_axi_wuser;
	assign s_axi_dd_wvalid = s_axi_wvalid;
	assign s_axi_wready = s_axi_dd_wready;
	assign s_axi_bid = s_axi_dd_bid;
	assign s_axi_bresp = s_axi_dd_bresp;
	assign s_axi_buser = s_axi_dd_buser;
	assign s_axi_bvalid = s_axi_dd_bvalid;
	assign s_axi_dd_bready = s_axi_bready;
	assign s_axi_dd_arid = s_axi_arid;
	assign s_axi_dd_araddr = s_axi_araddr;
	assign s_axi_dd_arlen = s_axi_arlen;
	assign s_axi_dd_arsize = s_axi_arsize;
	assign s_axi_dd_arburst = s_axi_arburst;
	assign s_axi_dd_arlock = s_axi_arlock;
	assign s_axi_dd_arcache = s_axi_arcache;
	assign s_axi_dd_arprot = s_axi_arprot;
	assign s_axi_dd_arqos = s_axi_arqos;
	assign s_axi_dd_arregion = s_axi_arregion;
	assign s_axi_dd_aruser = s_axi_aruser;
	assign s_axi_dd_arvalid = s_axi_arvalid;
	assign s_axi_arready = s_axi_dd_arready;
	assign s_axi_rid =s_axi_dd_rid ;
	assign s_axi_rdata = s_axi_dd_rdata;
	assign s_axi_rresp = s_axi_dd_rresp;
	assign s_axi_rlast = s_axi_dd_rlast;
	assign s_axi_ruser = s_axi_dd_ruser;
	assign s_axi_rvalid = s_axi_dd_rvalid;
	assign s_axi_dd_rready = s_axi_rready;

	end
    endgenerate

	// choose between register slice or direct ports of axi lite side
    generate
      if(LITE_SLICE_ENABLE == 1)
	begin: lite_regiser_slice
// Instantiation of Register Slice for AXI4 Lite Master
	axi_register_slice_v2_1_axi_register_slice # ( 
		.C_FAMILY("virtex"),
		.C_AXI_PROTOCOL(2), //0 == AXI4 - 1 == AXI3 - 2 == AXI4LITE
		.C_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
		.C_AXI_ADDR_WIDTH(C_M_AXI_LITE_ADDR_WIDTH),
		.C_AXI_DATA_WIDTH(C_M_AXI_LITE_DATA_WIDTH),
		.C_AXI_SUPPORTS_USER_SIGNALS(0),
		.C_AXI_AWUSER_WIDTH(1),
		.C_AXI_ARUSER_WIDTH(1),
		.C_AXI_WUSER_WIDTH(1),
		.C_AXI_RUSER_WIDTH(1),
		.C_AXI_BUSER_WIDTH(1),
		.C_REG_CONFIG_AW(LITE_CONFIG_AW),
		.C_REG_CONFIG_W(LITE_CONFIG_W),
		.C_REG_CONFIG_B(LITE_CONFIG_B),
		.C_REG_CONFIG_AR(LITE_CONFIG_AR),
		.C_REG_CONFIG_R(LITE_CONFIG_R)
	) axi_register_slice_v2_1_axi_register_slice_lite (
		.aclk(m_axi_lite_aclk),
		.aresetn(m_axi_lite_aresetn),

   		// Slave Interface Write Address Ports
		.s_axi_awid(m_axi_dd_lite_awaddr),
		.s_axi_awprot(m_axi_dd_lite_awprot),
		.s_axi_awvalid(m_axi_dd_lite_awvalid),
		.s_axi_awready(m_axi_dd_lite_awready),

		// Slave Interface Write Data Ports
		.s_axi_wdata(m_axi_dd_lite_wdata),
		.s_axi_wstrb(m_axi_dd_lite_wstrb),
		.s_axi_wvalid(m_axi_dd_lite_wvalid),
		.s_axi_wready(m_axi_dd_lite_wready),

		// Slave Interface Write Response Ports
		.s_axi_bresp(m_axi_dd_lite_bresp),
		.s_axi_bvalid(m_axi_dd_lite_bvalid),
		.s_axi_bready(m_axi_dd_lite_bready),

		// Slave Interface Read Address Ports
		.s_axi_araddr(m_axi_dd_lite_araddr),
		.s_axi_arprot(m_axi_dd_lite_arprot),
		.s_axi_arvalid(m_axi_dd_lite_arvalid),
		.s_axi_arready(m_axi_dd_lite_arready),

		// Slave Interface Read Data Ports
		.s_axi_rdata(m_axi_dd_lite_rdata),
		.s_axi_rresp(m_axi_dd_lite_rresp),
		.s_axi_rvalid(m_axi_dd_lite_rvalid),
		.s_axi_rready(m_axi_dd_lite_rready),

   		// Master Interface Write Address Ports
		.m_axi_awid(m_axi_lite_awaddr),
		.m_axi_awprot(m_axi_lite_awprot),
		.m_axi_awvalid(m_axi_lite_awvalid),
		.m_axi_awready(m_axi_lite_awready),

		// Master Interface Write Data Ports
		.m_axi_wdata(m_axi_lite_wdata),
		.m_axi_wstrb(m_axi_lite_wstrb),
		.m_axi_wvalid(m_axi_lite_wvalid),
		.m_axi_wready(m_axi_lite_wready),

		// Master Interface Write Response Ports
		.m_axi_bresp(m_axi_lite_bresp),
		.m_axi_bvalid(m_axi_lite_bvalid),
		.m_axi_bready(m_axi_lite_bready),

		// Master Interface Read Address Ports
		.m_axi_araddr(m_axi_lite_araddr),
		.m_axi_arprot(m_axi_lite_arprot),
		.m_axi_arvalid(m_axi_lite_arvalid),
		.m_axi_arready(m_axi_lite_arready),

		// Master Interface Read Data Ports
		.m_axi_rdata(m_axi_lite_rdata),
		.m_axi_rresp(m_axi_lite_rresp),
		.m_axi_rvalid(m_axi_lite_rvalid),
		.m_axi_rready(m_axi_lite_rready)
	);

	end
      else
	begin: lite_direct_declaration

	// assign wires for direct forwarding
	assign m_axi_lite_awaddr = m_axi_dd_lite_awaddr;
	assign m_axi_lite_awprot = m_axi_dd_lite_awprot;
	assign m_axi_lite_awvalid = m_axi_dd_lite_awvalid;
	assign m_axi_dd_lite_awready = m_axi_lite_awready;
	assign m_axi_lite_wdata = m_axi_dd_lite_wdata;
	assign m_axi_lite_wstrb = m_axi_dd_lite_wstrb;
	assign m_axi_lite_wvalid = m_axi_dd_lite_wvalid;
	assign m_axi_dd_lite_wready = m_axi_lite_wready;
	assign m_axi_dd_lite_bresp = m_axi_lite_bresp;
	assign m_axi_dd_lite_bvalid = m_axi_lite_bvalid;
	assign m_axi_lite_bready = m_axi_dd_lite_bready;
	assign m_axi_lite_araddr = m_axi_dd_lite_araddr;
	assign m_axi_lite_arprot = m_axi_dd_lite_arprot;
	assign m_axi_lite_arvalid = m_axi_dd_lite_arvalid;
	assign m_axi_dd_lite_arready = m_axi_lite_arready;
	assign m_axi_dd_lite_rdata = m_axi_lite_rdata;
	assign m_axi_dd_lite_rresp = m_axi_lite_rresp;
	assign m_axi_dd_lite_rvalid = m_axi_lite_rvalid;
	assign m_axi_lite_rready = m_axi_dd_lite_rready;

	end
    endgenerate

	// User logic ends

	endmodule
