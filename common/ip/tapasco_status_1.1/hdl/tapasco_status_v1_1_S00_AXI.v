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
`timescale 1 ns / 1 ps

	module tapasco_status_v1_1_S00_AXI #
	(
    parameter integer C_VIVADO_VERSION   = 32'd00,
    parameter integer C_TAPASCO_VERSION  = 32'd00,
    parameter integer C_GEN_TS           = 32'd00,
    parameter integer C_HOST_CLK_MHZ     = 32'd00,
    parameter integer C_MEM_CLK_MHZ      = 32'd00,
    parameter integer C_DESIGN_CLK_MHZ   = 32'd00,
    parameter integer C_INTC_COUNT       = 32'd01,
    parameter integer C_CAPABILITIES_0   = 32'd00,
    parameter integer C_SLOT_KERNEL_ID_1 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_2 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_3 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_4 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_5 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_6 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_7 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_8 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_9 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_10 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_11 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_12 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_13 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_14 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_15 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_16 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_17 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_18 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_19 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_20 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_21 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_22 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_23 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_24 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_25 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_26 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_27 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_28 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_29 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_30 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_31 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_32 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_33 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_34 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_35 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_36 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_37 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_38 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_39 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_40 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_41 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_42 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_43 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_44 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_45 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_46 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_47 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_48 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_49 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_50 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_51 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_52 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_53 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_54 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_55 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_56 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_57 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_58 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_59 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_60 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_61 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_62 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_63 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_64 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_65 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_66 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_67 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_68 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_69 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_70 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_71 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_72 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_73 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_74 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_75 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_76 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_77 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_78 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_79 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_80 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_81 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_82 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_83 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_84 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_85 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_86 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_87 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_88 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_89 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_90 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_91 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_92 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_93 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_94 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_95 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_96 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_97 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_98 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_99 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_100 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_101 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_102 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_103 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_104 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_105 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_106 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_107 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_108 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_109 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_110 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_111 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_112 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_113 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_114 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_115 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_116 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_117 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_118 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_119 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_120 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_121 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_122 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_123 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_124 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_125 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_126 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_127 = 32'b00,
    parameter integer C_SLOT_KERNEL_ID_128 = 32'b00,
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 12
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave)
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	    end
	  else
	    begin
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // slave is ready to accept write address when
	          // there is a valid write address and write data
	          // on the write address and data bus. This design
	          // expects no outstanding transactions.
	          axi_awready <= 1'b1;
	        end
	      else
	        begin
	          axi_awready <= 1'b0;
	        end
	    end
	end

	// Implement axi_awaddr latching
	// This process is used to latch the address when both
	// S_AXI_AWVALID and S_AXI_WVALID are valid.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end
	  else
	    begin
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // Write Address latching
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end
	end

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end
	  else
	    begin
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
	        begin
	          // slave is ready to accept write data when
	          // there is a valid write address and write data
	          // on the write address and data bus. This design
	          // expects no outstanding transactions.
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end
	end

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.
	// This marks the acceptance of address and indicates the status of
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end
	  else
	    begin
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b10; // 'SLVERR' response - no writing!
	        end
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid)
	            //check if bready is asserted while bvalid is high)
	            //(there is a possibility that bready is always asserted high)
	            begin
	              axi_bvalid <= 1'b0;
	            end
	        end
	    end
	end

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is
	// de-asserted when reset (active low) is asserted.
	// The read address is also latched when S_AXI_ARVALID is
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end
	  else
	    begin
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end
	end

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers
	// data are available on the axi_rdata bus at this instance. The
	// assertion of axi_rvalid marks the validity of read data on the
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid
	// is deasserted on reset (active low). axi_rresp and axi_rdata are
	// cleared to zero on reset (active low).
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end
	  else
	    begin
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end
	    end
	end

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr )
          12'h000: reg_data_out <= 32'hE5AE1337;
          12'h004: reg_data_out <= C_INTC_COUNT;
          12'h008: reg_data_out <= C_CAPABILITIES_0;
	  12'h010: reg_data_out <= C_VIVADO_VERSION;
	  12'h014: reg_data_out <= C_TAPASCO_VERSION;
	  12'h018: reg_data_out <= C_GEN_TS;
	  12'h01c: reg_data_out <= C_HOST_CLK_MHZ;
	  12'h020: reg_data_out <= C_MEM_CLK_MHZ;
	  12'h024: reg_data_out <= C_DESIGN_CLK_MHZ;
          12'd256: reg_data_out <= C_SLOT_KERNEL_ID_1;
          12'd272: reg_data_out <= C_SLOT_KERNEL_ID_2;
          12'd288: reg_data_out <= C_SLOT_KERNEL_ID_3;
          12'd304: reg_data_out <= C_SLOT_KERNEL_ID_4;
          12'd320: reg_data_out <= C_SLOT_KERNEL_ID_5;
          12'd336: reg_data_out <= C_SLOT_KERNEL_ID_6;
          12'd352: reg_data_out <= C_SLOT_KERNEL_ID_7;
          12'd368: reg_data_out <= C_SLOT_KERNEL_ID_8;
          12'd384: reg_data_out <= C_SLOT_KERNEL_ID_9;
          12'd400: reg_data_out <= C_SLOT_KERNEL_ID_10;
          12'd416: reg_data_out <= C_SLOT_KERNEL_ID_11;
          12'd432: reg_data_out <= C_SLOT_KERNEL_ID_12;
          12'd448: reg_data_out <= C_SLOT_KERNEL_ID_13;
          12'd464: reg_data_out <= C_SLOT_KERNEL_ID_14;
          12'd480: reg_data_out <= C_SLOT_KERNEL_ID_15;
          12'd496: reg_data_out <= C_SLOT_KERNEL_ID_16;
          12'd512: reg_data_out <= C_SLOT_KERNEL_ID_17;
          12'd528: reg_data_out <= C_SLOT_KERNEL_ID_18;
          12'd544: reg_data_out <= C_SLOT_KERNEL_ID_19;
          12'd560: reg_data_out <= C_SLOT_KERNEL_ID_20;
          12'd576: reg_data_out <= C_SLOT_KERNEL_ID_21;
          12'd592: reg_data_out <= C_SLOT_KERNEL_ID_22;
          12'd608: reg_data_out <= C_SLOT_KERNEL_ID_23;
          12'd624: reg_data_out <= C_SLOT_KERNEL_ID_24;
          12'd640: reg_data_out <= C_SLOT_KERNEL_ID_25;
          12'd656: reg_data_out <= C_SLOT_KERNEL_ID_26;
          12'd672: reg_data_out <= C_SLOT_KERNEL_ID_27;
          12'd688: reg_data_out <= C_SLOT_KERNEL_ID_28;
          12'd704: reg_data_out <= C_SLOT_KERNEL_ID_29;
          12'd720: reg_data_out <= C_SLOT_KERNEL_ID_30;
          12'd736: reg_data_out <= C_SLOT_KERNEL_ID_31;
          12'd752: reg_data_out <= C_SLOT_KERNEL_ID_32;
          12'd768: reg_data_out <= C_SLOT_KERNEL_ID_33;
          12'd784: reg_data_out <= C_SLOT_KERNEL_ID_34;
          12'd800: reg_data_out <= C_SLOT_KERNEL_ID_35;
          12'd816: reg_data_out <= C_SLOT_KERNEL_ID_36;
          12'd832: reg_data_out <= C_SLOT_KERNEL_ID_37;
          12'd848: reg_data_out <= C_SLOT_KERNEL_ID_38;
          12'd864: reg_data_out <= C_SLOT_KERNEL_ID_39;
          12'd880: reg_data_out <= C_SLOT_KERNEL_ID_40;
          12'd896: reg_data_out <= C_SLOT_KERNEL_ID_41;
          12'd912: reg_data_out <= C_SLOT_KERNEL_ID_42;
          12'd928: reg_data_out <= C_SLOT_KERNEL_ID_43;
          12'd944: reg_data_out <= C_SLOT_KERNEL_ID_44;
          12'd960: reg_data_out <= C_SLOT_KERNEL_ID_45;
          12'd976: reg_data_out <= C_SLOT_KERNEL_ID_46;
          12'd992: reg_data_out <= C_SLOT_KERNEL_ID_47;
          12'd1008: reg_data_out <= C_SLOT_KERNEL_ID_48;
          12'd1024: reg_data_out <= C_SLOT_KERNEL_ID_49;
          12'd1040: reg_data_out <= C_SLOT_KERNEL_ID_50;
          12'd1056: reg_data_out <= C_SLOT_KERNEL_ID_51;
          12'd1072: reg_data_out <= C_SLOT_KERNEL_ID_52;
          12'd1088: reg_data_out <= C_SLOT_KERNEL_ID_53;
          12'd1104: reg_data_out <= C_SLOT_KERNEL_ID_54;
          12'd1120: reg_data_out <= C_SLOT_KERNEL_ID_55;
          12'd1136: reg_data_out <= C_SLOT_KERNEL_ID_56;
          12'd1152: reg_data_out <= C_SLOT_KERNEL_ID_57;
          12'd1168: reg_data_out <= C_SLOT_KERNEL_ID_58;
          12'd1184: reg_data_out <= C_SLOT_KERNEL_ID_59;
          12'd1200: reg_data_out <= C_SLOT_KERNEL_ID_60;
          12'd1216: reg_data_out <= C_SLOT_KERNEL_ID_61;
          12'd1232: reg_data_out <= C_SLOT_KERNEL_ID_62;
          12'd1248: reg_data_out <= C_SLOT_KERNEL_ID_63;
          12'd1264: reg_data_out <= C_SLOT_KERNEL_ID_64;
          12'd1280: reg_data_out <= C_SLOT_KERNEL_ID_65;
          12'd1296: reg_data_out <= C_SLOT_KERNEL_ID_66;
          12'd1312: reg_data_out <= C_SLOT_KERNEL_ID_67;
          12'd1328: reg_data_out <= C_SLOT_KERNEL_ID_68;
          12'd1344: reg_data_out <= C_SLOT_KERNEL_ID_69;
          12'd1360: reg_data_out <= C_SLOT_KERNEL_ID_70;
          12'd1376: reg_data_out <= C_SLOT_KERNEL_ID_71;
          12'd1392: reg_data_out <= C_SLOT_KERNEL_ID_72;
          12'd1408: reg_data_out <= C_SLOT_KERNEL_ID_73;
          12'd1424: reg_data_out <= C_SLOT_KERNEL_ID_74;
          12'd1440: reg_data_out <= C_SLOT_KERNEL_ID_75;
          12'd1456: reg_data_out <= C_SLOT_KERNEL_ID_76;
          12'd1472: reg_data_out <= C_SLOT_KERNEL_ID_77;
          12'd1488: reg_data_out <= C_SLOT_KERNEL_ID_78;
          12'd1504: reg_data_out <= C_SLOT_KERNEL_ID_79;
          12'd1520: reg_data_out <= C_SLOT_KERNEL_ID_80;
          12'd1536: reg_data_out <= C_SLOT_KERNEL_ID_81;
          12'd1552: reg_data_out <= C_SLOT_KERNEL_ID_82;
          12'd1568: reg_data_out <= C_SLOT_KERNEL_ID_83;
          12'd1584: reg_data_out <= C_SLOT_KERNEL_ID_84;
          12'd1600: reg_data_out <= C_SLOT_KERNEL_ID_85;
          12'd1616: reg_data_out <= C_SLOT_KERNEL_ID_86;
          12'd1632: reg_data_out <= C_SLOT_KERNEL_ID_87;
          12'd1648: reg_data_out <= C_SLOT_KERNEL_ID_88;
          12'd1664: reg_data_out <= C_SLOT_KERNEL_ID_89;
          12'd1680: reg_data_out <= C_SLOT_KERNEL_ID_90;
          12'd1696: reg_data_out <= C_SLOT_KERNEL_ID_91;
          12'd1712: reg_data_out <= C_SLOT_KERNEL_ID_92;
          12'd1728: reg_data_out <= C_SLOT_KERNEL_ID_93;
          12'd1744: reg_data_out <= C_SLOT_KERNEL_ID_94;
          12'd1760: reg_data_out <= C_SLOT_KERNEL_ID_95;
          12'd1776: reg_data_out <= C_SLOT_KERNEL_ID_96;
          12'd1792: reg_data_out <= C_SLOT_KERNEL_ID_97;
          12'd1808: reg_data_out <= C_SLOT_KERNEL_ID_98;
          12'd1824: reg_data_out <= C_SLOT_KERNEL_ID_99;
          12'd1840: reg_data_out <= C_SLOT_KERNEL_ID_100;
          12'd1856: reg_data_out <= C_SLOT_KERNEL_ID_101;
          12'd1872: reg_data_out <= C_SLOT_KERNEL_ID_102;
          12'd1888: reg_data_out <= C_SLOT_KERNEL_ID_103;
          12'd1904: reg_data_out <= C_SLOT_KERNEL_ID_104;
          12'd1920: reg_data_out <= C_SLOT_KERNEL_ID_105;
          12'd1936: reg_data_out <= C_SLOT_KERNEL_ID_106;
          12'd1952: reg_data_out <= C_SLOT_KERNEL_ID_107;
          12'd1968: reg_data_out <= C_SLOT_KERNEL_ID_108;
          12'd1984: reg_data_out <= C_SLOT_KERNEL_ID_109;
          12'd2000: reg_data_out <= C_SLOT_KERNEL_ID_110;
          12'd2016: reg_data_out <= C_SLOT_KERNEL_ID_111;
          12'd2032: reg_data_out <= C_SLOT_KERNEL_ID_112;
          12'd2048: reg_data_out <= C_SLOT_KERNEL_ID_113;
          12'd2064: reg_data_out <= C_SLOT_KERNEL_ID_114;
          12'd2080: reg_data_out <= C_SLOT_KERNEL_ID_115;
          12'd2096: reg_data_out <= C_SLOT_KERNEL_ID_116;
          12'd2112: reg_data_out <= C_SLOT_KERNEL_ID_117;
          12'd2128: reg_data_out <= C_SLOT_KERNEL_ID_118;
          12'd2144: reg_data_out <= C_SLOT_KERNEL_ID_119;
          12'd2160: reg_data_out <= C_SLOT_KERNEL_ID_120;
          12'd2176: reg_data_out <= C_SLOT_KERNEL_ID_121;
          12'd2192: reg_data_out <= C_SLOT_KERNEL_ID_122;
          12'd2208: reg_data_out <= C_SLOT_KERNEL_ID_123;
          12'd2224: reg_data_out <= C_SLOT_KERNEL_ID_124;
          12'd2240: reg_data_out <= C_SLOT_KERNEL_ID_125;
          12'd2256: reg_data_out <= C_SLOT_KERNEL_ID_126;
          12'd2272: reg_data_out <= C_SLOT_KERNEL_ID_127;
          12'd2288: reg_data_out <= C_SLOT_KERNEL_ID_128;
	        default : reg_data_out <= 32'h13371337;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 32'hDEADBEEF;
	    end
	  else
	    begin
	      // When there is a valid read address (S_AXI_ARVALID) with
	      // acceptance of read address by the slave (axi_arready),
	      // output the read dada
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end
	    end
	end

	// Add user logic here

	// User logic ends

	endmodule
