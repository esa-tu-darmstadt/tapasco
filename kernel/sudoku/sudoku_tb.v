//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
module sudoku_tb;

parameter    C_M_AXI_ARR_ID_WIDTH = 1;
parameter    C_M_AXI_ARR_ADDR_WIDTH = 32;
parameter    C_M_AXI_ARR_DATA_WIDTH = 32;
parameter    ap_const_int64_8 = 8;
parameter    C_M_AXI_ARR_AWUSER_WIDTH = 1;
parameter    C_M_AXI_ARR_ARUSER_WIDTH = 1;
parameter    C_M_AXI_ARR_WUSER_WIDTH = 1;
parameter    C_M_AXI_ARR_RUSER_WIDTH = 1;
parameter    C_M_AXI_ARR_BUSER_WIDTH = 1;
parameter    C_DATA_WIDTH = 32;
parameter    C_M_AXI_ARR_TARGET_ADDR = 0;
parameter    C_M_AXI_ARR_USER_VALUE = 0;
parameter    C_M_AXI_ARR_PROT_VALUE = 0;
parameter    C_M_AXI_ARR_CACHE_VALUE = 3;
parameter    C_M_AXI_ARR_WSTRB_WIDTH = (C_M_AXI_ARR_DATA_WIDTH / ap_const_int64_8);
parameter    C_WSTRB_WIDTH = (C_DATA_WIDTH / ap_const_int64_8);
parameter    C_M_AXI_BASE_ADDRESS = 32'h44A00000;

reg clk;
reg rst;

initial begin
	clk = 1;
	rst = 1;
	#100;
	rst = 0;
end

always #4 clk = ~clk;

integer cycle_count = 0;
always @(posedge clk) cycle_count = cycle_count + 1;

reg ap_start;
wire ap_done;
wire ap_idle;
wire ap_ready;

reg  s_axi_aclk;
reg  s_axi_aresetn;
reg [31:0] s_axi_awaddr;
reg [2:0] s_axi_awprot;
reg  s_axi_awvalid;
wire s_axi_awready;
reg [31:0] s_axi_wdata;
reg [3:0] s_axi_wstrb;
reg  s_axi_wvalid;
wire s_axi_wready;
wire[1:0] s_axi_bresp;
wire s_axi_bvalid;
reg  s_axi_bready;
reg [31:0] s_axi_araddr;
reg [2:0] s_axi_arprot;
reg  s_axi_arvalid;
wire s_axi_arready;
wire[31:0] s_axi_rdata;
wire[1:0] s_axi_rresp;
wire s_axi_rvalid;
reg  s_axi_rready;

wire   m_axi_grid_awvalid;
reg   m_axi_grid_awready;
wire  [C_M_AXI_ARR_ADDR_WIDTH - 1 : 0] m_axi_grid_awaddr;
wire  [C_M_AXI_ARR_ID_WIDTH - 1 : 0] m_axi_grid_awid;
wire  [7:0] m_axi_grid_awlen;
wire  [2:0] m_axi_grid_awsize;
wire  [1:0] m_axi_grid_awburst;
wire  [1:0] m_axi_grid_awlock;
wire  [3:0] m_axi_grid_awcache;
wire  [2:0] m_axi_grid_awprot;
wire  [3:0] m_axi_grid_awqos;
wire  [3:0] m_axi_grid_awregion;
wire  [C_M_AXI_ARR_AWUSER_WIDTH - 1 : 0] m_axi_grid_awuser;
wire   m_axi_grid_wvalid;
reg   m_axi_grid_wready;
wire  [C_M_AXI_ARR_DATA_WIDTH - 1 : 0] m_axi_grid_wdata;
wire  [C_M_AXI_ARR_WSTRB_WIDTH - 1 : 0] m_axi_grid_wstrb;
wire   m_axi_grid_wlast;
wire  [C_M_AXI_ARR_ID_WIDTH - 1 : 0] m_axi_grid_wid;
wire  [C_M_AXI_ARR_WUSER_WIDTH - 1 : 0] m_axi_grid_wuser;
wire   m_axi_grid_arvalid;
reg   m_axi_grid_arready;
wire  [C_M_AXI_ARR_ADDR_WIDTH - 1 : 0] m_axi_grid_araddr;
wire  [C_M_AXI_ARR_ID_WIDTH - 1 : 0] m_axi_grid_arid;
wire  [7:0] m_axi_grid_arlen;
wire  [2:0] m_axi_grid_arsize;
wire  [1:0] m_axi_grid_arburst;
wire  [1:0] m_axi_grid_arlock;
wire  [3:0] m_axi_grid_arcache;
wire  [2:0] m_axi_grid_arprot;
wire  [3:0] m_axi_grid_arqos;
wire  [3:0] m_axi_grid_arregion;
wire  [C_M_AXI_ARR_ARUSER_WIDTH - 1 : 0] m_axi_grid_aruser;
reg   m_axi_grid_rvalid;
wire   m_axi_grid_rready;
reg  [C_M_AXI_ARR_DATA_WIDTH - 1 : 0] m_axi_grid_rdata;
reg   m_axi_grid_rlast;
reg  [C_M_AXI_ARR_ID_WIDTH - 1 : 0] m_axi_grid_rid;
reg  [C_M_AXI_ARR_RUSER_WIDTH - 1 : 0] m_axi_grid_ruser;
reg  [1:0] m_axi_grid_rresp;
reg   m_axi_grid_bvalid;
wire   m_axi_grid_bready;
reg  [1:0] m_axi_grid_bresp;
reg  [C_M_AXI_ARR_ID_WIDTH - 1 : 0] m_axi_grid_bid;
reg  [C_M_AXI_ARR_BUSER_WIDTH - 1 : 0] m_axi_grid_buser;
wire  ap_return;
reg [31:0] baseaddr;

Sudoku dut (
	.clk ( clk ),
	.reset ( rst ),
	.ap_clk( clk ),
	.ap_rst( rst ),

	.s_axi_aclk( clk ),
	.s_axi_aresetn( ~rst ),
	.s_axi_awaddr( s_axi_awaddr ),
	.s_axi_awprot( s_axi_awprot ),
	.s_axi_awvalid( s_axi_awvalid ),
	.s_axi_awready( s_axi_awready ),
	.s_axi_wdata( s_axi_wdata ),
	.s_axi_wstrb( s_axi_wstrb ),
	.s_axi_wvalid( s_axi_wvalid ),
	.s_axi_wready( s_axi_wready ),
	.s_axi_bresp( s_axi_bresp ),
	.s_axi_bvalid( s_axi_bvalid ),
	.s_axi_bready( s_axi_bready ),
	.s_axi_araddr( s_axi_araddr ),
	.s_axi_arprot( s_axi_arprot ),
	.s_axi_arvalid( s_axi_arvalid ),
	.s_axi_arready( s_axi_arready ),
	.s_axi_rdata( s_axi_rdata ),
	.s_axi_rresp( s_axi_rresp ),
	.s_axi_rvalid( s_axi_rvalid ),
	.s_axi_rready( s_axi_rready ),

	.m_axi_grid_aclk( clk ),
	.m_axi_grid_aresetn( ~rst ),

	.m_axi_grid_awvalid( m_axi_grid_awvalid ),
	.m_axi_grid_awready( m_axi_grid_awready ),
	.m_axi_grid_awaddr( m_axi_grid_awaddr ),
	.m_axi_grid_awprot( m_axi_grid_awprot ),
	.m_axi_grid_wvalid( m_axi_grid_wvalid ),
	.m_axi_grid_wready( m_axi_grid_wready ),
	.m_axi_grid_wdata( m_axi_grid_wdata ),
	.m_axi_grid_wstrb( m_axi_grid_wstrb ),
	.m_axi_grid_arvalid( m_axi_grid_arvalid ),
	.m_axi_grid_arready( m_axi_grid_arready ),
	.m_axi_grid_araddr( m_axi_grid_araddr ),
	.m_axi_grid_arprot( m_axi_grid_arprot ),
	.m_axi_grid_rvalid( m_axi_grid_rvalid ),
	.m_axi_grid_rready( m_axi_grid_rready ),
	.m_axi_grid_rdata( m_axi_grid_rdata ),
	.m_axi_grid_rresp( m_axi_grid_rresp ),
	.m_axi_grid_bvalid( m_axi_grid_bvalid ),
	.m_axi_grid_bready( m_axi_grid_bready ),
	.m_axi_grid_bresp( m_axi_grid_bresp ),
        .ap_return( ap_return ),
	.ap_done( ap_done ),
	.m_axi_grid_baseaddress( baseaddr )
);

initial begin
	m_axi_grid_arready = 0;
	m_axi_grid_awready = 0;
	m_axi_grid_wready  = 0;
	m_axi_grid_rvalid  = 0;
	m_axi_grid_rlast   = 0;
	m_axi_grid_bvalid  = 0;
	baseaddr           = C_M_AXI_BASE_ADDRESS;
	@(negedge rst)
	m_axi_grid_arready = 1;
	m_axi_grid_awready = 0;
	m_axi_grid_wready  = 0;
	m_axi_grid_rvalid  = 0;
	m_axi_grid_rlast   = 1;

	s_axi_awprot = 0;
	s_axi_awvalid = 0;
	s_axi_bready = 1;
	s_axi_rready = 0;
	
	@(posedge clk)
	s_axi_awaddr = 32'h4;
	s_axi_awvalid = 1'b1;
	s_axi_wdata = C_M_AXI_BASE_ADDRESS; //32'h44A00000;
	s_axi_wvalid = 1'b1;

	@(posedge s_axi_awready);
	@(posedge s_axi_wready);
	s_axi_awvalid = 1'b0;
	s_axi_wvalid = 1'b0;


	@(posedge clk)
	s_axi_awaddr = 1'h0;
	s_axi_awvalid = 1'b1;
	s_axi_wdata = 1'h1;
	s_axi_wvalid = 1'b1;
	@(posedge s_axi_awready);
	@(posedge s_axi_wready);
	s_axi_awvalid = 1'b0;
	s_axi_wvalid = 1'b0;
end

always @(posedge ap_done) begin
	if (! rst) begin
		$display("SIMULATION FINISHED: ap_return = %d\n", ap_return);
		PRINT_GRID();
		$finish;
	end
end

always @(posedge clk) begin
	if (m_axi_grid_rready && m_axi_grid_rvalid) begin
		m_axi_grid_rvalid <= 0;
		m_axi_grid_rlast <= 0;
	end
end

reg [31:0] grid [80:0];
integer i = 0;
initial begin
	for (i = 0; i < 81; i = i + 1) begin
		grid[i] = 0;
	end
	grid[0] = 7;
end

// READ process
always @(posedge clk) begin
	if (m_axi_grid_arvalid && m_axi_grid_arready) begin
		m_axi_grid_rdata   <= grid[(m_axi_grid_araddr - baseaddr) >> 2];
		m_axi_grid_rresp   <= 0; // 'OKAY'
		m_axi_grid_rvalid  <= 1;
		m_axi_grid_rlast   <= 1;
		m_axi_grid_arready <= 0;
	end
	if (m_axi_grid_arvalid && !m_axi_grid_rready) begin
		#125 m_axi_grid_arready <= 1;
	end
end

// WRITE process
reg [31:0] waddr;
always @(posedge clk) begin
	if (m_axi_grid_awvalid && m_axi_grid_awready && m_axi_grid_wvalid && m_axi_grid_wready) begin
		grid[(m_axi_grid_awaddr - baseaddr) >> 2] <= m_axi_grid_wdata;
		m_axi_grid_awready <= 0;
		m_axi_grid_wready <= 0;
		m_axi_grid_bresp  <= 0;
		m_axi_grid_bvalid <= 1;
	end else begin
		if (m_axi_grid_awvalid && m_axi_grid_awready) begin
			waddr <= m_axi_grid_awaddr;
			m_axi_grid_awready <= 0;
		end
		if (m_axi_grid_wvalid && m_axi_grid_wready) begin
			grid[(waddr - baseaddr) >> 2] <= m_axi_grid_wdata;
			m_axi_grid_wready <= 0;
			m_axi_grid_bresp  <= 0;
			m_axi_grid_bvalid <= 1;
		end
		if (m_axi_grid_awvalid && m_axi_grid_wvalid) begin
			//#500;
			m_axi_grid_awready <= 1;
			m_axi_grid_wready <= 1;
		end
	end
	if (m_axi_grid_bvalid && m_axi_grid_bready) begin
		m_axi_grid_bvalid <= 0;
	end
end

task PRINT_GRID; 
reg [7:0] i;
begin
	for (i = 0; i < 9; i = i + 1) begin
		$display("%1d%1d%1d|%1d%1d%1d|%1d%1d%1d", grid[(i * 9) + 0], 
			grid[(i * 9) + 1], grid[(i * 9) + 2], grid[(i * 9) + 3], 
			grid[(i * 9) + 4], grid[(i * 9)  + 5], grid[(i * 9) + 6], 
			grid[(i * 9) + 7], grid[(i * 9) + 8]);
		if (i == 2 || i == 5) $display("---+---+---");
	end
end
endtask

////////////////////////////////////////////////////////////////////////////////
// DEBUG ap_bus
/*integer req_cnt = 0;
always @(posedge clk) begin
	// note all read request with address
	if (dut.dut_grid_req_write && !dut.dut_grid_req_din) begin
		$display("req #%3d: ap_bus reading grid[%2d] ~ address: 0x%x, value right now: %1d", 
				req_cnt,
				dut.dut_grid_address, 
				(dut.dut_grid_address << 2) + baseaddr,
				grid[dut.dut_grid_address]);
		req_cnt = req_cnt + 1;
	end

	if (dut.dut_grid_rsp_read && dut.bm_grid_rsp_empty_n) begin
		$display("ap_bus reading data: 0x%x (probably for grid[%2d])", 
				dut.bm_grid_datain,
				(dut.bm_m_axi_grid_m_axi_araddr - baseaddr) >> 2);
	end

end

always @(posedge dut.dut_grid_req_write) begin
	if (!rst) begin
	if (dut.dut_grid_req_din) begin
		$display("%d: ap_bus write request: 0x%x, %d\n", cycle_count, dut.dut_grid_address, dut.dut_grid_dataout);
	end else begin
		$display("%d: ap_bus read request: 0x%x\n", cycle_count, dut.dut_grid_address);
	end
	end
end

always @(posedge dut.dut_grid_rsp_read) begin
	if (!rst) begin
		$display("%d: ap_bus read data: 0x%x\n", cycle_count, dut.bm_grid_datain);
	end
end

always @(posedge dut.bm_grid_req_full_n) begin
	if (!rst) begin
		$display("%d: write finished\n", cycle_count);
	end
end

////////////////////////////////////////////////////////////////////////////////
// DEBUG M-AXI
always @(posedge dut.bm_m_axi_grid_m_axi_awvalid) begin
	if (!rst) begin
	$display("%d: valid write address on M-AXI: 0x%x\n", cycle_count, dut.bm_m_axi_grid_m_axi_awaddr);
	end
end

always @(posedge dut.bm_m_axi_grid_m_axi_wvalid) begin
	if (!rst) begin
	$display("%d: valid write data on M-AXI: 0x%x\n", cycle_count, dut.bm_m_axi_grid_m_axi_wdata);
	end
end

always @(dut.bm_m_axi_grid_m_axi_awvalid && dut.m_axi_grid_AWREADY) begin
	if (!rst) begin
	$display("%d: write address handshake on M-AXI: 0x%x -> %d\n", cycle_count, dut.bm_m_axi_grid_m_axi_awaddr, dut.bm_m_axi_grid_m_axi_wdata);
	end
end

always @(dut.bm_m_axi_grid_m_axi_wvalid && dut.m_axi_grid_WREADY) begin
	if (!rst) begin
	$display("%d: write data handshake on M-AXI: %d\n", cycle_count, dut.bm_m_axi_grid_m_axi_wdata);
	end
end

always @(posedge dut.bm_m_axi_grid_m_axi_arvalid) begin
	if (!rst) begin
	$display("%d: valid read address on M-AXI: 0x%x\n", cycle_count, dut.bm_m_axi_grid_m_axi_awaddr);
	end
end

always @(dut.bm_m_axi_grid_m_axi_arvalid && dut.m_axi_grid_ARREADY) begin
	if (!rst) begin
	$display("%d: read address handshake on M-AXI: 0x%x\n", cycle_count, dut.bm_m_axi_grid_m_axi_araddr);
	end
end

always @(dut.m_axi_grid_RVALID && dut.bm_m_axi_grid_m_axi_rready) begin
	if (!rst) begin
	$display("%d: read data handshake on M-AXI: 0x%x\n", cycle_count, dut.m_axi_grid_RDATA);
	end
end*/

endmodule
