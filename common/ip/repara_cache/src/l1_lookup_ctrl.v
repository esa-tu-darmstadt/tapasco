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

    module l1_lookup_ctrl #
    (
        // Width of input address bus
        parameter integer C_AXI_ADDR_WIDTH          = 32,
        // Width of lite data
        parameter integer C_AXI_SL_DATA_WIDTH       = 32,
        // Width of axi slave data bus 
        parameter integer C_AXI_SF_DATA_WIDTH       = 32,
        // Width of axi master data bus 
        parameter integer C_AXI_MF_DATA_WIDTH       = 32,

        // Width of tagline 
        parameter integer C_TAGLINE_DATA_WIDTH      = 32,        
        // Width of tag buffer's address bus
        parameter integer C_TAGLINE_ADDR_WIDTH      = 8,
        // number of lines in the internal buffer
        parameter integer C_TAG_DEPTH               = 64,
        // Width of cacheline 
        parameter integer C_CACHELINE_DATA_WIDTH    = 32,
        // Width of internal buffer's address bus
        parameter integer C_CACHELINE_ADDR_WIDTH    = 8,

        // Ratio of AXI master & slave data width
        parameter integer MF_SF_RATIO               = 8,
        // Ratio of Cache line & AXI slave data width
        parameter integer CL_SF_RATIO               = 8,
        // Don't case bits in AXI address        
        parameter integer OFFS                      = 8,
        // Cache data address index offset part         
        parameter integer IDX_OFFS                  = 8,
        // number of lines of valid flags to be ored
        parameter integer C_VALID_FLAG_CHECK_NUM    = 64,
        // Write strategy: "WR_THROUGH", "WR_BACK"    
        parameter C_WR_STRATEGY                     = "WR_THROUGH"         
    )
    (
        // Global Clock Signal
        input wire                                  clk,
        // Global Reset Signal
        input wire                                  reset,
        
        // from/to AXI Full slave, handshaking signals
        input  wire                                 rwm_busy_flag,
        output wire                                 ctrl_busy_flag,
        
        // single bit interface
        input  wire                                 invalidate_all,
        input  wire                                 flush_all,
        output wire                                 module_busy,
                
        // from config & status registers
        // lookup control signals
        input wire                                  conf_invalidate,
        input wire                                  conf_flush,
        input wire  [C_AXI_ADDR_WIDTH-1 : 0]        conf_addr_start,
        input wire  [C_AXI_SL_DATA_WIDTH-1 : 0]     conf_erase_num,
        output wire [C_AXI_SL_DATA_WIDTH-1 : 0]     conf_ctrl_status,                               // same length as configuration address

        // from/to lookup_table
        output reg                                  delete_whole_table,                             // when invalidate all -> reset tag table  
        output reg  [2+C_AXI_ADDR_WIDTH-1 : 0]      wr_tag_line,                                    // whole line: dirty & valid & x bit AXI addr
        output reg                                  wr_tag_line_en,     
        input  wire [C_TAGLINE_DATA_WIDTH+1 : 0]    rd_tag_line,                                    // whole line: dirty & valid & x bit AXI addr
        input  wire                                 rd_tag_flush_valid_sign,           

        input  wire                                 lut_hit,                                        // hit: AXI addr is store; wr_en signal when write to hit
        input  wire                                 lut_dirty,                                      // dirty: the data line has been modified in int. buf.
        input  wire [C_TAGLINE_DATA_WIDTH-1 : 0]    lut_ib_tag,                                     // tag: tag value in tag table
        
        // to internal buffer
        output wire                                 lookup_sel, 
        output wire [C_CACHELINE_ADDR_WIDTH-1 : 0]  ib_rd_addr,               
        input  wire [C_AXI_SF_DATA_WIDTH-1 : 0]     ib_rd_data,
        
        // to AXI master
        output reg  [C_AXI_ADDR_WIDTH-1 : 0]        axi_m_addr_data,
        output wire [7 : 0]                         axi_m_addr_burstlen,
        output wire                                 axi_m_addr_valid,
        input  wire                                 axi_m_addr_ready,
        output wire [C_AXI_MF_DATA_WIDTH-1 : 0]     axi_m_wr_data,
        output wire                                 axi_m_wr_valid,
        input  wire                                 axi_m_wr_ready
    );
    
	// function called clogb2 that returns an integer which has the 
    // value of the ceiling of the log base 2.                      
    function integer clogb2 (input integer bit_depth);              
    begin                                                           
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
            bit_depth = bit_depth >> 1;                                 
    end
    endfunction       

    localparam integer CL_MF_RATIO  = C_CACHELINE_DATA_WIDTH/C_AXI_MF_DATA_WIDTH;
    localparam integer MS_OFFS      = clogb2(MF_SF_RATIO)-1;                                        // because ratio is power of 2
    localparam integer MS_FILL_MSB  = (MF_SF_RATIO == 1) ? 1 : MS_OFFS;                             // because ratio is power of 2
    localparam integer CLS_FILL_MSB = (CL_SF_RATIO == 1) ? 1 : IDX_OFFS;                            // because ratio is power of 2
    
    // FSM states
    localparam IDLE             = 4'h0;             // init signals & wait for request
    localparam COMM_END_CHECK   = 4'h1;             // del_cnt, erase_cnt check
    localparam INVFLUSH_CHECK   = 4'h2;             // check current tag line
    localparam FLUSH_ALL_CHECK  = 4'h3;          	// check current tag line 
    localparam INV_SINGLE		= 4'h4;          	// invalidate single line in table 
	localparam LOAD_TO_MS		= 4'h5;             // load burst beat size data to axi master
    localparam FLUSH_DATA		= 4'h6;             // flush data to mem
	localparam INV_ALL          = 4'h7;             // invalidate all -> reset tag table
    localparam WAIT_RW_FSM      = 4'h8;             // wait till rw fsm ends
    
    reg [3:0] lookup_ctrl_fsm;
    
    // WIRES & REGISTERS
    reg [C_AXI_SL_DATA_WIDTH-1 : 0]   ALLONE_PATTERN = {C_AXI_SL_DATA_WIDTH{1'b1}};
    reg [C_AXI_SL_DATA_WIDTH-1 : 0]   erase_num;
    reg [C_TAGLINE_ADDR_WIDTH-1 : 0]  del_all_tag_cnt;
    reg [C_TAGLINE_ADDR_WIDTH-1 : 0]  next_vblock_cnt;
    reg [C_AXI_ADDR_WIDTH-1 : 0]      axi_addr_inv_fl;  
    reg [1 : 0]                       lookup_type;
    reg                               lookup_sel_tmp;
    reg                               ctrl_busy_pending;
    reg                               incoming_req;    
    reg                               flush_all_ended;    
  
    reg [C_AXI_MF_DATA_WIDTH-1 : 0]    flush_data_reg;
    reg                                axi_m_addr_valid_reg;
    reg                                axi_m_wr_valid_reg;
    reg [C_AXI_MF_DATA_WIDTH-1 : 0]    axi_m_wr_data_reg;    
    reg                                axi_m_first_beat_reg;
    reg                                cl_end;
    reg [C_CACHELINE_ADDR_WIDTH-1 : 0] ib_rd_addr_reg;    
    reg [C_CACHELINE_ADDR_WIDTH-1 : 0] cl_addr_reg;    
    
    reg [MS_FILL_MSB-1 : 0]            m_s_fill_cnt;    
    reg [CLS_FILL_MSB-1 : 0]           cl_s_fill_cnt;
    reg [MS_FILL_MSB-1 : 0]            m_s_fill_cnt_delay;    
    reg [CLS_FILL_MSB-1 : 0]           cl_s_fill_cnt_delay;    
     
    wire [C_TAGLINE_ADDR_WIDTH-1 : 0]  inv_fl_single_idx;
    wire                               inv_tmp;
    wire                               flush_tmp;
    wire                               inv_all_tmp;
    wire                               flush_all_tmp;
   
    // status register: readable from AXI Lite slave
    assign conf_ctrl_status = {{(C_AXI_SL_DATA_WIDTH-10){1'b0}}, lut_dirty, lut_hit, 2'b00, (rwm_busy_flag | ctrl_busy_pending), lookup_sel_tmp, lookup_ctrl_fsm};
    
    assign module_busy = rwm_busy_flag | ctrl_busy_pending;
    
    assign inv_tmp   = (C_WR_STRATEGY == "WR_THROUGH" ) ? (conf_invalidate|conf_flush) : conf_invalidate;
    assign flush_tmp = (C_WR_STRATEGY == "WR_THROUGH" ) ? 1'b0                         : conf_flush;

    assign inv_all_tmp   = (C_WR_STRATEGY == "WR_THROUGH" ) ? (invalidate_all|flush_all) : invalidate_all;
    assign flush_all_tmp = (C_WR_STRATEGY == "WR_THROUGH" ) ? 1'b0                       : flush_all;
    
    assign ctrl_busy_flag       = ctrl_busy_pending;
    assign axi_m_addr_valid     = axi_m_addr_valid_reg;
    assign axi_m_addr_burstlen  = CL_MF_RATIO-1;
    assign axi_m_wr_valid       = axi_m_wr_valid_reg;
    assign axi_m_wr_data        = axi_m_wr_data_reg;
    assign ib_rd_addr           = ib_rd_addr_reg;
   
    // table select
    assign lookup_sel = lookup_sel_tmp; 
    
    // signs the current state of cacheline sending on AXI master
    assign inv_fl_single_idx = axi_addr_inv_fl[C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1 : IDX_OFFS+OFFS];
    
    // generate SF -> MF register
    generate
        if (MF_SF_RATIO == 1) begin
            always @(posedge clk) begin
                if (reset == 1'b1) begin
                    flush_data_reg <= 'h0;
                end
                else begin
                    flush_data_reg <= ib_rd_data; 
                end  
            end           
        end
        else begin
            always @(posedge clk) begin
                if (reset == 1'b1) begin
                    flush_data_reg <= 'h0;
                end
                else begin
                    flush_data_reg <= {ib_rd_data, flush_data_reg[C_AXI_MF_DATA_WIDTH-1 : C_AXI_SF_DATA_WIDTH]}; 
                end  
            end          
        end
    endgenerate
   
    // lookup table control state machine
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            lookup_ctrl_fsm     <= IDLE;
            delete_whole_table  <= 1'b0;
            wr_tag_line         <= 'h0;    
            wr_tag_line_en      <= 1'b0; 
            lookup_sel_tmp      <= 1'b1;
            ctrl_busy_pending   <= 1'b0;
            axi_m_wr_data_reg   <= 'h0;                
            axi_m_addr_data     <= 'h0;                
            axi_m_wr_valid_reg  <= 1'b0;  
            axi_m_addr_valid_reg<= 1'b0;  
            axi_m_first_beat_reg<= 1'b0;  
            cl_end              <= 1'b0;  
            ib_rd_addr_reg      <= 'h0;
            cl_addr_reg         <= 'h0;
            axi_addr_inv_fl     <= 'h0;  
            del_all_tag_cnt     <= 'h0;    
            next_vblock_cnt     <= 'h0;       
            erase_num           <= 'h0;              
            lookup_type         <= 2'b00;                
            incoming_req        <= 1'b0;                
            flush_all_ended     <= 1'b0;                
        end
        else begin
            m_s_fill_cnt        <= ib_rd_addr_reg[MS_FILL_MSB-1  : 0];
            cl_s_fill_cnt       <= ib_rd_addr_reg[CLS_FILL_MSB-1 : 0];
            m_s_fill_cnt_delay  <= m_s_fill_cnt;
            cl_s_fill_cnt_delay <= cl_s_fill_cnt;
        
            case(lookup_ctrl_fsm)
            COMM_END_CHECK: begin
                incoming_req         <= 1'b0;
                wr_tag_line_en       <= 1'b0; 
                axi_m_first_beat_reg <= 1'b1;

				if ((lookup_type == 2'b10) && (flush_all_ended == 1'b1)) begin                      // flush all has finished
					ctrl_busy_pending <= 1'b0;
					ib_rd_addr_reg    <= 'h0;
                    lookup_sel_tmp    <= 1'b0;					
					lookup_ctrl_fsm   <= IDLE;  
				end				
                else if ((lookup_type != 2'b10) && (del_all_tag_cnt == erase_num)) begin            // flush has finished with given number of erase
                    ctrl_busy_pending <= 1'b0;
                    ib_rd_addr_reg    <= 'h0;
                    lookup_sel_tmp    <= 1'b0;
                    lookup_ctrl_fsm   <= IDLE;
                end
                else begin                                                                     
                    ib_rd_addr_reg <= ib_rd_addr_reg + 1;
                    cl_addr_reg    <= ib_rd_addr_reg;
					
					if (lookup_type == 2'b10) begin
						lookup_ctrl_fsm <= FLUSH_ALL_CHECK;
					end
					else begin
						lookup_ctrl_fsm <= INVFLUSH_CHECK;
					end
                end    			
            end    
            INVFLUSH_CHECK: begin                                                                      
                del_all_tag_cnt <= del_all_tag_cnt + 1;   
                axi_addr_inv_fl <= axi_addr_inv_fl + {1'b1, {IDX_OFFS+OFFS{1'b0}}};                 // increment to next cache line address
                
                if (lut_hit == 1'b1) begin                                                          // invalidate line #n when hit
                    wr_tag_line    <= {{(2+C_TAGLINE_DATA_WIDTH){1'b0}}, inv_fl_single_idx, {IDX_OFFS+OFFS{1'b0}}};
                    wr_tag_line_en <= 1'b1;    
                end
                // not using lut_dirty because we're not making any lookups
                // just reading the table lines directly
                if (lut_hit == 1'b0) begin                                                          // when not hit 
                    ib_rd_addr_reg  <= {ib_rd_addr_reg[C_CACHELINE_ADDR_WIDTH-1 : IDX_OFFS] + 1, {IDX_OFFS{1'b0}}}; // jump to nex cache line data
                    wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= axi_addr_inv_fl + {1'b1, {IDX_OFFS+OFFS{1'b0}}};         // req. read tag line #n+1
				    lookup_ctrl_fsm <= COMM_END_CHECK;
                end
				else if ((lut_dirty == 1'b0) || (lookup_type == 2'b00)) begin                       // when not dirty OR invalidating
                    ib_rd_addr_reg  <= {ib_rd_addr_reg[C_CACHELINE_ADDR_WIDTH-1 : IDX_OFFS] + 1, {IDX_OFFS{1'b0}}}; // jump to nex cache line data
				    lookup_ctrl_fsm <= INV_SINGLE;
                end
                else begin                                                                          // flushing dirty line
                    axi_m_addr_data <= {lut_ib_tag, cl_addr_reg, {OFFS{1'b0}}};                     // load flush addr to AXI Master registers
                             
                    if (CL_SF_RATIO == 1) begin
                        cl_end <= 1'b1;
                    end    
                                      
                    if (MF_SF_RATIO == 1) begin                                                     // when master data port is filled up; data width of SF = MF
                        axi_m_addr_valid_reg <= 1'b1;
                        axi_m_wr_valid_reg   <= 1'b1;
                        axi_m_wr_data_reg    <= flush_data_reg;
                        lookup_ctrl_fsm      <= FLUSH_DATA;
                    end
                    else begin                                                                      // else, fill master port with slave size data
                        ib_rd_addr_reg  <= ib_rd_addr_reg + 1; 
                        lookup_ctrl_fsm <= LOAD_TO_MS;
                    end
                end
            end    
			FLUSH_ALL_CHECK: begin 
			    // check if flush all has ended
			    if ((rd_tag_flush_valid_sign == 1'b0) && (del_all_tag_cnt > C_TAG_DEPTH-C_VALID_FLAG_CHECK_NUM-1)) begin
			         flush_all_ended <= 1'b1;   
                end
                else if (del_all_tag_cnt == C_TAG_DEPTH-1) begin
			         flush_all_ended <= 1'b1;                  
                end
				// next valid block starting address generator
                if  (del_all_tag_cnt == next_vblock_cnt) begin
                    next_vblock_cnt <= next_vblock_cnt + C_VALID_FLAG_CHECK_NUM;
                end                 
                // not using lut_dirty because we're not making any lookups
                // just reading the table lines directly
                if (rd_tag_flush_valid_sign == 1'b0) begin                                          // if there isn't any valid line in current block
                    ib_rd_addr_reg <= {next_vblock_cnt, {(C_CACHELINE_ADDR_WIDTH-C_TAGLINE_ADDR_WIDTH){1'b0}}};     // jump to nex cache line data
                    del_all_tag_cnt <= next_vblock_cnt;                                             // increment tag pointer to next block
                    wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= {{(C_TAGLINE_DATA_WIDTH){1'b0}}, next_vblock_cnt, {IDX_OFFS+OFFS{1'b0}}};    // req. read tag line #n+1
					lookup_ctrl_fsm <= COMM_END_CHECK;                  
                end
                else if (rd_tag_line[C_TAGLINE_DATA_WIDTH+1] == 1'b0) begin                         // when dirty bit = 0
                    ib_rd_addr_reg  <= {ib_rd_addr_reg[C_CACHELINE_ADDR_WIDTH-1 : IDX_OFFS] + 1, {IDX_OFFS{1'b0}}}; // jump to nex cache line
                    del_all_tag_cnt <= del_all_tag_cnt + 1;                                                         // increment tag pointer  
                    wr_tag_line_en  <= 1'b1;
	                wr_tag_line     <= {{(2+C_TAGLINE_DATA_WIDTH){1'b0}}, del_all_tag_cnt, {IDX_OFFS+OFFS{1'b0}}};  // invalidate line #n
					lookup_ctrl_fsm <= INV_SINGLE;                  
                end
                else begin                                                                          // flushing dirty line
                    axi_m_addr_data <= {(rd_tag_line[C_TAGLINE_DATA_WIDTH-1 : 0]), cl_addr_reg, {OFFS{1'b0}}};      // load flush addr to AXI Master registers
                    del_all_tag_cnt <= del_all_tag_cnt + 1;                                                         // increment tag pointer  
	                wr_tag_line     <= {{(2+C_TAGLINE_DATA_WIDTH){1'b0}}, del_all_tag_cnt, {IDX_OFFS+OFFS{1'b0}}};  // invalidate line #n
                    wr_tag_line_en  <= 1'b1;
	
                    if (CL_SF_RATIO == 1) begin
                        cl_end <= 1'b1;
                    end                            
                
                    if (MF_SF_RATIO == 1) begin                                                     // when master data port is filled up; data width of SF = MF
                        axi_m_addr_valid_reg <= 1'b1;
                        axi_m_wr_valid_reg   <= 1'b1;
                        axi_m_wr_data_reg    <= flush_data_reg;
                        lookup_ctrl_fsm      <= FLUSH_DATA;
                    end
                    else begin                                                                      // else, fill master port with slave size data
                        ib_rd_addr_reg  <= ib_rd_addr_reg + 1; 
                        lookup_ctrl_fsm <= LOAD_TO_MS;
                    end
                end
            end    			
			INV_SINGLE: begin
                wr_tag_line_en <= 1'b0;
		
				if (lookup_type == 2'b10) begin
					wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= {{(C_TAGLINE_DATA_WIDTH){1'b0}}, del_all_tag_cnt, {IDX_OFFS+OFFS{1'b0}}};    // req. read tag line #n+1
				end
				else begin
                    wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= axi_addr_inv_fl;                         // req. read tag line #n+1
				end
				
				lookup_ctrl_fsm  <= COMM_END_CHECK;    			
			end			
            LOAD_TO_MS: begin                                                                       // read cache line #n from int. buffer  
                wr_tag_line_en <= 1'b0;                 

                if (CL_SF_RATIO-1 == cl_s_fill_cnt_delay) begin
                    cl_end <= 1'b1;  
                end
                            
                if (MF_SF_RATIO-1 == m_s_fill_cnt_delay) begin                                      // when master data port is filled up; data width of SF != MF
                    ib_rd_addr_reg     <= ib_rd_addr_reg - 1;                                       // set pointer to previous because of 2 clock delay in read data  
                    axi_m_wr_valid_reg <= 1'b1;
                    axi_m_wr_data_reg  <= flush_data_reg;
                                  
                    if (axi_m_first_beat_reg == 1'b1) begin                                                   
                        axi_m_first_beat_reg <= 1'b0;
                        axi_m_addr_valid_reg <= 1'b1;                    
                    end
 
                    lookup_ctrl_fsm <= FLUSH_DATA;
                end
                else begin
                    ib_rd_addr_reg <= ib_rd_addr_reg + 1; 
                end
            end
            FLUSH_DATA: begin                                                                       // handling axi master valid & ready
                wr_tag_line_en <= 1'b0;   
                 
                if (axi_m_addr_ready == 1'b1) begin
                    axi_m_addr_valid_reg <= 1'b0; 
                end         

                if (((CL_SF_RATIO == 1) || ( cl_end == 1'b1)) && (axi_m_wr_ready == 1'b1)) begin    // when AXI master has accepted and this was the last beat
                    cl_end             <= 1'b0;
                    axi_m_wr_valid_reg <= 1'b0; 
					
					if (lookup_type == 2'b10) begin
						wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= {{(C_TAGLINE_DATA_WIDTH){1'b0}}, del_all_tag_cnt, {IDX_OFFS+OFFS{1'b0}}};
					end
				    else begin
						wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= axi_addr_inv_fl;
					end
					
                    lookup_ctrl_fsm <= COMM_END_CHECK;
                end 
                else if (axi_m_wr_ready == 1'b1) begin                                              // when AXI master has accepted and this is an intermediate beat
                    axi_m_wr_valid_reg <= 1'b0; 
                    lookup_ctrl_fsm    <= LOAD_TO_MS;
                end  
            end            
			INV_ALL: begin
                incoming_req       <= 1'b0;
                delete_whole_table <= 1'b0; 
                ctrl_busy_pending  <= 1'b0;
                lookup_sel_tmp     <= 1'b0;
                lookup_ctrl_fsm    <= IDLE;  
            end              
            WAIT_RW_FSM: begin
                // store first incoming request while RWM is working                
                if (incoming_req == 1'b0) begin
                    axi_addr_inv_fl <= conf_addr_start;
                    
                    if ((inv_all_tmp == 1'b1) || (flush_all_tmp == 1'b1)) begin
                        erase_num <= ALLONE_PATTERN;    
                    end
                    else begin
                        erase_num <= conf_erase_num;    
                    end
                    // configuration type save logic
                    if ((inv_all_tmp == 1'b1) || (inv_tmp == 1'b1)) begin
                        lookup_type <= 2'b00;
                    end
                    else if ((flush_tmp == 1'b1) && (conf_erase_num != ALLONE_PATTERN)) begin       // when conf flush = 1
                        lookup_type <= 2'b01;                
                    end                  
                    else begin                                                                      // when flush all
                        lookup_type <= 2'b10;                
                    end
                    // incoming request process logic
                    if ((inv_all_tmp == 1'b1) || (flush_all_tmp == 1'b1) || (inv_tmp == 1'b1) || (flush_tmp == 1'b1)) begin 
                        incoming_req      <= 1'b1;
                        ctrl_busy_pending <= 1'b1;
                    end
                    else begin
                        ctrl_busy_pending <= 1'b0;
                    end  
                end
                // when RWM has finished step to the correct state
                if (rwm_busy_flag == 1'b0) begin
                    if (ctrl_busy_pending == 1'b1) begin
                        lookup_sel_tmp <= 1'b1;
                         
                        if ((lookup_type == 2'b00) && (erase_num == ALLONE_PATTERN)) begin          // when ALL invalidate occurs
                            delete_whole_table <= 1'b1; 
                            lookup_ctrl_fsm    <= INV_ALL;
                        end
                        else if (lookup_type == 2'b10) begin                                        // when ALL flush occurs
                            wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= 'h0;
                            ib_rd_addr_reg                      <= 'h0;
							lookup_ctrl_fsm                     <= COMM_END_CHECK;
                        end
                        else begin                                                                  // when SINGLE invalidate/flush occurs
                            wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= axi_addr_inv_fl;
							ib_rd_addr_reg                      <= conf_addr_start[(C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1) : OFFS];
                            lookup_ctrl_fsm                     <= COMM_END_CHECK;
                        end   
                    end                    
                    else begin
                        lookup_sel_tmp  <= 1'b0;
                        lookup_ctrl_fsm <= IDLE;                
                    end
                end                 
            end 
            default: begin                                                                          // idle state; waiting new start request
                wr_tag_line_en       <= 1'b0;  
                axi_m_addr_valid_reg <= 1'b0;  
                axi_m_wr_valid_reg   <= 1'b0;  
                del_all_tag_cnt      <= 'h0;
                axi_m_first_beat_reg <= 1'b0;
                next_vblock_cnt      <= C_VALID_FLAG_CHECK_NUM;    
                flush_all_ended      <= 1'b0;   
                
                // configuration type save logic
                if (ctrl_busy_pending == 1'b1) begin
                    lookup_type <= lookup_type;   
                end                 
                else if ((inv_all_tmp == 1'b1) || (inv_tmp == 1'b1)) begin
                    lookup_type <= 2'b00;
                end
                else if ((conf_flush == 1'b1) && (conf_erase_num != ALLONE_PATTERN)) begin          // when conf flush = 1
                    lookup_type <= 2'b01;                
                end                  
                else begin                                                                          // when flush all
                    lookup_type <= 2'b10;                
                end 
                // incoming request process logic
                if (ctrl_busy_pending == 1'b1) begin                                                // if we catched at the rwm busy end the req
                    lookup_ctrl_fsm <= WAIT_RW_FSM;                                                 // go back to wait rwm state to see if rwm is still busy
                end
                else if ((inv_all_tmp == 1'b1) || ((inv_tmp == 1'b1) && (conf_erase_num == ALLONE_PATTERN))) begin
                    delete_whole_table <= 1'b1; 
                    ctrl_busy_pending  <= 1'b1;                    
                    lookup_sel_tmp     <= 1'b1;
                    lookup_ctrl_fsm    <= INV_ALL;                                                  // when ALL invalidate occurs
                end
                else if ((flush_all_tmp == 1'b1) || ((flush_tmp == 1'b1) && (conf_erase_num == ALLONE_PATTERN))) begin  
                    axi_addr_inv_fl    <= conf_addr_start;
                    erase_num          <= conf_erase_num;
					wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= 'h0;
                    ib_rd_addr_reg     <= 'h0;
					ctrl_busy_pending  <= 1'b1;                    
                    lookup_sel_tmp     <= 1'b1;
                    lookup_ctrl_fsm    <= COMM_END_CHECK;                                            // when ALL flush occurs  
                end
                else if ((inv_tmp == 1'b1) || (flush_tmp == 1'b1)) begin 
                    axi_addr_inv_fl    <= conf_addr_start;
                    erase_num          <= conf_erase_num;
				    wr_tag_line[C_AXI_ADDR_WIDTH-1 : 0] <= conf_addr_start;
				    ib_rd_addr_reg     <= conf_addr_start[(C_AXI_ADDR_WIDTH-C_TAGLINE_DATA_WIDTH-1) : OFFS];
                    ctrl_busy_pending  <= 1'b1;                    
                    lookup_sel_tmp     <= 1'b1;                    
                    lookup_ctrl_fsm    <= COMM_END_CHECK;
                end
                else if (rwm_busy_flag == 1'b1) begin
                    ctrl_busy_pending  <= 1'b0;                    
                    lookup_sel_tmp     <= 1'b0;
                    lookup_ctrl_fsm    <= WAIT_RW_FSM;  
                end                     
                else begin
                    ctrl_busy_pending  <= 1'b0;                    
                    lookup_sel_tmp     <= 1'b0;
                    incoming_req       <= 1'b0;  
                end    
            end     
            endcase
        end
    end    

endmodule
