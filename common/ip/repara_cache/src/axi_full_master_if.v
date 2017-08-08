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

    module AXI_Full_Master_if #
    (
        // Users to add parameters here

        // User parameters ends
        // Do not modify the parameters beyond this line

        // Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
        parameter integer C_M_AXI_BURST_LEN = 1,
        // Thread ID Width
        parameter integer C_M_AXI_ID_WIDTH  = 1,
        // Width of Address Bus
        parameter integer C_M_AXI_ADDR_WIDTH    = 32,
        // Width of Data Bus
        parameter integer C_M_AXI_DATA_WIDTH    = 32,
        // Width of User Write Address Bus
        parameter integer C_M_AXI_AWUSER_WIDTH  = 0,
        // Width of User Read Address Bus
        parameter integer C_M_AXI_ARUSER_WIDTH  = 0,
        // Width of User Write Data Bus
        parameter integer C_M_AXI_WUSER_WIDTH   = 0,
        // Width of User Read Data Bus
        parameter integer C_M_AXI_RUSER_WIDTH   = 0,
        // Width of User Response Bus
        parameter integer C_M_AXI_BUSER_WIDTH   = 0
    )
    (
        // req port
        input  wire [C_M_AXI_ADDR_WIDTH-1 : 0]      EXT_ADDR,
        input  wire                                 EXT_ADDR_VALID,
        output wire                                 EXT_ADDR_READY,
        input  wire [7 : 0]                         EXT_LEN,
        input  wire [C_M_AXI_DATA_WIDTH-1 : 0]      EXT_WR_DATA,
        input  wire [C_M_AXI_DATA_WIDTH/8-1 : 0]    EXT_WR_STRB,
        input  wire                                 EXT_WR_VALID,
        output wire                                 EXT_WR_READY,
        output wire [C_M_AXI_DATA_WIDTH-1 : 0]      EXT_RD_DATA,
        output wire                                 EXT_RD_VALID,
        input  wire                                 EXT_RD_READY,

    // Global Clock Signal.
        input wire  M_AXI_ACLK,
        // Global Reset Singal. This Signal is Active Low
        input wire  M_AXI_ARESETN,

    // Master Interface Write Address ID
        output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
        // Master Interface Write Address
        output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        output wire [7 : 0] M_AXI_AWLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        output wire [2 : 0] M_AXI_AWSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        output wire [1 : 0] M_AXI_AWBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        output wire  M_AXI_AWLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        output wire [3 : 0] M_AXI_AWCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        output wire [2 : 0] M_AXI_AWPROT,
        // Quality of Service, QoS identifier sent for each write transaction.
        output wire [3 : 0] M_AXI_AWQOS,
        // Optional User-defined signal in the write address channel.
        output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid write address and control information.
        output wire  M_AXI_AWVALID,
        // Write address ready. This signal indicates that
        // the slave is ready to accept an address and associated control signals
        input wire  M_AXI_AWREADY,

    // Master Interface Write Data.
        output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
        // Write strobes. This signal indicates which byte
        // lanes hold valid data. There is one write strobe
        // bit for each eight bits of the write data bus.
        output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
        // Write last. This signal indicates the last transfer in a write burst.
        output wire  M_AXI_WLAST,
        // Optional User-defined signal in the write data channel.
        output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
        // Write valid. This signal indicates that valid write
        // data and strobes are available
        output wire  M_AXI_WVALID,
        // Write ready. This signal indicates that the slave
        // can accept the write data.
        input wire  M_AXI_WREADY,

    // Master Interface Write Response.
        input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
        // Write response. This signal indicates the status of the write transaction.
        input wire [1 : 0] M_AXI_BRESP,
        // Optional User-defined signal in the write response channel
        input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
        // Write response valid. This signal indicates that the
        // channel is signaling a valid write response.
        input wire  M_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        output wire  M_AXI_BREADY,

    // Master Interface Read Address.
        output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
        // Read address. This signal indicates the initial
        // address of a read burst transaction.
        output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        output wire [7 : 0] M_AXI_ARLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        output wire [2 : 0] M_AXI_ARSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        output wire [1 : 0] M_AXI_ARBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        output wire  M_AXI_ARLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        output wire [3 : 0] M_AXI_ARCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        output wire [2 : 0] M_AXI_ARPROT,
        // Quality of Service, QoS identifier sent for each read transaction
        output wire [3 : 0] M_AXI_ARQOS,
        // Optional User-defined signal in the read address channel.
        output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid read address and control information
        output wire  M_AXI_ARVALID,
        // Read address ready. This signal indicates that
        // the slave is ready to accept an address and associated control signals
        input wire  M_AXI_ARREADY,

    // Read ID tag. This signal is the identification tag
        // for the read data group of signals generated by the slave.
        input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
        // Master Read Data
        input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
        // Read response. This signal indicates the status of the read transfer
        input wire [1 : 0] M_AXI_RRESP,
        // Read last. This signal indicates the last transfer in a read burst
        input wire  M_AXI_RLAST,
        // Optional User-defined signal in the read address channel.
        input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
        // Read valid. This signal indicates that the channel
        // is signaling the required read data.
        input wire  M_AXI_RVALID,
        // Read ready. This signal indicates that the master can
        // accept the read data and response information.
        output wire  M_AXI_RREADY
    );


      // function called clogb2 that returns an integer which has the
      // value of the ceiling of the log base 2.
      function integer clogb2 (input integer bit_depth);
      begin
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
          bit_depth = bit_depth >> 1;
        end
      endfunction

    // AXI4FULL signals
    //AXI4 internal temp signals
    reg [C_M_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg axi_awvalid;
    reg [C_M_AXI_DATA_WIDTH-1 : 0]  axi_wdata;
    reg [C_M_AXI_DATA_WIDTH/8-1 : 0]  axi_wstrb;
    reg axi_wlast;
    reg axi_wvalid;
    reg axi_bready;
    reg [C_M_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg axi_arvalid;
    reg axi_rready;

    //internal regs
    
    reg running_wr, running_rd;
    reg i_ext_addr_ready, i_ext_wr_ready, i_ext_rd_valid;
    reg [C_M_AXI_ADDR_WIDTH-1 : 0]   i_addr;
    reg [7 : 0]                      i_len;
    reg [C_M_AXI_DATA_WIDTH-1 : 0]   i_wr_data;
    reg [C_M_AXI_DATA_WIDTH/8-1 : 0] i_wr_strb;
    reg [C_M_AXI_DATA_WIDTH-1 : 0]   i_rd_data;
    wire clk;
    wire reset;
    
    
    //I/O Connections.
    //Write Address (AW)
    assign M_AXI_AWID   = 'b0;
    //The AXI address is a concatenation of the target base address + active offset range
    assign M_AXI_AWADDR = axi_awaddr;
    //Burst LENgth is number of transaction beats
    
    
    //xxx    always 1
    assign M_AXI_AWLEN  = EXT_LEN;
    
    
    
    //Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
    assign M_AXI_AWSIZE = clogb2((C_M_AXI_DATA_WIDTH/8)-1);
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_AWBURST= 2'b01;
    assign M_AXI_AWLOCK = 1'b0;
    //Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
    assign M_AXI_AWCACHE= 4'b0011;
    assign M_AXI_AWPROT = 3'h0;
    assign M_AXI_AWQOS  = 4'h0;
    assign M_AXI_AWUSER = 'b0;
    assign M_AXI_AWVALID= axi_awvalid;

    //Write Data(W)
    assign M_AXI_WDATA  = axi_wdata;
    assign M_AXI_WSTRB  = axi_wstrb;
    assign M_AXI_WLAST  = axi_wlast;
    assign M_AXI_WUSER  = 'b0;
    assign M_AXI_WVALID = axi_wvalid;

    //Write Response (B)
    assign M_AXI_BREADY = axi_bready;

    //Read Address (AR)
    assign M_AXI_ARID   = 'b0;

    assign M_AXI_ARADDR = axi_araddr;
    //Burst LENgth is number of transaction beats, minus 1
    //xxx always 1
    assign M_AXI_ARLEN  = 8'b0;
    //Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
    assign M_AXI_ARSIZE = clogb2((C_M_AXI_DATA_WIDTH/8)-1);
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_ARBURST= 2'b01;

    assign M_AXI_ARLOCK = 1'b0;
    //Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
    assign M_AXI_ARCACHE= 4'b0011;
    assign M_AXI_ARPROT = 3'h0;
    assign M_AXI_ARQOS  = 4'h0;
    assign M_AXI_ARUSER = 'b0;

    assign M_AXI_ARVALID= axi_arvalid;

    //Read and Read Response (R)
    assign M_AXI_RREADY = axi_rready;


    assign EXT_ADDR_READY   = i_ext_addr_ready;
    assign EXT_WR_READY     = i_ext_wr_ready;
    assign EXT_RD_DATA      = i_rd_data;
    assign EXT_RD_VALID     = i_ext_rd_valid;
    

    assign clk = M_AXI_ACLK;
    assign reset = ~M_AXI_ARESETN;

    reg running_wbeat;
    //--------------------
    //Request port handling
    //--------------------
    always @(posedge clk) begin
        if (reset) begin
            running_rd          <= 0;
            running_wr          <= 0;
        end else begin
            if (~running_rd && ~running_wr) begin
                //no active transfer
                i_ext_addr_ready    <= 1;
                i_ext_wr_ready      <= 1;
                running_wbeat       <= 0;
                cnt                 <= 0;
                i_w_done            <= 0;
                if (i_ext_addr_ready && EXT_ADDR_VALID &&  i_ext_wr_ready && EXT_WR_VALID) begin
                    //wr req
                    i_ext_addr_ready    <= 0;
                    i_ext_wr_ready      <= 0;
                    //latch parameters
                    i_wr_data           <= EXT_WR_DATA;
                    i_wr_strb           <= EXT_WR_STRB;
                    i_addr              <= EXT_ADDR;
                    i_len               <= EXT_LEN;
                    //signal to start transfer
                    running_wr          <= 1;
                    running_wbeat       <= 1;
                end
                if (i_ext_addr_ready && EXT_ADDR_VALID &&  i_ext_wr_ready && ~EXT_WR_VALID) begin
                    //rd req
                    i_ext_addr_ready    <= 0;
                    i_ext_wr_ready      <= 0;
                    //latch parameters
                    i_addr              <= EXT_ADDR;
                    i_len               <= EXT_LEN;
                    //signal to start transfer
                    running_rd          <= 1;
                end
            end else if (running_wr) begin
                //active write
                
                if (i_ext_wr_ready & EXT_WR_VALID) begin
                    i_ext_wr_ready      <= 0;
                    //latch parameters
                    i_wr_data           <= EXT_WR_DATA;
                    i_wr_strb           <= EXT_WR_STRB;
                    //start write beat
                    running_wbeat       <= 1;
                end

                if (i_wbeat_done) begin
                    running_wbeat       <= 0;
                    //incr counter at the end of the beat
                    if (i_len != cnt) begin
                        cnt         <= cnt + 1;
                        //write beat finished, so get the next data from EXT side
                        //if till to go
                        i_ext_wr_ready      <= 1;
                    end 
                    
                end
                
                if (i_wbeat_done & (cnt == i_len) ) begin
                    i_w_done <= 1;
                end

                if (i_aw_done & i_w_done & i_b_done) begin
                    //both addr, data and response channel finished, so transfer is finished
                    running_wr          <= 0;
                    running_wbeat       <= 0;
                    cnt                 <= 0;
                end
            end else if (running_rd) begin
                //active read
                i_ext_addr_ready    <= 0;
                i_ext_wr_ready      <= 0;
                if (i_ar_done && i_r_done) begin
                    //both addr and data channel finished, so transfer is finished
                    running_rd      <= 0;
                end
            end
        end
    end

    //--------------------
    //Write Address Channel
    //--------------------
    reg i_aw_done;

    always @(posedge clk) begin
        if (reset) begin
            axi_awvalid <= 1'b0;
            axi_awaddr <= 'b0;
            i_aw_done   <= 0;
        end else if (~axi_awvalid && running_wr && ~i_aw_done) begin
            //no running transfer and a request came in
            axi_awvalid <= 1'b1;
            axi_awaddr  <= i_addr;
            i_aw_done   <= 0;
        end else if (M_AXI_AWREADY && axi_awvalid && running_wr) begin
            //transaction is accepted
            axi_awvalid <= 1'b0;
            i_aw_done   <= 1;
        end  else if (i_aw_done && ~running_wr) begin
            //running flag is deasserted, so go back to idle
            i_aw_done   <= 0;
        end
    end

    //--------------------
    //Write Data Channel
    //--------------------
    reg i_wbeat_done, i_w_done;

    // WVALID logic
    always @(posedge clk) begin
        //pulse
        i_wbeat_done    <= 0;
        if (running_wr) begin
            if (running_wbeat ) begin
                if(~axi_wvalid & ~i_wbeat_done) begin
                    //prev beat finished, start the next
                    axi_wvalid  <= 1'b1;
                    axi_wdata   <= i_wr_data;
                    axi_wstrb   <= i_wr_strb;
                    //set wlast at the beginning of the beat
                    if (i_len == cnt) begin
                        axi_wlast   <= 1'b1;
                    end 
                                    
                end else if (axi_wvalid & M_AXI_WREADY  ) begin
                    //current write beat finished
                    axi_wvalid      <= 1'b0;
                    i_wbeat_done    <= 1;
                end 
            end else begin
                //running_wbeat flag is deasserted, so go back to idle
                axi_wvalid      <= 1'b0;
            end
        end else begin
            //running_wr flag is deasserted, so go back to idle
            axi_wvalid      <= 1'b0;
            axi_wlast       <= 1'b0;
        end
    end

    reg [7:0] cnt;

    //----------------------------
    //Write Response (B) Channel
    //----------------------------
    reg i_b_done;
    
    always @(posedge clk)  begin
        if (reset | ~running_wr) begin
            axi_bready  <= 1'b0;
            i_b_done    <= 0;
        end
        else if (M_AXI_BVALID && ~axi_bready && running_wr) begin
            // accept/acknowledge bresp with axi_bready by the master
            // when M_AXI_BVALID is asserted by slave
            axi_bready  <= 1'b1;    
            i_b_done    <= 1;
        end
        else if (axi_bready) begin                                    // deassert after one clock cycle
            axi_bready <= 1'b0;
        end
    end

    //----------------------------
    //Read Address Channel
    //----------------------------
    reg i_ar_done;

    always @(posedge clk) begin
        if (reset) begin
            axi_arvalid <= 1'b0;
            axi_araddr <= 'b0;
            i_ar_done   <= 0;
        end else if (~axi_arvalid && running_rd && ~i_ar_done) begin
            //no running transfer and a request came in
            axi_arvalid <= 1'b1;
            axi_araddr  <= i_addr;
            i_ar_done   <= 0;
        end else if (M_AXI_ARREADY && axi_arvalid && running_rd) begin
            //transaction is accepted
            axi_arvalid <= 1'b0;
            i_ar_done   <= 1;
        end  else if (i_ar_done && ~running_rd) begin
            //running flag is deasserted, so go back to idle
            i_ar_done   <= 0;
        end
    end

    //--------------------------------
    //Read Data (and Response) Channel
    //--------------------------------
    wire rnext;
    reg i_r_done;
    // Forward movement occurs when the channel is valid and ready
    assign rnext = M_AXI_RVALID && axi_rready;

    // The Read Data channel returns the results of the read request

    // In this example the data checker is always able to accept
    // more data, so no need to throttle the RREADY signal
    always @(posedge clk) begin
        if (reset | ~running_rd) begin
            axi_rready          <= 1'b0;
            i_r_done            <= 0;
            i_ext_rd_valid      <= 0;
        end else if (running_rd && ~i_r_done) begin
            // accept/acknowledge rdata/rresp with axi_rready by the master
            // when M_AXI_RVALID is asserted by slave
            if (M_AXI_RVALID && ~axi_rready) begin
                axi_rready <= 1'b1;
            end else if (M_AXI_RVALID && M_AXI_RLAST && axi_rready) begin
                //take data from AXI Slave, and give it to the ext port
                axi_rready          <= 1'b0;
                i_ext_rd_valid      <= 1;
                i_rd_data           <= M_AXI_RDATA;
            end else if (i_ext_rd_valid && EXT_RD_READY) begin
                //ext port has taken data, read transfer is done
                i_ext_rd_valid      <= 0;
                i_r_done            <= 1;
            end
        end
    end
    
endmodule
