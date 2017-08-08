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

    module AXI_Full_Slave_if #
    (
        // Width of ID for for write address, write data, read address and read data
        parameter integer C_S_AXI_ID_WIDTH    = 1,
        // Width of S_AXI data bus
        parameter integer C_S_AXI_DATA_WIDTH    = 32,
        // Width of S_AXI address bus
        parameter integer C_S_AXI_ADDR_WIDTH    = 32,
        // Width of optional user defined signal in write address channel
        parameter integer C_S_AXI_AWUSER_WIDTH    = 1,
        // Width of optional user defined signal in read address channel
        parameter integer C_S_AXI_ARUSER_WIDTH    = 1,
        // Width of optional user defined signal in write data channel
        parameter integer C_S_AXI_WUSER_WIDTH    = 1,
        // Width of optional user defined signal in read data channel
        parameter integer C_S_AXI_RUSER_WIDTH    = 1,
        // Width of optional user defined signal in write response channel
        parameter integer C_S_AXI_BUSER_WIDTH    = 1
    )
    (
        //external port
        output wire [C_S_AXI_ADDR_WIDTH-1 : 0]      EXT_ADDR,
        input wire                                  EXT_ADDR_READY,
        output wire                                 EXT_ADDR_VALID,
        input wire  [C_S_AXI_DATA_WIDTH-1 : 0]      EXT_RD_DATA,
        input wire                                  EXT_RD_VALID,
        output wire                                 EXT_RD_READY,
        output wire [C_S_AXI_DATA_WIDTH-1 : 0]      EXT_WR_DATA,
        output wire [C_S_AXI_DATA_WIDTH/8-1 : 0]    EXT_WR_STRB,
        output wire                                 EXT_WR_VALID,
        input wire                                  EXT_WR_READY,

    // Global Clock Signal
        input wire  S_AXI_ACLK,
        // Global Reset Signal. This Signal is Active LOW
        input wire  S_AXI_ARESETN,
        
    // Write Address ID
        input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_AWID,
        // Write address
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        input wire [7 : 0] S_AXI_AWLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        input wire [2 : 0] S_AXI_AWSIZE,
        // Burst type. The burst type and the size information, 
        // determine how the address for each transfer within the burst is calculated.
        input wire [1 : 0] S_AXI_AWBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        input wire  S_AXI_AWLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        input wire [3 : 0] S_AXI_AWCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_AWPROT,
        // Quality of Service, QoS identifier sent for each
        // write transaction.
        input wire [3 : 0] S_AXI_AWQOS,
        // Region identifier. Permits a single physical interface
        // on a slave to be used for multiple logical interfaces.
        input wire [3 : 0] S_AXI_AWREGION,
        // Optional User-defined signal in the write address channel.
        input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] S_AXI_AWUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid write address and
        // control information.
        input wire  S_AXI_AWVALID,
        // Write address ready. This signal indicates that
        // the slave is ready to accept an address and associated
        // control signals.
        output wire  S_AXI_AWREADY,
        
    // Write Data
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
        // Write strobes. This signal indicates which byte
        // lanes hold valid data. There is one write strobe
        // bit for each eight bits of the write data bus.
        input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
        // Write last. This signal indicates the last transfer
        // in a write burst.
        input wire  S_AXI_WLAST,
        // Optional User-defined signal in the write data channel.
        input wire [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
        // Write valid. This signal indicates that valid write
        // data and strobes are available.
        input wire  S_AXI_WVALID,
        // Write ready. This signal indicates that the slave
        // can accept the write data.
        output wire  S_AXI_WREADY,
        
    // Response ID tag. This signal is the ID tag of the
        // write response.
        output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_BID,
        // Write response. This signal indicates the status
        // of the write transaction.
        output wire [1 : 0] S_AXI_BRESP,
        // Optional User-defined signal in the write response channel.
        output wire [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
        // Write response valid. This signal indicates that the
        // channel is signaling a valid write response.
        output wire  S_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        input wire  S_AXI_BREADY,
        
    // Read address ID. This signal is the identification
        // tag for the read address group of signals.
        input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_ARID,
        // Read address. This signal indicates the initial
        // address of a read burst transaction.
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        input wire [7 : 0] S_AXI_ARLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        input wire [2 : 0] S_AXI_ARSIZE,
        // Burst type. The burst type and the size information, 
        // determine how the address for each transfer within the burst is calculated.
        input wire [1 : 0] S_AXI_ARBURST,
        // Lock type. Provides additional information about the
        // atomic characteristics of the transfer.
        input wire  S_AXI_ARLOCK,
        // Memory type. This signal indicates how transactions
        // are required to progress through a system.
        input wire [3 : 0] S_AXI_ARCACHE,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_ARPROT,
        // Quality of Service, QoS identifier sent for each
        // read transaction.
        input wire [3 : 0] S_AXI_ARQOS,
        // Region identifier. Permits a single physical interface
        // on a slave to be used for multiple logical interfaces.
        input wire [3 : 0] S_AXI_ARREGION,
        // Optional User-defined signal in the read address channel.
        input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] S_AXI_ARUSER,
        // Write address valid. This signal indicates that
        // the channel is signaling valid read address and
        // control information.
        input wire  S_AXI_ARVALID,    
        // Read address ready. This signal indicates that
        // the slave is ready to accept an address and associated
        // control signals.
        output wire  S_AXI_ARREADY,
        
    // Read ID tag. This signal is the identification tag
        // for the read data group of signals generated by the slave.
        output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_RID,
        // Read Data
        output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
        // Read response. This signal indicates the status of
        // the read transfer.
        output wire [1 : 0] S_AXI_RRESP,
        // Read last. This signal indicates the last transfer
        // in a read burst.
        output wire  S_AXI_RLAST,
        // Optional User-defined signal in the read address channel.
        output wire [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
        // Read valid. This signal indicates that the channel
        // is signaling the required read data.
        output wire  S_AXI_RVALID,
        // Read ready. This signal indicates that the master can
        // accept the read data and response information.
        input wire  S_AXI_RREADY
    );

	// function called clogb2 that returns an integer which has the 
	// value of the ceiling of the log base 2.                      
	function integer clogb2 (input integer bit_depth);              
	begin                                                           
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
            bit_depth = bit_depth >> 1;                                 
    end
	endfunction                                                     
    
    //local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    //ADDR_LSB = 2 for 32 bits (n downto 2) 
    //ADDR_LSB = 3 for 64 bits (n downto 3)
    //ADDR_LSB = 4 for 128 bits (n downto 4)
    //ADDR_LSB = 5 for 256 bits (n downto 5)
    //ADDR_LSB = 6 for 512 bits (n downto 6)
//xxx formula changed
    //localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32)+ 1;
    localparam integer ADDR_LSB = clogb2( C_S_AXI_DATA_WIDTH/8 -1);
    
    // AXI4FULL signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg [C_S_AXI_ID_WIDTH-1 : 0] axi_awid;
    reg axi_awready;
    reg axi_wready;
    
    //reg [1 : 0]    axi_bresp; 
    reg axi_bvalid;
    
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg axi_arready;
    
    //reg [1 : 0] axi_rresp; 
    
    reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
    reg axi_rlast;
    //wire axi_rvalid;
    
    // aw_wrap_en determines wrap boundary and enables wrapping
    wire aw_wrap_en;
    // ar_wrap_en determines wrap boundary and enables wrapping
    wire ar_wrap_en;
    // aw_wrap_size is the size of the write transfer, the
    // write address wraps to a lower address if upper address
    // limit is reached
    wire integer  aw_wrap_size ; 
    // ar_wrap_size is the size of the read transfer, the
    // read address wraps to a lower address if upper address
    // limit is reached
    wire integer  ar_wrap_size ; 
    // The axi_awlen_cntr internal write address counter to keep track of beats in a burst transaction
    reg [7:0] axi_awlen_cntr;
    //The axi_arlen_cntr internal read address counter to keep track of address beats in a burst transaction
    reg [7:0] axi_arlen_cntr;
    //The axi_rlen_cntr internal read address counter to keep track of data beats in a burst transaction
    reg [7:0] axi_rlen_cntr;
    // The running_wr flag marks the presence of write address valid
    reg running_wr;
    //The running_rd flag marks the presence of read address valid
    reg running_rd; 

    reg [C_S_AXI_ID_WIDTH-1:0] axi_arid;
    reg ext_addr_valid_rd;
    reg ext_addr_valid_wr;
    
    // I/O Connections assignments
    
    assign S_AXI_ARREADY    = axi_arready;
              
    assign S_AXI_RID        = axi_arid;
    // always return OKAY
    assign S_AXI_RRESP      = 0;
    assign S_AXI_RLAST      = axi_rlast;
    assign S_AXI_RUSER      = 0;
    assign S_AXI_RVALID     = EXT_RD_VALID & running_rd; 
    assign S_AXI_RDATA      = EXT_RD_DATA; 
    assign EXT_RD_READY     = S_AXI_RREADY ;
    assign RD_ADDR          = axi_araddr;
    
    assign S_AXI_AWREADY    = axi_awready;
    //xxx S_AXI_WREADY was changed: 
    //      original code: assert at first byte, deassert at last
    //      needed: for every byte check if the slave says it is ready.
    //              so AND together the internal ready flag and the EXT_WR_READY.
    assign S_AXI_WREADY     = axi_wready & EXT_WR_READY;
    assign EXT_WR_DATA      = S_AXI_WDATA;
    assign EXT_WR_STRB      = S_AXI_WSTRB;

    //assign EXT_WR_VALID     = S_AXI_WVALID;
    //xxx 
    assign EXT_WR_VALID     = axi_wready;
    
    assign S_AXI_BID        = axi_awid;
    // always return OKAY
    assign S_AXI_BRESP      = 0;
    assign S_AXI_BUSER      = 0;
    assign S_AXI_BVALID     = axi_bvalid;
    
    assign aw_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (S_AXI_AWLEN)); 
    assign ar_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (S_AXI_ARLEN)); 
    assign aw_wrap_en   = ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
    assign ar_wrap_en   = ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;


    //--------------------------
    // external address generation
    //--------------------------
    //
    assign EXT_ADDR = ( running_wr ) ? axi_awaddr : axi_araddr;
    assign EXT_ADDR_VALID = ext_addr_valid_rd | axi_wready;//xxx ext_addr_valid_rd | ext_addr_valid_wr;


    // Implement axi_awready generation

    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.
    
//xxx comment is wrong here: to assert S_AXI_AWREADY we do not wait for S_AXI_WVALID. 
//We only wait for AWVALID and the prev transfers(R+w) to finish.
//The code is right though.
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
          axi_awready <= 1'b0;
          running_wr <= 1'b0;
      end 
      else begin    
          //xxx note: only allow awready if EXT_ADDR_READY is 1
          if (~axi_awready && S_AXI_AWVALID && ~running_wr && ~running_rd && EXT_ADDR_READY) begin     // slave is ready to accept an address and associated control signals
              axi_awready       <= 1'b1;
              running_wr  <= 1'b1;                                            // used for generation of bresp() and bvalid
          end
          else if (S_AXI_WLAST && S_AXI_WREADY) begin                                 // preparing to accept next address after current write burst tx completion       
              running_wr  <= 1'b0;
          end
          else begin
              axi_awready <= 1'b0;
          end
      end 
    end    
    
    // Implement axi_wready generation

    // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    // de-asserted when reset is low. 

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_wready <= 1'b0;
        end 
        else begin    
            if ( ~axi_wready && S_AXI_WVALID && running_wr ) begin               // slave can accept the write data
                axi_wready <= 1'b1;
            end
            else if (S_AXI_WLAST && S_AXI_WREADY) begin
                axi_wready <= 1'b0;
            end
        end 
    end     
    
    // Implement axi_awaddr latching

    // This process is used to latch the address when both 
    // S_AXI_AWVALID and S_AXI_WVALID are valid. 
    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awaddr <= 0;
            axi_awlen_cntr <= 0;
            ext_addr_valid_wr <= 0;
        end 
        else begin    
            //default assignment as it is a pulse, and we only allow asserting the valid, when the ext module is ready (EXT_ADDR_READY=1)
            ext_addr_valid_wr <= 0;
                        
            if (~axi_awready && S_AXI_AWVALID && ~running_wr && ~running_rd && EXT_ADDR_READY) begin
                // address latching 
                axi_awaddr <= S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH - 1:0];                 
                // start address of transfer
                axi_awlen_cntr <= 0;                                                    
                axi_awid  <= S_AXI_AWID;
                ext_addr_valid_wr <= 1;
            end   
            //xxx note: only allow addr in if EXT_ADDR_READY is 1
//xxx try   else if((axi_awlen_cntr <= S_AXI_AWLEN) && S_AXI_WREADY && S_AXI_WVALID && EXT_ADDR_READY) begin
            else if((axi_awlen_cntr < S_AXI_AWLEN) && S_AXI_WREADY && S_AXI_WVALID && EXT_ADDR_READY) begin
                axi_awlen_cntr <= axi_awlen_cntr + 1;
                ext_addr_valid_wr <= 1;
                case (S_AXI_AWBURST)
                  2'b00: begin // fixed burst
                      // The write address for all the beats in the transaction are fixed
                      axi_awaddr <= axi_awaddr;          
                      //for awsize = 4 bytes (010)
                  end   
                  2'b01: begin //incremental burst
                      // The write address for all the beats in the transaction are increments by awsize
                      axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                      axi_awaddr[ADDR_LSB-1:0]                    <= {ADDR_LSB{1'b0}};     
                      //awaddr aligned to 4 byte boundary
                      //for awsize = 4 bytes (010)
                  end   
                  2'b10: //Wrapping burst
                      // The write address wraps when the address reaches wrap boundary 
                      if (aw_wrap_en) begin
                          axi_awaddr <= (axi_awaddr - aw_wrap_size); 
                      end
                      else begin
                          axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                          axi_awaddr[ADDR_LSB-1:0]                    <= {ADDR_LSB{1'b0}}; 
                      end                      
                  default: begin //reserved (incremental burst for example)
                     axi_awaddr <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                     //for awsize = 4 bytes (010)
                  end
                endcase              
            end
        end 
    end            
    
    
    // Implement write response logic generation

    // The write response and response valid signals are asserted by the slave 
    // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    // This marks the acceptance of address and indicates the status of 
    // write transaction.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 ) begin
          axi_bvalid <= 0;
//          axi_bresp <= 2'b0;
      end 
      else begin    
          if (running_wr && S_AXI_WREADY && S_AXI_WVALID && ~axi_bvalid && S_AXI_WLAST ) begin
//          if (S_AXI_WDONE_MOSI) begin
              axi_bvalid <= 1'b1;
//              axi_bresp  <= 2'b0; 
              // 'OKAY' response 
          end                   
          else begin
              if (S_AXI_BREADY && axi_bvalid) begin
                  //check if bready is asserted while bvalid is high) 
                  //(there is a possibility that bready is always asserted high)   
                  axi_bvalid <= 1'b0; 
              end  
          end
      end
    end   
    
     
    // Implement axi_arready generation

    // axi_arready is asserted for one S_AXI_ACLK clock cycle when
    // S_AXI_ARVALID is asserted. axi_arready is 
    // asserted when reset (active low) is asserted. 
    // The read address is also latched when S_AXI_ARVALID is 
    // asserted. axi_araddr is reset to zero on reset assertion.

    always @( posedge S_AXI_ACLK )
    begin
       if ( S_AXI_ARESETN == 1'b0 ) begin
           axi_arready <= 1'b0;
           running_rd <= 1'b0;
       end 
       else begin    
           //xxx note: only allow arready if EXT_ADDR_READY is 1
           //wr has prio.
           if (~axi_arready && S_AXI_ARVALID && ~S_AXI_AWVALID && ~running_wr && ~running_rd && EXT_ADDR_READY) begin
               axi_arready      <= 1'b1;
               running_rd <= 1'b1;
           end
//           else if (EXT_RD_VALID && S_AXI_RREADY && axi_arlen_cntr == S_AXI_ARLEN) begin
           else if (EXT_RD_VALID && S_AXI_RREADY && axi_rlen_cntr == S_AXI_ARLEN) begin
               // completion of current read 
               running_rd <= 1'b0;
           end
           else begin
               axi_arready <= 1'b0;
           end
       end 
    end       

//read address and read data must be handled on EXT_ IF as separate channels.
//so we need 2 counters: rd addr, rd data. 
//rlast is depending on the rd data cnt.
//running_rd is deasserted when rd data cnt reaches max value.
    
    // Implement rlast
    
    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_rlen_cntr <= 0;
            axi_rlast <= 1'b0;
        end else begin    
            if (running_rd) begin
                if (0 == S_AXI_ARLEN) begin
                    //single
                    axi_rlast <= 1'b1;
                end else begin
                    //burst
                    if (EXT_RD_READY && EXT_RD_VALID) begin
                        axi_rlen_cntr <= axi_rlen_cntr + 1;
                        if((axi_rlen_cntr == S_AXI_ARLEN - 1) ) begin
                            axi_rlast <= 1'b1;
                        end 
                    end 
                end
            end else begin
                axi_rlen_cntr <= 0;
                axi_rlast <= 1'b0;
            end
        end
    end
    
    // Implement axi_araddr latching

    //This process is used to latch the address when both 
    //S_AXI_ARVALID and S_AXI_RVALID are valid. 
    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_araddr <= 0;
            axi_arlen_cntr <= 0;
            axi_arid <= 0;
            ext_addr_valid_rd <= 0;
        end 
        else begin    
            //wr has prio
            if (~axi_arready && S_AXI_ARVALID && ~S_AXI_AWVALID  && ~running_rd && ~running_wr && EXT_ADDR_READY ) begin
                // address latching 
                axi_araddr <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH - 1:0]; 
                axi_arid <= S_AXI_ARID[C_S_AXI_ID_WIDTH-1:0];
                ext_addr_valid_rd <= 1;
                // start address of transfer
                axi_arlen_cntr <= 0;
            end              
            //xxx note: only allow addr incr if EXT_ADDR_READY is 1
            else if((axi_arlen_cntr < S_AXI_ARLEN) && running_rd && EXT_ADDR_READY) begin
                axi_arlen_cntr <= axi_arlen_cntr + 1;
                ext_addr_valid_rd <= 1;
                case (S_AXI_ARBURST)
                    2'b00: begin // fixed burst
                        // The read address for all the beats in the transaction are fixed
                        axi_araddr <= axi_araddr;        
                    end   
                    2'b01: begin //incremental burst
                        // The read address for all the beats in the transaction are increments by awsize
                        axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                        //araddr aligned to 4 byte boundary
                        axi_araddr[ADDR_LSB-1:0]                    <= {ADDR_LSB{1'b0}};   
                    end   
                    2'b10: //Wrapping burst
                        // The read address wraps when the address reaches wrap boundary 
                        if (ar_wrap_en) begin
                            axi_araddr <= (axi_araddr - ar_wrap_size); 
                        end
                        else begin
                            axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                            //araddr aligned to 4 byte boundary
                            axi_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                    end                      
                    default: begin //reserved (incremental burst for example)
                        axi_araddr <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
                    end
                endcase              
            end
            else if((axi_arlen_cntr == S_AXI_ARLEN) && EXT_ADDR_READY) begin
                ext_addr_valid_rd <= 0;
            end
        end 
    end       
    
//xxx REMOVED internal axi_rvalid generation, since it is coming from the external module (EXT_RD_VALID)
    
    // Implement axi_rvalid generation

//    // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
//    // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
//    // data are available on the axi_rdata bus at this instance. The 
//    // assertion of axi_rvalid marks the validity of read data on the 
//    // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
//    // is deasserted on reset (active low). axi_rresp and axi_rdata are 
//    // cleared to zero on reset (active low).  
//
//    always @( posedge S_AXI_ACLK )
//    begin
//      if ( S_AXI_ARESETN == 1'b0 ) begin
////          axi_rvalid <= 0;
//          axi_rresp  <= 0;
//      end 
//      else begin    
//          if (running_rd && ~axi_rvalid) begin
////          if (running_rd && ~axi_rvalid) begin
////              axi_rvalid <= 1'b1;
//              axi_rresp  <= 2'b0; 
//              // 'OKAY' response
//          end   
//          else if (axi_rvalid && S_AXI_RREADY) begin
////              axi_rvalid <= 1'b0;
//          end            
//      end
//    end        


endmodule
