/*
 *  Implementation of the (full) AXI4 Master Interface
 *
 *  Channel: Source -> Target (Prefix)
 *  -----------------------------------
 *  Write address channel:  M -> S (aw)
 *  Write data channel:     M -> S (w)
 *  Write response channel: S -> M (b)
 *  Read address channel:   M -> S (ar)
 *  Read data channel:      S -> M (r)
 */

package AXI4Master;

import FIFOF :: *;
import GetPut :: *;

import AXI4Types :: *;


// ----------------------------------------
// AXI4 Master / Read address/data channels
// ----------------------------------------


(* always_ready, always_enabled *)
interface AXI4_Master_Rd_Fab#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);

    // Read address channel
    (* prefix = "" *)
    method Action m_arready(Bool arready);
    method Bool arvalid();
    
    method Bit#(idw) arid();
    method Bit#(addrw) araddr();
    method Bit#(4) arregion();
    method UInt#(8) arlen();
    method AXI4_Burst_Size arsize();
    method AXI4_Burst_Type arburst();
    method AXI4_Lock arlock();
    method AXI4_Rd_Cache arcache(); 
    method AXI4_Prot arprot();
    method Bit#(4) arqos();
    method Bit#(userw) aruser();

    // Read data channel
    (* prefix = "" *)
    method Action m_rvalid(Bool rvalid);
    method Bool rready();
    (* prefix = "" *)
    method Action m_rchan(
            Bit#(idw) rid,
            Bit#(dataw) rdata,
            AXI4_Resp rresp,
            Bit#(1) rlast,
            Bit#(userw) ruser
        );

endinterface: AXI4_Master_Rd_Fab


interface AXI4_Master_Rd#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);
    (* prefix = "" *)
    interface AXI4_Master_Rd_Fab#(addrw, dataw, idw, userw) fab;
    interface Put#(AXI4_Rq_Rd#(addrw, idw, userw)) req;
    interface Get#(AXI4_Rsp_Rd#(dataw, idw, userw)) resp;   
endinterface: AXI4_Master_Rd


module mkAXI4_Master_Rd#(Integer bufszin, Integer bufszout)
        (AXI4_Master_Rd#(addrw, dataw, idw, userw));

    // Read address channel
    FIFOF#(AXI4_Rq_Rd#(addrw, idw, userw)) req_fifo <- mkSizedFIFOF(bufszin);

    Wire#(Bool) arready_signal <- mkWire();
    Wire#(AXI4_Rq_Rd#(addrw, idw, userw)) addr_read_data <- mkDWire(?);

    // Read data channel
    Wire#(Bool) rvalid_signal <- mkWire();
    FIFOF#(AXI4_Rsp_Rd#(dataw, idw, userw)) resp_fifo <- mkSizedFIFOF(bufszout);
    Wire#(AXI4_Rsp_Rd#(dataw, idw, userw)) data_read_resp <- mkWire();

    // Rules: Read address channel
    rule request_to_wire;
        addr_read_data <= req_fifo.first();
        if (/*req_fifo.notEmpty() &&*/ arready_signal) begin
            req_fifo.deq();
        end
    endrule

    // Rules: Read data channel
    rule wire_to_response (resp_fifo.notFull() && rvalid_signal);
        resp_fifo.enq(data_read_resp);
    endrule

    // TODO: accept user signal here
    function Action rchan(Bit#(idw) rid, Bit#(dataw) rdata,
            AXI4_Resp rresp, Bit#(1) rlast, Bit#(userw) ruser);
        action 
            data_read_resp <= AXI4_Rsp_Rd
                { id : rid, data : rdata, resp : rresp, last : rlast, user : ruser};        
        endaction
    endfunction


    interface AXI4_Master_Rd_Fab fab;
        // Read address channel
        interface m_arready = arready_signal._write();
        interface arvalid = req_fifo.notEmpty;

        interface arid = addr_read_data.id;
        interface araddr = addr_read_data.addr;
        interface arregion = addr_read_data.region;
        interface arlen = addr_read_data.len;
        interface arsize = addr_read_data.size;
        interface arburst = addr_read_data.burst;
        interface arlock = addr_read_data.lock;
        interface arcache = addr_read_data.cache;
        interface arprot = addr_read_data.prot;
        interface arqos = addr_read_data.qos;
        interface aruser = addr_read_data.user;

        // Read data channel
        interface m_rvalid = rvalid_signal._write();
        interface rready = resp_fifo.notFull;

        interface m_rchan = rchan;
    endinterface: fab

    interface Put req = toPut(req_fifo);
    interface Get resp = toGet(resp_fifo);

endmodule: mkAXI4_Master_Rd


// --------------------------------------------------
// AXI4 Master / Write address/data/response channels
// --------------------------------------------------


(* always_ready, always_enabled *)
interface AXI4_Master_Wr_Fab#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);

    // Write address channel    
    (* prefix = "" *)
    method Action m_awready(Bool awready); 
    method Bool awvalid(); 
    
    method Bit#(addrw) awaddr(); // also used by axi 4 lite
    method AXI4_Prot awprot(); // also used by axi 4 lite
    method Bit#(idw) awid();
    method UInt#(8) awlen();
    method AXI4_Burst_Size awsize();
    method AXI4_Burst_Type awburst();
    method AXI4_Lock awlock();
    method AXI4_Wr_Cache awcache();
    method Bit#(4) awqos();
    method Bit#(4) awregion();  
    method Bit#(userw) awuser();

    // Write data channel
    (* prefix = "" *)
    method Action m_wready(Bool wready); 
    method Bool wvalid(); 

    method Bit#(dataw) wdata();
    method Bit#(TDiv#(dataw, 8)) wstrb();
    method Bit#(1) wlast();
    method Bit#(userw) wuser();

    // Write response channel
    (* prefix = "" *)
    method Action m_bvalid(Bool bvalid);
    method Bool bready(); 
    
    (* prefix = "" *)
    method Action m_bresp(AXI4_Resp bresp);
    (* prefix = "" *)
    method Action m_bid(Bit#(idw) bid);
    (* prefix = "" *)
    method Action m_buser(Bit#(userw) buser);

endinterface: AXI4_Master_Wr_Fab


interface AXI4_Master_Wr#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);
    interface AXI4_Master_Wr_Fab#(addrw, dataw, idw, userw) fab;
    interface Put#(AXI4_Addr_Rq_Wr#(addrw, idw, userw)) addr;
    interface Put#(AXI4_Data_Rq_Wr#(dataw, userw)) data;
    interface Get#(AXI4_Rsp_Wr#(idw, userw)) resp;
endinterface: AXI4_Master_Wr


module mkAXI4_Master_Wr#(Integer bufszinaddr, Integer bufszindata, Integer bufszout)
        (AXI4_Master_Wr#(addrw, dataw, idw, userw));

    // Write data channel
    Wire#(Bool) wready_signal <- mkWire(); 

    Wire#(AXI4_Data_Rq_Wr#(dataw, userw)) wr_data_wire <- mkDWire(?);
    FIFOF#(AXI4_Data_Rq_Wr#(dataw, userw)) wr_data_buffer <- mkSizedFIFOF(bufszindata);

    // Write address channel
    Wire#(Bool) awready_signal <- mkWire();

    Wire#(AXI4_Addr_Rq_Wr#(addrw, idw, userw)) wr_addr_wire <- mkDWire(?);
    FIFOF#(AXI4_Addr_Rq_Wr#(addrw, idw, userw)) wr_addr_buffer <- mkSizedFIFOF(bufszinaddr);

    // Write response channel
    FIFOF#(AXI4_Rsp_Wr#(idw, userw)) write_resp_fifo <- mkSizedFIFOF(bufszout);

    Wire#(Bool) bvalid_signal <- mkWire(); 

    Wire#(AXI4_Resp) resp_wire <- mkWire();
    Wire#(Bit#(idw)) bid_wire <- mkWire();
    Wire#(Bit#(userw)) buser_wire <- mkWire();

    // Rules: Write address channel
    rule write_addr_to_wire;
        wr_addr_wire <= wr_addr_buffer.first();
        if (awready_signal) begin
            wr_addr_buffer.deq();
        end
    endrule

    // Rules: Write data channel
    rule write_data_to_wire;
        wr_data_wire <= wr_data_buffer.first();
        if (wready_signal) begin
            wr_data_buffer.deq();
        end
    endrule

    // Rules: Write response channel
    rule resp_wire_to_buffer (write_resp_fifo.notFull && bvalid_signal);
        write_resp_fifo.enq(AXI4_Rsp_Wr
            { resp : resp_wire, id : bid_wire, user : buser_wire });
    endrule

    interface AXI4_Master_Wr_Fab fab;
        // Write address channel
        interface awvalid = wr_addr_buffer.notEmpty();
        interface m_awready = awready_signal._write();

        interface awid = wr_addr_wire.id;
        interface awaddr = wr_addr_wire.addr;
        interface awregion = wr_addr_wire.region;
        interface awlen = wr_addr_wire.len;
        interface awsize = wr_addr_wire.size;
        interface awburst = wr_addr_wire.burst;
        interface awlock = wr_addr_wire.lock;
        interface awcache = wr_addr_wire.cache;
        interface awprot = wr_addr_wire.prot;
        interface awqos = wr_addr_wire.qos;
        interface awuser = wr_addr_wire.user;

        // Write data channel
        interface wvalid = wr_data_buffer.notEmpty();
        interface m_wready = wready_signal._write();

        interface wdata = wr_data_wire.data;
        interface wstrb = wr_data_wire.strb;
        interface wlast = wr_data_wire.last;
        interface wuser = wr_data_wire.user;

        // Write response channel
        interface bready = write_resp_fifo.notFull;
        interface m_bvalid = bvalid_signal._write();

        interface m_bresp = resp_wire._write();
        interface m_bid = bid_wire._write();
        interface m_buser = buser_wire._write();
    endinterface: fab   

    interface Put addr = toPut(wr_addr_buffer);
    interface Put data = toPut(wr_data_buffer);
    interface Get resp = toGet(write_resp_fifo);

endmodule: mkAXI4_Master_Wr


endpackage: AXI4Master
