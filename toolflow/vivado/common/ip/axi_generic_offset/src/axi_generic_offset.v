/*
 * AXI offset. Set highest address bit to zero.
 *
 * Author: Carsten Heinz <heinz@esa.tu-darmstadt.de>
 * Copyright (c) 2018 Embedded Systems and Applications Group, TU Darmstadt
 */

`default_nettype none

module axi_generic_offset #(
    parameter BYTES_PER_WORD = 16,
    parameter ADDRESS_WIDTH = 32,
    parameter ID_WIDTH = 6,
    parameter OVERWRITE_BITS = 1,
    parameter HIGHEST_ADDR_BIT = 0
) (
    input wire aclk,
    input wire aresetn,

    input  wire [ADDRESS_WIDTH-1:0]     S_AXI_araddr,
    input  wire [7:0]                   S_AXI_arlen,
    input  wire [2:0]                   S_AXI_arprot,
    input  wire [2:0]                   S_AXI_arsize,
    input  wire [1:0]                   S_AXI_arburst,
    input  wire                         S_AXI_arlock,
    input  wire [3:0]                   S_AXI_arcache,
    input  wire [3:0]                   S_AXI_arqos,
    input  wire [3:0]                   S_AXI_arregion,
    input  wire                         S_AXI_aruser,
    input  wire [ID_WIDTH-1:0]          S_AXI_arid,
    output wire                         S_AXI_arready,
    input  wire                         S_AXI_arvalid,
    input  wire [ADDRESS_WIDTH-1:0]     S_AXI_awaddr,
    input  wire [7:0]                   S_AXI_awlen,
    input  wire [2:0]                   S_AXI_awprot,
    input  wire [2:0]                   S_AXI_awsize,
    input  wire [1:0]                   S_AXI_awburst,
    input  wire                         S_AXI_awlock,
    input  wire [3:0]                   S_AXI_awcache,
    input  wire [3:0]                   S_AXI_awqos,
    input  wire [3:0]                   S_AXI_awregion,
    input  wire                         S_AXI_awuser,
    input  wire [ID_WIDTH-1:0]          S_AXI_awid,
    output wire                         S_AXI_awready,
    input  wire                         S_AXI_awvalid,
    input  wire                         S_AXI_bready,
    output wire                         S_AXI_bvalid,
    output wire [ID_WIDTH-1:0]          S_AXI_bid,
    output wire [1:0]                   S_AXI_bresp,
    output wire                         S_AXI_buser,
    output wire [BYTES_PER_WORD*8-1:0]  S_AXI_rdata,
    output wire                         S_AXI_rlast,
    input  wire                         S_AXI_rready,
    output wire                         S_AXI_rvalid,
    output wire [ID_WIDTH-1:0]          S_AXI_rid,
    output wire [1:0]                   S_AXI_rresp,
    output wire                         S_AXI_ruser,
    input  wire [BYTES_PER_WORD*8-1:0]  S_AXI_wdata,
    input  wire [BYTES_PER_WORD-1:0]    S_AXI_wstrb,
    input  wire                         S_AXI_wlast,
    output wire                         S_AXI_wready,
    input  wire                         S_AXI_wvalid,

    output wire [ADDRESS_WIDTH-1:0]     M_AXI_araddr,
    output wire [7:0]                   M_AXI_arlen,
    output wire [2:0]                   M_AXI_arprot,
    output wire [2:0]                   M_AXI_arsize,
    output wire [1:0]                   M_AXI_arburst,
    output wire                         M_AXI_arlock,
    output wire [3:0]                   M_AXI_arcache,
    output wire [3:0]                   M_AXI_arqos,
    output wire [3:0]                   M_AXI_arregion,
    output wire                         M_AXI_aruser,
    output wire [ID_WIDTH-1:0]          M_AXI_arid,
    input  wire                         M_AXI_arready,
    output wire                         M_AXI_arvalid,
    output wire [ADDRESS_WIDTH-1:0]     M_AXI_awaddr,
    output wire [7:0]                   M_AXI_awlen,
    output wire [2:0]                   M_AXI_awprot,
    output wire [2:0]                   M_AXI_awsize,
    output wire [1:0]                   M_AXI_awburst,
    output wire                         M_AXI_awlock,
    output wire [3:0]                   M_AXI_awcache,
    output wire [3:0]                   M_AXI_awqos,
    output wire [3:0]                   M_AXI_awregion,
    output wire                         M_AXI_awuser,
    output wire [ID_WIDTH-1:0]          M_AXI_awid,
    input  wire                         M_AXI_awready,
    output wire                         M_AXI_awvalid,
    output wire                         M_AXI_bready,
    input  wire                         M_AXI_bvalid,
    input  wire [ID_WIDTH-1:0]          M_AXI_bid,
    input  wire [1:0]                   M_AXI_bresp,
    input  wire                         M_AXI_buser,
    input  wire [BYTES_PER_WORD*8-1:0]  M_AXI_rdata,
    input  wire                         M_AXI_rlast,
    output wire                         M_AXI_rready,
    input  wire                         M_AXI_rvalid,
    input  wire [ID_WIDTH-1:0]          M_AXI_rid,
    input  wire [1:0]                   M_AXI_rresp,
    input  wire                         M_AXI_ruser,
    output wire [BYTES_PER_WORD*8-1:0]  M_AXI_wdata,
    output wire [BYTES_PER_WORD-1:0]    M_AXI_wstrb,
    output wire                         M_AXI_wlast,
    input  wire                         M_AXI_wready,
    output wire                         M_AXI_wvalid
);

assign M_AXI_araddr = {HIGHEST_ADDR_BIT[OVERWRITE_BITS-1:0],S_AXI_araddr[ADDRESS_WIDTH-OVERWRITE_BITS-1:0]};
assign M_AXI_arlen = S_AXI_arlen;

// overwrite arprot with "Secure Data Unpriviledged" to prevent DECERR returned by memory controller of the PYNQ 
assign M_AXI_arprot = 3'b000;
assign M_AXI_arsize = S_AXI_arsize;
assign M_AXI_arburst = S_AXI_arburst;
assign M_AXI_arlock = S_AXI_arlock;
assign M_AXI_arcache = S_AXI_arcache;
assign M_AXI_arqos = S_AXI_arqos;
assign M_AXI_arregion = S_AXI_arregion;
assign M_AXI_aruser = S_AXI_aruser;
assign M_AXI_arid = S_AXI_arid;
assign M_AXI_arvalid = S_AXI_arvalid;

assign M_AXI_awaddr = {HIGHEST_ADDR_BIT[OVERWRITE_BITS-1:0],S_AXI_awaddr[ADDRESS_WIDTH-OVERWRITE_BITS-1:0]};
assign M_AXI_awlen = S_AXI_awlen;

// overwrite awprot with "Secure Data Unpriviledged" to prevent DECERR returned by memory controller of the PYNQ 
assign M_AXI_awprot = 3'b000;
assign M_AXI_awsize = S_AXI_awsize;
assign M_AXI_awburst = S_AXI_awburst;
assign M_AXI_awlock = S_AXI_awlock;
assign M_AXI_awcache = S_AXI_awcache;
assign M_AXI_awqos = S_AXI_awqos;
assign M_AXI_awregion = S_AXI_awregion;
assign M_AXI_awuser = S_AXI_awuser;
assign M_AXI_awid = S_AXI_awid;
assign M_AXI_awvalid = S_AXI_awvalid;

assign M_AXI_bready = S_AXI_bready;
assign S_AXI_bid = M_AXI_bid;
assign S_AXI_bresp = M_AXI_bresp;
assign S_AXI_buser = M_AXI_buser;

assign M_AXI_rready = S_AXI_rready;
assign M_AXI_wdata = S_AXI_wdata;
assign M_AXI_wstrb = S_AXI_wstrb;
assign M_AXI_wlast = S_AXI_wlast;
assign M_AXI_wvalid = S_AXI_wvalid;

assign S_AXI_arready = M_AXI_arready;
assign S_AXI_awready = M_AXI_awready;
assign S_AXI_bvalid = M_AXI_bvalid;
assign S_AXI_rdata = M_AXI_rdata;
assign S_AXI_rlast = M_AXI_rlast;
assign S_AXI_rvalid = M_AXI_rvalid;
assign S_AXI_rid = M_AXI_rid;
assign S_AXI_rresp = M_AXI_rresp;
assign S_AXI_ruser = M_AXI_ruser;
assign S_AXI_wready = M_AXI_wready;

endmodule

`default_nettype wire
