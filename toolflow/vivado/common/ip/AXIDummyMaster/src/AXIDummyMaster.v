module AXIDummyMaster(M_AXI_aclk,
		M_AXI_aresetn,
		M_AXI_arvalid,
		M_AXI_arready,
		M_AXI_araddr,
		M_AXI_arprot,
		M_AXI_rready,
		M_AXI_rvalid,
		M_AXI_rdata,
		M_AXI_rresp,
		M_AXI_awready,
		M_AXI_awvalid,
		M_AXI_awaddr,
		M_AXI_awprot,
		M_AXI_wready,
		M_AXI_wvalid,
		M_AXI_wdata,
		M_AXI_wstrb,
		M_AXI_bvalid,
		M_AXI_bready,
		M_AXI_bresp);

	input M_AXI_aclk;
	input M_AXI_aresetn;

	output M_AXI_arvalid;
	input  M_AXI_arready;
	output [11:0] M_AXI_araddr;
	output [2:0] M_AXI_arprot;

	output M_AXI_rready;
	input  M_AXI_rvalid;
	input  [31:0] M_AXI_rdata;
	input  [1:0] M_AXI_rresp;

	input  M_AXI_awready;
	output M_AXI_awvalid;
	output [11:0] M_AXI_awaddr;
	output [2:0] M_AXI_awprot;

	input  M_AXI_wready;
	output M_AXI_wvalid;
	output [31:0] M_AXI_wdata;
	output [3:0] M_AXI_wstrb;

	input  M_AXI_bvalid;
	output M_AXI_bready;
	input  [1:0] M_AXI_bresp;

	assign M_AXI_arvalid = 0;
	assign M_AXI_araddr = 0;
	assign M_AXI_arprot = 0;

	assign M_AXI_rready = 1;

	assign M_AXI_awvalid = 0;
	assign M_AXI_awaddr = 0;
	assign M_AXI_awprot = 0;

	assign M_AXI_wvalid = 0;
	assign M_AXI_wdata = 0;
	assign M_AXI_wstrb = 0;

	assign M_AXI_bready = 1;
endmodule

