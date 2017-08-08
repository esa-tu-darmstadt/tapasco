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

    module l1_rwm #
    (
        // Width of input address bus
        parameter integer C_AXI_ADDR_WIDTH          = 32,
        // Width of axi master full data bus
        parameter integer C_AXI_MF_DATA_WIDTH       = 128,
        // Width of axi slave full data bus
        parameter integer C_AXI_SF_DATA_WIDTH       = 32,
        // Write strategy: "WR_THROUGH", "WR_BACK"
        parameter C_WR_STRATEGY                     = "WR_THROUGH" ,
       
        // Width of tagline 
        parameter integer C_TAGLINE_DATA_WIDTH      = 24,        
        // Width of cacheline 
        parameter integer C_CACHELINE_DATA_WIDTH    = 256,

        // Ratio of AXI master & slave data width
        parameter integer C_MF_SF_RATIO             = 4,
        // Ratio of Cache line & AXI slave data width
        parameter integer C_CL_SF_RATIO             = 8,
        // Ratio of Cache line & AXI master data width
        parameter integer C_CL_MF_RATIO             = 2,
        // Unused bits in AXI slave address
        parameter integer C_SF_ADDR_LSB             = 2,
        // Unused bits in AXI master address
        parameter integer C_MF_ADDR_LSB             = 7,
        // Cache data address index offset part         
        parameter integer C_IDX_OFFS                = 3    
        
    )
    (
        // Global Clock Signal
        input wire  clk,
        // Global Reset Signal
        input wire  reset,
        
        // from/to AXI Full slave
        input  wire [C_AXI_ADDR_WIDTH-1 : 0]        axi_s_addr,
        input  wire                                 axi_s_addr_valid,
        output wire                                 axi_s_addr_ready,
        input  wire [C_AXI_SF_DATA_WIDTH-1 : 0]     axi_s_wr_data,
        input  wire                                 axi_s_wr_valid,
        output wire                                 axi_s_wr_ready,
        output reg  [C_AXI_SF_DATA_WIDTH-1 : 0]     axi_s_rd_data,
        output wire                                 axi_s_rd_valid,
        input  wire                                 axi_s_rd_ready,
        
        // from/to lookup
        output wire                                 rwm_busy_flag,
        input  wire                                 ctrl_busy_flag,
        input  wire [C_TAGLINE_DATA_WIDTH-1 : 0]    lut_ib_tag,                                     // tag addr 
        input  wire                                 lut_hit,                                        
        input  wire                                 lut_dirty,                                      
        output wire [2+C_AXI_ADDR_WIDTH-1 : 0]      lut_wr_tag_line,
        output wire                                 lut_wr_tag_line_en,        
        
        // to int. buffer
        output wire [C_AXI_ADDR_WIDTH-1 : 0]        ib_addr,
        output reg  [C_AXI_SF_DATA_WIDTH-1 : 0]     ib_wr_data,
        output wire                                 ib_wr_en,
        input  wire [C_AXI_SF_DATA_WIDTH-1 : 0]     ib_rd_data,        
                    
        // to AXI master    
        output wire [C_AXI_ADDR_WIDTH-1 : 0]        axi_m_addr,
        output reg                                  axi_m_addr_valid,
        input  wire                                 axi_m_addr_ready,
        output wire [C_AXI_MF_DATA_WIDTH-1 : 0]     axi_m_wr_data,
        output wire                                 axi_m_wr_valid,
        output wire [C_AXI_MF_DATA_WIDTH/8-1 : 0]   axi_m_wr_strb,
        input  wire                                 axi_m_wr_ready,
        input  wire [C_AXI_MF_DATA_WIDTH-1 : 0]     axi_m_rd_data,
        input  wire                                 axi_m_rd_valid,
        output wire                                 axi_m_rd_ready
        
        
    );
    
    //-------------------------------
    // constants
    //-------------------------------
    
    // AXI handling FSM states
    localparam S0_AXI_IDLE          = 2'b00;             // init signals & wait for request
    localparam S1_AXI_SEND_REQ      = 2'b01;             // send axi master req
    localparam S2_AXI_WAIT_TR_END   = 2'b10;             // wait end of transaction

    //counter's part in the address = index
    localparam CNT_PART_MSB = C_IDX_OFFS+C_SF_ADDR_LSB-1;
    
    //RW FSM states
    localparam S0_IDLE                  = 5'd0;
    localparam S1_REQ                   = 5'd1;
    localparam S2_WT__WR_HIT            = 5'd2;
    localparam S3_WT__WR_MISS           = 5'd3;
    localparam S4_WT__RD_HIT            = 5'd4;
    localparam S5_WT__RD_MISS_LOAD      = 5'd5;
    localparam S6_WT__RD_MISS_STORE     = 5'd6;
    localparam S10_WB__WR_HIT           = 5'd10;
    localparam S11_WB__RD_HIT           = 5'd11;
    localparam S12_WB__MISS_LOAD_EXT    = 5'd12;
    localparam S13_WB__MISS_STORE_IB    = 5'd13;
    localparam S14_WB__DIRTY_LOAD_IB    = 5'd14;
    localparam S15_WB__DIRTY_STORE_EXT  = 5'd15;
    
    //-------------------------------
    // regs and wires
    //-------------------------------
    reg                                 wr_tag_dirty = 0;
    reg                                 wr_tag_line_en_i;
                                    
    reg  [1:0]                          axi_m_addr_fsm;
    reg  [1:0]                          axi_m_wr_fsm;
    wire                                master_rd_done;
    wire                                master_wr_done;
    
    reg                                 axi_s_addr_ready_i;
    reg                                 axi_s_rd_valid_i;
    reg                                 axi_s_wr_ready_i;
    reg                                 axi_m_wr_valid_i;
    reg                                 axi_m_rd_ready_i;
    wire [C_AXI_MF_DATA_WIDTH/8-1 : 0]  axi_m_wr_strb_i_one;
    reg  [C_AXI_MF_DATA_WIDTH/8-1 : 0]  axi_m_wr_strb_i_sel;
    reg                                 rwm_wr_en_i;
                                        
    reg  [C_AXI_SF_DATA_WIDTH-1 : 0]    req_wdata;
    reg  [C_AXI_ADDR_WIDTH-1 : 0]       req_addr;
    reg                                 req_is_wr;
    reg  [C_TAGLINE_DATA_WIDTH-1 : 0]   prev_tag;
    
    reg  [C_CACHELINE_DATA_WIDTH-1:0 ]  cacheline;
    reg  [C_CACHELINE_DATA_WIDTH-1:0 ]  next_cacheline;
    wire [C_CACHELINE_DATA_WIDTH-1:0 ]  next_cacheline_load_ext;
    wire [C_CACHELINE_DATA_WIDTH-1:0 ]  next_cacheline_load_ib;
    wire [C_CACHELINE_DATA_WIDTH-1:0 ]  next_cacheline_store_ext;
    wire [C_CACHELINE_DATA_WIDTH-1:0 ]  next_cacheline_store_ib;
    wire [31:0 ]                        test_cacheline [C_CACHELINE_DATA_WIDTH/32-1:0]; 
    
    reg                                 busy_flag;
    reg  [4:0]                          rw_state;
    reg  [4:0]                          next_rw_state;
    
    reg  [7:0]                          cnt;
    reg  [7:0]                          next_cnt;
    wire [7:0]                          axi_addr_cnt_part;
    


    // generate busy flag for internal use and for lookup table control module
    //////////////////////////////////////////////////////////////////////////
    // readwrite busy flag to outer modules
    assign rwm_busy_flag = busy_flag;
    
    // generate busy flag to lookup ctrl module
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            busy_flag <= 1'b0;     
        end else begin
            busy_flag <= (next_rw_state != S0_IDLE);
        end
    end 

    //--------------------------------------
    // axi slave if handling
    //--------------------------------------
    assign axi_s_addr_ready = axi_s_addr_ready_i;
    assign axi_s_rd_valid   = axi_s_rd_valid_i;
    assign axi_s_wr_ready   = axi_s_wr_ready_i;
    
    // generate ready signals
    always @(*) begin
        axi_s_addr_ready_i   <= !busy_flag & !ctrl_busy_flag;
        axi_s_wr_ready_i     <= !busy_flag & !ctrl_busy_flag;
    end  
    
   /*generate
        if (C_CL_MF_RATIO > 1) begin
//            assign axi_addr_cnt_part[CNT_PART_MSB-C_SF_ADDR_LSB: 0] = 
//                        req_addr[CNT_PART_MSB:C_SF_ADDR_LSB];
            assign axi_addr_cnt_part = req_addr[CNT_PART_MSB:C_SF_ADDR_LSB];
        end 
        if (C_CL_MF_RATIO == 1) begin
            //no counter needed on MF side
            assign axi_addr_cnt_part = 0;
        end
    endgenerate*/
    
    assign axi_addr_cnt_part = req_addr[CNT_PART_MSB:C_SF_ADDR_LSB];
    
    // generate read data + valid signal
    always @(posedge clk) begin
        if (reset) begin
            axi_s_rd_data       <= 'b0; 
            axi_s_rd_valid_i    <= 'b0;
        end else begin
            if (rw_state == S4_WT__RD_HIT) begin
                // when reading from int. buffer
                axi_s_rd_data       <= ib_rd_data; 
                axi_s_rd_valid_i    <= 'b1;
            end else if ((rw_state == S6_WT__RD_MISS_STORE || 
                          rw_state == S13_WB__MISS_STORE_IB  ) && req_is_wr == 0 && cnt == axi_addr_cnt_part) begin  
                //reading from ext mem
                axi_s_rd_data       <= cacheline[C_AXI_SF_DATA_WIDTH-1:0];
                axi_s_rd_valid_i    <= 'b1;
            end else if (rw_state == S11_WB__RD_HIT) begin
                // when reading from int. buffer
                axi_s_rd_data       <= ib_rd_data; 
                axi_s_rd_valid_i    <= 'b1;
            end else if (axi_s_rd_ready == 1'b1) begin    
                axi_s_rd_valid_i    <= 1'b0;
            end
        end
    end

    //store addr + data 
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            req_addr        <= 'b0;
            req_wdata       <= 'b0;
            req_is_wr       <= 'b0;
        end else begin
            if ( axi_s_addr_valid  & ~busy_flag) begin          // save lookup address
                req_addr    <= axi_s_addr;
                req_is_wr   <= axi_s_wr_valid;
            end
            if ( axi_s_wr_valid & ~busy_flag ) begin            // save write data        
                req_wdata   <= axi_s_wr_data;   
            end
        end
    end

    //store address tag info coming from the LUT
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            prev_tag <= 'h0;
        end else begin
            if (rw_state == S1_REQ) begin
                prev_tag <= lut_ib_tag;
            end
        end
    end    
    //--------------------------------------
    // lookup if handling
    //--------------------------------------
    generate
        if (C_CL_SF_RATIO > 1) begin
            //MUX the address going to the IB, incase accessing multiple IB locations in the state
            // the counter needs to be included, otherwise use the incoming addr directly
            assign ib_addr = (  rw_state == S6_WT__RD_MISS_STORE    || 
                                rw_state == S13_WB__MISS_STORE_IB   || 
                                rw_state == S14_WB__DIRTY_LOAD_IB     ) ? 
                        {req_addr[C_AXI_ADDR_WIDTH-1:CNT_PART_MSB+1], cnt[CNT_PART_MSB-C_SF_ADDR_LSB:0], {C_SF_ADDR_LSB{1'b0}} } :
                        req_addr ;
        end 
        if (C_CL_SF_RATIO == 1) begin
            //no counter needed on IB side
            assign ib_addr = 
                        {req_addr[C_AXI_ADDR_WIDTH-1:C_SF_ADDR_LSB], 
                        {C_SF_ADDR_LSB{1'b0}} } ;
        end
    endgenerate


    
    assign ib_wr_en    = rwm_wr_en_i;
    //always write VALID=1, since clear only happens at CTRL FSM when doing flush/invalidate
    //when wr_en is 0, then use the lut_wr_tag_line as the address that needs a lookup check.
    assign lut_wr_tag_line = wr_tag_line_en_i ? {wr_tag_dirty, 1'b1, req_addr} : {2'b0,axi_s_addr};
    assign lut_wr_tag_line_en = wr_tag_line_en_i;
  
    // generating int. buffer wr_En wr_data and status flag update signals
    // buffer write
    always @(*) begin
        if (rw_state == S2_WT__WR_HIT ) begin
            //write data from AXI SF to IB, no flag update
            ib_wr_data          <= req_wdata; 
            rwm_wr_en_i         <= 'h1;
            wr_tag_line_en_i    <= 'h0;
            wr_tag_dirty        <= 'h0;                   
        end else if (rw_state == S6_WT__RD_MISS_STORE || rw_state == S13_WB__MISS_STORE_IB ) begin
            //write data from AXI MF, now in cacheline temp to IB, update flags
            ib_wr_data          <= cacheline[C_AXI_SF_DATA_WIDTH-1:0]; 
            rwm_wr_en_i         <= 'b1;
            //write tagline at the end of the state
            //xxx uncomment prev version, if this timing fails here
             wr_tag_line_en_i    <= 'b1;
            //wr_tag_line_en_i    <= (rw_state != next_rw_state );
            wr_tag_dirty        <= 'h0;                   
        end else if (rw_state == S10_WB__WR_HIT ) begin
             //write data from AXI SF to IB, update flags
            ib_wr_data          <= req_wdata; 
            rwm_wr_en_i         <= 'b1;
            //write tagline at the end of the state
            //xxx uncomment prev version, if this timing fails here
             wr_tag_line_en_i    <= 'b1;
            //wr_tag_line_en_i    <= (rw_state != next_rw_state );
            wr_tag_dirty        <= 'h1;                   
        end else begin
            ib_wr_data          <= 'h0;
            rwm_wr_en_i         <= 'h0;
            wr_tag_line_en_i    <= 'h0; 
            wr_tag_dirty        <= 'h0;                   
        end
    end
    
    //-------------------------------
    // axi master if handling
    //-------------------------------

    //write data is normally coming from the cacheline temp reg, 
    //only for WR_THROUGH use incoming SF data directly
    assign axi_m_wr_data   = (C_WR_STRATEGY == "WR_THROUGH" ) ? 
                                {C_MF_SF_RATIO{req_wdata}} : 
                                cacheline[C_AXI_MF_DATA_WIDTH-1:0]; 

    generate
        if (C_CL_MF_RATIO > 1) begin
            //address calculation...
            //if WR_BACK and dirty                  >> use prev location and the counter
            //if WR_BACK and loading from ext mem   >> use SF address and the counter
            //normally                              >> use SF address directly
            assign axi_m_addr      = 
                        (next_rw_state == S15_WB__DIRTY_STORE_EXT) ? 
                            
                            {   prev_tag, req_addr[C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1:CNT_PART_MSB+1], 
                                    cnt[CNT_PART_MSB-C_MF_ADDR_LSB:0],{C_MF_ADDR_LSB{1'b0}}  } :
                        
                        (next_rw_state == S5_WT__RD_MISS_LOAD   || 
                         next_rw_state == S12_WB__MISS_LOAD_EXT)    ? 
                        
                            {   req_addr[C_AXI_ADDR_WIDTH-1:CNT_PART_MSB+1], 
                                    cnt[CNT_PART_MSB-C_MF_ADDR_LSB:0], {C_MF_ADDR_LSB{1'b0}}} :
                                    
                            {   req_addr[C_AXI_ADDR_WIDTH-1:C_MF_ADDR_LSB], {C_MF_ADDR_LSB{1'b0}}} ; 
        end
        if (C_CL_MF_RATIO == 1) begin
            //no counter needed on MF side
            assign axi_m_addr      = 
                        (next_rw_state == S15_WB__DIRTY_STORE_EXT) ? 
                            
                            {   prev_tag, req_addr[C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1:C_MF_ADDR_LSB], 
                                    {C_MF_ADDR_LSB{1'b0}}  } :
                            {   req_addr[C_AXI_ADDR_WIDTH-1:C_MF_ADDR_LSB], {C_MF_ADDR_LSB{1'b0}}} ; 
            
        end
    endgenerate
    
    assign axi_m_rd_ready  = axi_m_rd_ready_i; 
    assign axi_m_wr_valid  = axi_m_wr_valid_i; 
    
    //select between strobes generated 
    assign axi_m_wr_strb   = 
                ( C_WR_STRATEGY == "WR_THROUGH" && C_AXI_MF_DATA_WIDTH != C_AXI_SF_DATA_WIDTH ) ? 
                    axi_m_wr_strb_i_sel : 
                    axi_m_wr_strb_i_one;
    
    //wr strobe is always 1..1 for all bytes
    assign axi_m_wr_strb_i_one   =  {(C_AXI_MF_DATA_WIDTH/8){1'b1}};
    
    //wr strobe is only 1..1 for a single AXI SF beat in WR_THROUGH when DW is different
    generate
        integer i, j;
        if (C_AXI_MF_DATA_WIDTH != C_AXI_SF_DATA_WIDTH ) begin
            always @* begin
                for (i=0; i < C_MF_SF_RATIO; i= i+1) begin
                    for (j=0; j < C_AXI_SF_DATA_WIDTH/8; j = j+1 ) begin
                        axi_m_wr_strb_i_sel[j+i*(C_AXI_SF_DATA_WIDTH/8)] =
                            { {(axi_addr_cnt_part[C_MF_ADDR_LSB-C_SF_ADDR_LSB-1:0] == i) }};
                    end
                end
            end
        end
    
    endgenerate
    
    assign master_rd_done = axi_m_rd_valid & axi_m_rd_ready_i;
    assign master_wr_done = (axi_m_wr_fsm == S2_AXI_WAIT_TR_END );
    
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            axi_m_addr_valid   <= 'b0;
            axi_m_wr_valid_i   <= 'b0;
            axi_m_rd_ready_i   <= 'b0;
            axi_m_addr_fsm     <= S0_AXI_IDLE;
            axi_m_wr_fsm       <= S0_AXI_IDLE;
        end else begin
            //------------------------------------
            // handle addr req
            //------------------------------------
            case (axi_m_addr_fsm) 
            S1_AXI_SEND_REQ: begin
                if (axi_m_addr_ready == 1'b1) begin
                    axi_m_addr_valid    <= 1'b0;            
                    axi_m_addr_fsm      <= S2_AXI_WAIT_TR_END;
                end     
            end
            S2_AXI_WAIT_TR_END: begin
                //write or read req end
                
//xxx add here the exception states here whenever there are more than 1 AXI M transfers to be done                
// needed if the MF is waiting a pre-defined length burst
/*
                if ((   master_wr_done  && 
                        (rw_state == S15_WB__DIRTY_STORE_EXT ) ) ||
                    (   master_rd_done && 
                        (rw_state == S5_WT__RD_MISS_LOAD ||
                         rw_state == S12_WB__MISS_LOAD_EXT    )      )
                   )    
*/
               if ( master_wr_done  || master_rd_done ) begin
                    //wait for other FSM to finish
                    axi_m_addr_fsm      <= S0_AXI_IDLE; 
                    //xxx it can be accelerated here if there is a new pending req (burst)
                    //  then dont go to IDLE
                end

            end
            default: begin
                //when cnt is needed, then use the registered state variable, since cnt maybe non-zero
                // when next state is already changed...
                if  ( next_rw_state == S2_WT__WR_HIT                                       || 
                      next_rw_state == S3_WT__WR_MISS                                      ||
                     (rw_state == S5_WT__RD_MISS_LOAD      && cnt < (C_CL_MF_RATIO))  ||
                     (rw_state == S12_WB__MISS_LOAD_EXT    && cnt < (C_CL_MF_RATIO))  ||
                     (rw_state == S15_WB__DIRTY_STORE_EXT  && cnt < (C_CL_MF_RATIO))     )
                begin
                    //start MF transfer
                    axi_m_addr_valid    <= 1'b1;                       
                    axi_m_addr_fsm      <= S1_AXI_SEND_REQ;  
                end else begin
                    //transfer done
                    axi_m_addr_valid    <= 1'b0;              
                end
            end
            endcase 
            //------------------------------------
            // handle write data req 
            //------------------------------------
            case (axi_m_wr_fsm)
            S1_AXI_SEND_REQ: begin
                if (axi_m_wr_ready == 1'b1) begin
                    axi_m_wr_valid_i   <= 1'b0;            
                    axi_m_wr_fsm       <= S2_AXI_WAIT_TR_END;
                end     
            end
            S2_AXI_WAIT_TR_END: begin
                if  (axi_m_addr_fsm == S2_AXI_WAIT_TR_END) begin
                    //wait for other FSM to finish
                    axi_m_wr_fsm      <= S0_AXI_IDLE; 
                    //xxx it can be accelerated here if there is a new pending req (burst)
                end
            end
            default: begin
                //see comment at m_addr_fsm
                if  (   next_rw_state == S2_WT__WR_HIT              || 
                        next_rw_state == S3_WT__WR_MISS             || 
                        rw_state == S15_WB__DIRTY_STORE_EXT        ) 
                begin                           
                    //start MF transfer
                    axi_m_wr_valid_i  <= 1'b1;                       
                    axi_m_wr_fsm      <= S1_AXI_SEND_REQ;  
                end else begin
                    //transfer done
                    axi_m_wr_valid_i      <= 1'b0;              
                end
            end
            
            endcase   
            //------------------------------------
            // handle read data   
            //------------------------------------
            if (axi_m_rd_valid == 1'b1) begin  
                axi_m_rd_ready_i   <= 1'b1;                                                
            end
            else begin
                axi_m_rd_ready_i   <= 1'b0;
            end        
        end
    end 
 

    //----------------------------------------
    // RW FSM - FF
    //----------------------------------------
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            rw_state    <= S0_IDLE;
            cnt         <= 'h0;
            cacheline   <= 'h0;
        end else begin
            rw_state    <= next_rw_state;
            cnt         <= next_cnt;
            cacheline   <= next_cacheline;
        end
    end 
    
    //----------------------------------------
    // RW FSM - comb.
    //----------------------------------------
    always @* begin
        //default: keep prev value
        next_rw_state   <= rw_state;
        next_cnt        <= cnt;
        next_cacheline  <= cacheline;
        
        case (rw_state) 
            S0_IDLE: begin
                    if (axi_s_addr_valid && axi_s_addr_ready_i) begin
                        //valid incoming request
                        next_rw_state <= S1_REQ;
                    end
                end
            S1_REQ: begin
                    next_cnt    <= 0;
                    if (C_WR_STRATEGY == "WR_BACK" ) begin
                        if (req_is_wr) begin
                            //write
                            if (lut_hit) begin
                                //write hit
                                next_rw_state <= S10_WB__WR_HIT;
                            end else begin
                                if (lut_dirty) begin
                                    //write miss and dirty
                                    next_rw_state <= S14_WB__DIRTY_LOAD_IB;
                                end else begin
                                    //write miss, not dirty
                                    next_rw_state <= S12_WB__MISS_LOAD_EXT; 
                                end
                            end
                        end else begin
                            //read
                            if (lut_hit) begin
                                //read hit
                                next_rw_state <= S11_WB__RD_HIT;
                            end else begin
                                if (lut_dirty) begin
                                    //read miss and dirty
                                    next_rw_state <= S14_WB__DIRTY_LOAD_IB;
                                end else begin
                                    //read miss, not dirty
                                    next_rw_state <= S12_WB__MISS_LOAD_EXT;
                                end
                            end
                        end
                    end
                    if (C_WR_STRATEGY == "WR_THROUGH" ) begin
                        if (req_is_wr) begin
                            if (lut_hit) begin
                                //write hit
                                next_rw_state <= S2_WT__WR_HIT;
                            end else begin
                                //write miss
                                next_rw_state <= S3_WT__WR_MISS;
                            end
                        end else begin
                            if (lut_hit) begin
                                //read hit
                                next_rw_state <= S4_WT__RD_HIT;
                            end else begin
                                //read miss
                                next_rw_state <= S5_WT__RD_MISS_LOAD;
                            end
                        end
                    end
                end
            //----------------------------
            // WR_THROUGH
            //----------------------------
            S2_WT__WR_HIT:begin
                    //write to ext mem also in case of WR_THROUGH
                    //so wait until AXI MF finishes
                    if ((axi_m_wr_valid_i == 1'b1) && (axi_m_wr_ready == 1'b1)) begin
                        next_rw_state   <= S0_IDLE;
                    end
                    //we need strobing here, 
                    //since only AXI SF wide data will be written to AXI MF
                end
            S3_WT__WR_MISS: begin
                    //write to ext mem also in case of WR_THROUGH
                    //so wait until AXI MF finishes
                    if ((axi_m_wr_valid_i == 1'b1) && (axi_m_wr_ready == 1'b1)) begin
                        next_rw_state   <= S0_IDLE;
                    end
                    //we need strobing here, 
                    //since only AXI SF wide data will be written to AXI MF
                end
            S4_WT__RD_HIT: begin
                    //simply read from the cache 
                    //this takes a single cycle.
                    next_rw_state   <= S0_IDLE;
                end
            S5_WT__RD_MISS_LOAD: begin
                    //miss part 1, so read from ext mem first
                    // this may take several cycles - depends on MASTER dw 
                    if (master_rd_done) begin
                        if (cnt == C_CL_MF_RATIO - 1 ) begin
                            //finished reading from ext mem
                            next_rw_state   <= S6_WT__RD_MISS_STORE;
                            next_cnt        <= 0;
                        end else begin
                            //still to go, continue reading
                            next_cnt        <= cnt + 1;
                        end
                        //store read data in cacheline temp reg 
                        next_cacheline <= next_cacheline_load_ext;
                    end
                end
            S6_WT__RD_MISS_STORE: begin
                    //miss part 2, store whole cacheline in IB
                    // this may take several cycles - depends on SLAVE dw
                    if (cnt == C_CL_SF_RATIO - 1 ) begin
                        //finished reading from ext mem
                        next_rw_state   <= S0_IDLE;
                        next_cnt        <= 0;
                    end else begin
                        //still to go, continue reading
                        next_cnt        <= cnt + 1;
                        //rotate
                        next_cacheline <= next_cacheline_store_ib;
                    end
                end
            //----------------------------
            // WR_BACK
            //----------------------------
            S10_WB__WR_HIT: begin
                    //simply write to the cache 
                    //this takes a single cycle.
                    next_rw_state   <= S0_IDLE;
                end
            S11_WB__RD_HIT: begin
                    //simply read from the cache 
                    //this takes a single cycle.
                    next_rw_state   <= S0_IDLE;
                end
            S12_WB__MISS_LOAD_EXT: begin
                    //rd/wr miss part1: read whole cacheline from ext mem
                    //first load to tmp cacheline  
                    // this may take several cycles - depends on MASTER dw 
                    if (master_rd_done) begin
                        if (cnt == C_CL_MF_RATIO - 1 ) begin
                            //finished reading from ext mem
                            next_rw_state   <= S13_WB__MISS_STORE_IB;
                            next_cnt        <= 0;
                        end else begin
                            //still to go, continue reading
                            next_cnt        <= cnt + 1;
                        end
                        //store read data in cacheline temp reg 
                        next_cacheline <= next_cacheline_load_ext;
                    end
                end
            S13_WB__MISS_STORE_IB: begin
                    //rd/wr miss part2, store whole cacheline in IB
                    // this may take several cycles - depends on SLAVE dw
                    if (cnt == C_CL_SF_RATIO - 1 ) begin
                        //finished writing to IB
                        if (req_is_wr) begin
                            //write path
                            next_rw_state   <= S10_WB__WR_HIT;
                        end else begin
                            //read path
                            next_rw_state   <= S0_IDLE;
                        end
                        next_cnt        <= 0;
                    end else begin
                        //still to go, continue reading
                        next_cnt        <= cnt + 1;
                    end
                    //rotate
                    next_cacheline <= next_cacheline_store_ib;
                end
            S14_WB__DIRTY_LOAD_IB: begin
                    //dirty part 1, load prev value from IB to cacheline
                    // this may take several cycles - depends on SLAVE dw
                    // doing +1 cycle, so that we can delay read out to address generation
                    if (cnt == C_CL_SF_RATIO - 1 +1) begin
                        //finished reading from IB
                        next_rw_state   <= S15_WB__DIRTY_STORE_EXT;
                        next_cnt        <= 0;
                    end else begin
                        //still to go, continue reading
                        next_cnt            <= cnt + 1;
                    end
                    //rotate
                    if (cnt != 0) begin
                        //shifting is delayed 1 cycle compared to address generation
                        next_cacheline <= next_cacheline_load_ib;
                    end
                end
             S15_WB__DIRTY_STORE_EXT: begin
                    //dirty part2, copy to ext mem
                    // this may take several cycles - depends on MASTER dw 
                    if (master_wr_done) begin
                        if (cnt == C_CL_MF_RATIO - 1 ) begin
                            //finished writing to ext mem, continue to load from ext mem
                            next_rw_state   <= S12_WB__MISS_LOAD_EXT;
                            next_cnt        <= 0;
                        end else begin
                            //still to go, continue reading
                            next_cnt        <= cnt + 1;
                        end
                        //store read data in cacheline temp reg 
                        next_cacheline <= next_cacheline_store_ext;
                    end
                end
            default: next_rw_state   <= S0_IDLE;
        endcase
    end

    //cacheline alignments depending on the Data widths... must be a generate
    generate
        if (C_CL_MF_RATIO > 1) begin
            //shift in several steps, if CL longer than MF
            assign next_cacheline_load_ext   = {axi_m_rd_data, cacheline[C_CACHELINE_DATA_WIDTH-1:C_AXI_MF_DATA_WIDTH]};
            // circulal shift (rotate) the cacheline temp reg 
            // data to be written to EXT MEM is on the LSB side
            assign next_cacheline_store_ext  = {cacheline[C_AXI_MF_DATA_WIDTH-1:0],cacheline[C_CACHELINE_DATA_WIDTH-1:C_AXI_MF_DATA_WIDTH]};
        end else begin
            //same size
            assign next_cacheline_load_ext   = axi_m_rd_data;
            //keep prev cacheline value
            assign next_cacheline_store_ext  = cacheline;
        end
        if (C_CL_SF_RATIO > 1) begin
            // circulal shift (rotate) the cacheline temp reg 
            // data to be written to IB is on the LSB side
            assign next_cacheline_store_ib  = {cacheline[C_AXI_SF_DATA_WIDTH-1:0],cacheline[C_CACHELINE_DATA_WIDTH-1:C_AXI_SF_DATA_WIDTH]};
            //shift in several steps, if CL longer than SF
            assign next_cacheline_load_ib = {ib_rd_data, cacheline[C_CACHELINE_DATA_WIDTH-1:C_AXI_SF_DATA_WIDTH]};
        end else begin
            //keep prev cacheline value
            assign next_cacheline_store_ib  = cacheline;
            //same size
            assign next_cacheline_load_ib = ib_rd_data;
        end
    endgenerate

    //for easing simulation: break down cacheline to list of bytes
    genvar test_i;
    generate begin: g_init_data_reg
        for(test_i=0;  test_i < C_CACHELINE_DATA_WIDTH/32 ; test_i = test_i + 1) begin: g_test_cacheline
            //generate an array from the long bit vector
            assign test_cacheline[test_i] = cacheline[(test_i+1)*32-1:test_i*32];
        end
    end
    endgenerate    
      
endmodule
