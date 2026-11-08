// PDILoader: Allow Programmable Logic to trigger the loading of PDIs from DDR.
//
// A PDI (for example an AI Engine only partial PDI) sits in DDR. On the PDILoad slave interface a
// requester hands over the physical address of that PDI as the PMC sees it; the loader then performs
// the Inter-Processor Interrupt (IPI) handshake with the PLM, the firmware on the PMC, over an AXI4
// master that must be connected to the CIPS S_AXI_LPD port. It is not reachable over the NoC. 
// XilLoader LOAD_SUBSYSTEM_PDI {0x030701, 0xF (DDR), addr_hi, addr_lo},
// ring IPI<n>.TRIG, wait for IPI<n>.OBS to clear, read the two response words. The PLM then does what
// it did for that image at boot: parse the PDI, run the CDOs, load the ELFs, release the cores.
//
// Parameters
//   IPI_CHANNEL     IPI channel 0, 1, 2, 3, 4, or 5 the requests are sent on (IPI6 and PMC_NOBUF have no message
//                   buffer; IPI5 is the PLM's xsdb master channel, which a JTAG session also uses).
//                   Other values are an elaboration error
//   TIMEOUT_CYCLES  clock cycles to wait for the PLM before giving up with error 3
//
// Interfaces
//   S_PDI_LOAD (PDILoad slave, see ../../PDILoad/PDILoad_rtl.xml)
//     start_valid/start_ready       request handshake; accepted only while idle
//     start_addr[63:0]              PMC physical address of the PDI (0x100_0000_0000 + DDR offset on the VCK5000)
//     finish_valid/finish_ready     exactly one finish per start, held until the requester takes it
//     finish_error[7:0]             0 = success, otherwise the error code below
//     finish_status[31:0]           PLMI status word of the response (0 = success)
//     finish_loader_status[31:0]    XilLoader status word of the response (decode with xloader.h of embeddedsw)
//   M_AXI_LPD (AXI4 master, 64 bit address, 32 bit data, single beat, AxPROT = AxCACHE = 0: verified on hardware)
//
// Error codes: 1 AXI write response != OKAY, 2 AXI read response != OKAY (the LPD is not reachable),
//   3 timeout (the PLM never acknowledged, usually a channel it is not servicing), 4 PLM reported a
//   non-zero PLMI status, 5 the channel still holds an unacknowledged earlier request.
//
// Sequence (every write waits for its response, so the ordering never depends on the interconnect):
//   step 0..3  write the request words into the channel's request slot
//   step 4     read word 0 back until it matches (proves the message RAM is reachable)
//   step 5     write a sentinel into the response slot
//   step 6     read OBS once: the PMC bit must be clear, otherwise an earlier request is still pending
//   step 7     write the PMC bit into TRIG
//   step 8     poll OBS until the PLM has cleared the PMC bit
//   step 9     poll response word 0 until the sentinel is gone (the PLM acks before it has finished the
//              load and writes the response only then)
//   step 10    read response word 1 (XilLoader status)
//
// Register facts (embeddedsw ipipsu driver, PLM xplmi_ipi.c, ATF plat_ipi.h):
//   IPI<n> regs  0xFF330000 + n*0x10000 : TRIG +0x0, OBS +0x4 (bit k of TRIG raises the interrupt at
//                agent k; bit k of OBS, read-only, stays set until agent k has cleared it in its ISR)
//   bit masks    PMC 0x2 ; buffer index PMC 1, IPI<n> 2+n
//   message RAM  0xFF3F0000 + src_idx*0x200 + dst_idx*0x40, response at +0x20
//   request  IPI<n>->PMC : 0xFF3F0000 + (2+n)*0x200 + 1*0x40   (slot "from n, to PMC")
//   response PMC->IPI<n> : the same slot + 0x20 (xipipsu_buf.c: the responder answers inside the
//                          requester's slot)

module PDILoader #(
    parameter integer IPI_CHANNEL    = 2,
    parameter integer TIMEOUT_CYCLES = 1073741824
) (
    input  wire        aclk,
    input  wire        aresetn,

    // PDILoad slave
    input  wire        S_PDI_LOAD_start_valid,
    output wire        S_PDI_LOAD_start_ready,
    input  wire [63:0] S_PDI_LOAD_start_addr,
    output wire        S_PDI_LOAD_finish_valid,
    input  wire        S_PDI_LOAD_finish_ready,
    output wire [7:0]  S_PDI_LOAD_finish_error,
    output wire [31:0] S_PDI_LOAD_finish_status,
    output wire [31:0] S_PDI_LOAD_finish_loader_status,

    // AXI4 master towards the LPD
    output wire [63:0] M_AXI_LPD_awaddr,
    output wire [7:0]  M_AXI_LPD_awlen,
    output wire [2:0]  M_AXI_LPD_awsize,
    output wire [1:0]  M_AXI_LPD_awburst,
    output wire        M_AXI_LPD_awlock,
    output wire [3:0]  M_AXI_LPD_awcache,
    output wire [2:0]  M_AXI_LPD_awprot,
    output wire [3:0]  M_AXI_LPD_awqos,
    output wire [3:0]  M_AXI_LPD_awregion,
    output wire        M_AXI_LPD_awvalid,
    input  wire        M_AXI_LPD_awready,
    output wire [31:0] M_AXI_LPD_wdata,
    output wire [3:0]  M_AXI_LPD_wstrb,
    output wire        M_AXI_LPD_wlast,
    output wire        M_AXI_LPD_wvalid,
    input  wire        M_AXI_LPD_wready,
    input  wire [1:0]  M_AXI_LPD_bresp,
    input  wire        M_AXI_LPD_bvalid,
    output wire        M_AXI_LPD_bready,
    output wire [63:0] M_AXI_LPD_araddr,
    output wire [7:0]  M_AXI_LPD_arlen,
    output wire [2:0]  M_AXI_LPD_arsize,
    output wire [1:0]  M_AXI_LPD_arburst,
    output wire        M_AXI_LPD_arlock,
    output wire [3:0]  M_AXI_LPD_arcache,
    output wire [2:0]  M_AXI_LPD_arprot,
    output wire [3:0]  M_AXI_LPD_arqos,
    output wire [3:0]  M_AXI_LPD_arregion,
    output wire        M_AXI_LPD_arvalid,
    input  wire        M_AXI_LPD_arready,
    input  wire [31:0] M_AXI_LPD_rdata,
    input  wire [1:0]  M_AXI_LPD_rresp,
    input  wire        M_AXI_LPD_rlast,
    input  wire        M_AXI_LPD_rvalid,
    output wire        M_AXI_LPD_rready
);
    // ---------------------------------------------------------------- IPI addresses
    if (IPI_CHANNEL < 0 || IPI_CHANNEL > 5) begin : bad_channel
        $error("PDILoader: IPI_CHANNEL must be 0..5 (IPI6 and PMC_NOBUF have no message buffer), got %0d", IPI_CHANNEL);
    end

    localparam logic [63:0] IPI_TRIG = 64'h00000000FF330000 + 64'(IPI_CHANNEL) * 64'h10000;
    localparam logic [63:0] IPI_OBS  = IPI_TRIG + 64'h4;
    localparam logic [63:0] REQ_BUF  = 64'h00000000FF3F0000 + 64'(2 + IPI_CHANNEL) * 64'h200 + 64'h40;
    localparam logic [63:0] RESP_BUF = REQ_BUF + 64'h20;

    localparam logic [31:0] CMD_LOAD_PDI = 32'h00030701;  // len 3, XilLoader (7), LOAD_SUBSYSTEM_PDI (1)
    localparam logic [31:0] PDI_SRC_DDR  = 32'h0000000F;
    localparam logic [31:0] SENTINEL     = 32'hDEADBEEF;
    localparam logic [31:0] PMC_MASK     = 32'h00000002;

    localparam logic [7:0] ERR_NONE = 0, ERR_WRITE_RESP = 1, ERR_READ_RESP = 2, ERR_TIMEOUT = 3,
                           ERR_PLM = 4, ERR_BUSY = 5;

    // ---------------------------------------------------------------- sequencer state
    typedef enum logic [2:0] {S_IDLE, S_WRITE, S_WRITE_WAIT, S_READ, S_READ_WAIT, S_DONE} state_t;
    state_t      state;
    logic [3:0]  step;
    logic [31:0] timer;
    logic [63:0] pdi_addr;
    logic [31:0] plmi_status, loader_status;
    logic [7:0]  err;

    // what the current step does
    logic        step_is_write;
    logic [63:0] step_addr;
    logic [31:0] step_wdata;
    always_comb begin
        step_is_write = 1'b0;
        step_addr     = RESP_BUF + 64'h4;
        step_wdata    = 32'h0;
        case (step)
            4'd0: begin step_is_write = 1'b1; step_addr = REQ_BUF;         step_wdata = CMD_LOAD_PDI;   end
            4'd1: begin step_is_write = 1'b1; step_addr = REQ_BUF + 64'h4; step_wdata = PDI_SRC_DDR;    end
            4'd2: begin step_is_write = 1'b1; step_addr = REQ_BUF + 64'h8; step_wdata = pdi_addr[63:32]; end
            4'd3: begin step_is_write = 1'b1; step_addr = REQ_BUF + 64'hC; step_wdata = pdi_addr[31:0];  end
            4'd4: begin                       step_addr = REQ_BUF;                                        end
            4'd5: begin step_is_write = 1'b1; step_addr = RESP_BUF;        step_wdata = SENTINEL;       end
            4'd6: begin                       step_addr = IPI_OBS;                                        end
            4'd7: begin step_is_write = 1'b1; step_addr = IPI_TRIG;        step_wdata = PMC_MASK;       end
            4'd8: begin                       step_addr = IPI_OBS;                                        end
            4'd9: begin                       step_addr = RESP_BUF;                                       end
            default: ;
        endcase
    end

    // ---------------------------------------------------------------- AXI master: single-beat transactions
    // AW and W are issued together and each held until accepted; the address and data are registered at
    // issue time so a transaction that is still pending after a timeout keeps its values.
    logic        aw_pending, w_pending, ar_pending;
    logic [63:0] aw_addr_q, ar_addr_q;
    logic [31:0] w_data_q;

    assign M_AXI_LPD_awaddr   = aw_addr_q;
    assign M_AXI_LPD_awlen    = 8'd0;        // 1 beat
    assign M_AXI_LPD_awsize   = 3'd2;        // 4 bytes
    assign M_AXI_LPD_awburst  = 2'b01;       // INCR
    assign M_AXI_LPD_awlock   = 1'b0;
    assign M_AXI_LPD_awcache  = 4'b0000;     // device
    assign M_AXI_LPD_awprot   = 3'b000;      // secure, unprivileged, data
    assign M_AXI_LPD_awqos    = 4'd0;
    assign M_AXI_LPD_awregion = 4'd0;
    assign M_AXI_LPD_awvalid  = aw_pending;
    assign M_AXI_LPD_wdata    = w_data_q;
    assign M_AXI_LPD_wstrb    = 4'b1111;
    assign M_AXI_LPD_wlast    = 1'b1;
    assign M_AXI_LPD_wvalid   = w_pending;
    assign M_AXI_LPD_bready   = 1'b1;        // a response is always taken (and ignored outside S_WRITE_WAIT)
    assign M_AXI_LPD_araddr   = ar_addr_q;
    assign M_AXI_LPD_arlen    = 8'd0;
    assign M_AXI_LPD_arsize   = 3'd2;
    assign M_AXI_LPD_arburst  = 2'b01;
    assign M_AXI_LPD_arlock   = 1'b0;
    assign M_AXI_LPD_arcache  = 4'b0000;
    assign M_AXI_LPD_arprot   = 3'b000;
    assign M_AXI_LPD_arqos    = 4'd0;
    assign M_AXI_LPD_arregion = 4'd0;
    assign M_AXI_LPD_arvalid  = ar_pending;
    assign M_AXI_LPD_rready   = 1'b1;

    wire may_write = !aw_pending && !w_pending;
    wire may_read  = !ar_pending;
    wire resp_error = M_AXI_LPD_bresp[1];    // SLVERR or DECERR
    wire read_error = M_AXI_LPD_rresp[1];

    // ---------------------------------------------------------------- PDILoad slave
    logic        finish_pending;
    logic [7:0]  finish_error;
    logic [31:0] finish_status, finish_loader_status;

    assign S_PDI_LOAD_start_ready          = (state == S_IDLE) && !finish_pending;
    assign S_PDI_LOAD_finish_valid         = finish_pending;
    assign S_PDI_LOAD_finish_error         = finish_error;
    assign S_PDI_LOAD_finish_status        = finish_status;
    assign S_PDI_LOAD_finish_loader_status = finish_loader_status;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state <= S_IDLE;
            step <= 4'd0;
            timer <= 32'd0;
            err <= ERR_NONE;
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            ar_pending <= 1'b0;
            finish_pending <= 1'b0;
        end else begin
            if (M_AXI_LPD_awvalid && M_AXI_LPD_awready) aw_pending <= 1'b0;
            if (M_AXI_LPD_wvalid  && M_AXI_LPD_wready)  w_pending  <= 1'b0;
            if (M_AXI_LPD_arvalid && M_AXI_LPD_arready) ar_pending <= 1'b0;
            if (finish_pending && S_PDI_LOAD_finish_ready) finish_pending <= 1'b0;

            case (state)
                S_IDLE: if (S_PDI_LOAD_start_valid && S_PDI_LOAD_start_ready) begin
                    pdi_addr <= S_PDI_LOAD_start_addr;
                    plmi_status <= 32'd0;
                    loader_status <= 32'd0;
                    timer <= 32'd0;
                    step <= 4'd0;
                    err <= ERR_NONE;
                    state <= S_WRITE;
                end

                S_WRITE: if (may_write) begin
                    aw_pending <= 1'b1;
                    aw_addr_q <= step_addr;
                    w_pending <= 1'b1;
                    w_data_q <= step_wdata;
                    state <= S_WRITE_WAIT;
                end

                S_WRITE_WAIT: if (M_AXI_LPD_bvalid) begin
                    if (resp_error) begin
                        err <= ERR_WRITE_RESP;
                        state <= S_DONE;
                    end else begin
                        step <= step + 4'd1;
                        state <= S_READ;    // S_READ re-dispatches to S_WRITE when the next step is a write
                    end
                end

                S_READ: if (step_is_write) begin
                    state <= S_WRITE;
                end else if (may_read) begin
                    ar_pending <= 1'b1;
                    ar_addr_q <= step_addr;
                    state <= S_READ_WAIT;
                end

                S_READ_WAIT: if (M_AXI_LPD_rvalid) begin
                    if (read_error) begin
                        err <= ERR_READ_RESP;
                        state <= S_DONE;
                    end else case (step)
                        4'd4: begin   // message RAM really reachable? re-read until our header shows up
                            if (M_AXI_LPD_rdata == CMD_LOAD_PDI) begin
                                step <= 4'd5;
                                state <= S_WRITE;
                            end else begin
                                state <= S_READ;
                            end
                        end
                        4'd6: begin   // stale request pending at the PMC? then the PLM is not servicing this channel
                            if (M_AXI_LPD_rdata[1]) begin
                                err <= ERR_BUSY;
                                state <= S_DONE;
                            end else begin
                                step <= 4'd7;
                                state <= S_WRITE;
                            end
                        end
                        4'd8: begin   // the PLM acks by clearing the PMC bit of our OBS register
                            if (!M_AXI_LPD_rdata[1]) step <= 4'd9;
                            state <= S_READ;
                        end
                        4'd9: begin   // response written? the sentinel is replaced by the PLMI status
                            if (M_AXI_LPD_rdata != SENTINEL) begin
                                plmi_status <= M_AXI_LPD_rdata;
                                step <= 4'd10;
                            end
                            state <= S_READ;
                        end
                        default: begin
                            loader_status <= M_AXI_LPD_rdata;
                            if (plmi_status != 32'd0) err <= ERR_PLM;
                            state <= S_DONE;
                        end
                    endcase
                end

                S_DONE: begin
                    finish_pending <= 1'b1;
                    finish_error <= err;
                    finish_status <= plmi_status;
                    finish_loader_status <= loader_status;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase

            // timeout only while something is in flight; it overrides the transitions above
            if (state != S_IDLE && state != S_DONE) begin
                if (timer == 32'(TIMEOUT_CYCLES)) begin
                    err <= ERR_TIMEOUT;
                    state <= S_DONE;
                end else begin
                    timer <= timer + 32'd1;
                end
            end
        end
    end

    // rlast is always 1 for single beats
    wire unused_rlast = M_AXI_LPD_rlast;
endmodule
