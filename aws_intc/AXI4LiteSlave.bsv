/*
 *  Implementation of the AXI 4 Lite Slave Interface
 *
 *  Channel: Source -> Target (Prefix)
 *  -----------------------------------
 *  Write address channel:  M -> S (aw)
 *  Write data channel:     M -> S (w)
 *  Write response channel: S -> M (b)
 *  Read address channel:   M -> S (ar)
 *  Read data channel:      S -> M (r)
 */

package AXI4LiteSlave;

import AXI4LiteTypes :: *; 
import AXI4LiteMaster :: *;

import Connectable :: *;
import ClientServer :: *;
import FIFOF :: *;
import GetPut :: *;


// -------------------------------
// AXI4 Lite Slave / Read channels
// -------------------------------


(* always_ready, always_enabled *)
interface AXI4_Lite_Slave_Rd_Fab#(numeric type addrw, numeric type dataw);
    // Read address channel
    method Bool arready();
    (* prefix = "" *)
    method Action m_arvalid(Bool arvalid);
    (* prefix = "" *)
    method Action m_archan(Bit#(addrw) araddr, AXI4_Lite_Prot arprot); 

    // Read data channel
    method Bool rvalid();
    (* prefix = "" *)
    method Action m_rready(Bool rready);
    method Bit#(dataw) rdata();
    method AXI4_Lite_Resp rresp();
endinterface: AXI4_Lite_Slave_Rd_Fab


interface AXI4_Lite_Slave_Rd#(numeric type addrw, numeric type dataw);
    (* prefix = "" *)
    interface AXI4_Lite_Slave_Rd_Fab#(addrw, dataw) fab;
    interface Client#(AXI4_Lite_Rq_Rd#(addrw), AXI4_Lite_Rsp_Rd#(dataw)) bus;
endinterface: AXI4_Lite_Slave_Rd


module mkAXI4_Lite_Slave_Rd#(Integer bufsz)(AXI4_Lite_Slave_Rd#(addrw, dataw));
    FIFOF#(AXI4_Lite_Rq_Rd#(addrw)) req_fifo <- mkSizedFIFOF(bufsz);
    FIFOF#(AXI4_Lite_Rsp_Rd#(dataw)) resp_fifo <- mkSizedFIFOF(bufsz);

    Wire#(Bool) arvalid_signal <- mkWire(); // must be a wire
    Wire#(AXI4_Lite_Rq_Rd#(addrw)) addr_read_data <- mkWire();

    Wire#(Bool) rready_signal <- mkWire(); // must be a wire
    Wire#(AXI4_Lite_Rsp_Rd#(dataw)) data_read_resp <- mkDWire(?);

    rule wire_to_request (req_fifo.notFull() && arvalid_signal);
        req_fifo.enq(addr_read_data);
    endrule

    // TODO: combine the following two rules?
    rule read_response_to_wire;
        data_read_resp <= resp_fifo.first();
    endrule

    rule read_resp_fifo_deq (resp_fifo.notEmpty() && rready_signal);
        resp_fifo.deq();
    endrule

    interface AXI4_Lite_Slave_Rd_Fab fab;
        // Read address channel
        interface arready = req_fifo.notFull;

        interface m_arvalid = arvalid_signal._write(); 

        method Action m_archan(Bit#(addrw) araddr, AXI4_Lite_Prot arprot);
            AXI4_Lite_Rq_Rd#(addrw) req;
            req.addr = araddr;
            req.prot = arprot;
            addr_read_data <= req;
        endmethod       

        // Read data channel
        interface rvalid = resp_fifo.notEmpty;

        method Action m_rready(Bool rready);
            rready_signal <= rready;
        endmethod

        interface rdata = data_read_resp.data;
        interface rresp = data_read_resp.resp;

    endinterface: fab


    interface Client bus;
        interface Get request = toGet(req_fifo);
        interface Put response = toPut(resp_fifo);
    endinterface: bus

endmodule: mkAXI4_Lite_Slave_Rd


// --------------------------------
// AXI4 Lite Slave / Write channels
// --------------------------------


(* always_ready, always_enabled *)
interface AXI4_Lite_Slave_Wr_Fab#(numeric type addrw, numeric type dataw);

    // Write address channel
    method Bool awready();      
    (* prefix = "" *)
    method Action m_awvalid(Bool awvalid);
    (* prefix = "" *)
    method Action m_awchan(Bit#(addrw) awaddr, AXI4_Lite_Prot awprot);

    // Write data channel
    method Bool wready();
    (* prefix = "" *)
    method Action m_wvalid(Bool wvalid);
    (* prefix = "" *)
    method Action m_wchan(Bit#(dataw) wdata, Bit#(TDiv#(dataw, 8)) wstrb);

    // Write response channel
    method Bool bvalid();
    (* prefix = "" *)
    method Action m_bready(Bool bready);
    method AXI4_Lite_Resp bresp();

endinterface: AXI4_Lite_Slave_Wr_Fab


interface AXI4_Lite_Slave_Wr#(numeric type addrw, numeric type dataw);
    interface AXI4_Lite_Slave_Wr_Fab#(addrw, dataw) fab;
    interface Client#(AXI4_Lite_Rq_Wr#(addrw, dataw), AXI4_Lite_Rsp_Wr) bus;
endinterface: AXI4_Lite_Slave_Wr


module mkAXI4_Lite_Slave_Wr#(Integer bufsz)(AXI4_Lite_Slave_Wr#(addrw, dataw));
    // TODO: optimize: BypassFIFOF?
    FIFOF#(AXI4_Lite_Rq_Wr#(addrw, dataw)) write_fifo <- mkSizedFIFOF(bufsz); 
    FIFOF#(AXI4_Lite_Rsp_Wr) write_resp_fifo <- mkSizedFIFOF(bufsz);

    Wire#(Bool) awvalid_signal <- mkWire();
    Wire#(Bool) wvalid_signal <- mkWire();

    Wire#(Bool) bready_signal <- mkWire();
    Wire#(AXI4_Lite_Rsp_Wr) bresp_data <- mkDWire(?);

    FIFOF#(Bit#(addrw)) addr_buffer <- mkFIFOF(); 
    FIFOF#(AXI4_Lite_Prot) prot_buffer <- mkFIFOF();
    FIFOF#(Bit#(dataw)) data_buffer <- mkFIFOF();
    FIFOF#(Bit#(TDiv#(dataw, 8))) strb_buffer <- mkFIFOF();

    Wire#(Bit#(addrw)) addr_wire <- mkWire();
    Wire#(AXI4_Lite_Prot) prot_wire <- mkWire();
    Wire#(Bit#(dataw)) data_wire <- mkWire();
    Wire#(Bit#(TDiv#(dataw, 8))) strb_wire <- mkWire();

    rule addr_and_prot_wire_to_buffer
    (addr_buffer.notFull && prot_buffer.notFull && awvalid_signal);

        addr_buffer.enq(addr_wire);
        prot_buffer.enq(prot_wire);
    endrule

    rule data_and_strb_wire_to_buffer
    (data_buffer.notFull && strb_buffer.notFull && wvalid_signal);

        data_buffer.enq(data_wire);
        strb_buffer.enq(strb_wire);
    endrule

    rule buffers_to_request
    /*(addr_buffer.notEmpty && prot_buffer.notEmpty && 
     data_buffer.notEmpty && strb_buffer.notEmpty)*/;

        AXI4_Lite_Rq_Wr#(addrw, dataw) req;
        req.addr = addr_buffer.first();
        req.prot = prot_buffer.first();
        req.data = data_buffer.first();
        req.strb = strb_buffer.first();
        write_fifo.enq(req);

        addr_buffer.deq();
        prot_buffer.deq();
        data_buffer.deq();
        strb_buffer.deq();
    endrule

    rule write_response_to_wire;
        bresp_data <= write_resp_fifo.first();
    endrule

    rule remove_write_response
    (write_resp_fifo.notEmpty && bready_signal);

        write_resp_fifo.deq();
    endrule
    
    interface AXI4_Lite_Slave_Wr_Fab fab;
        // Write address channel
        interface awready = (addr_buffer.notFull && prot_buffer.notFull);

        method Action m_awvalid(Bool awvalid);
            awvalid_signal <= awvalid;
        endmethod 

        method Action m_awchan(Bit#(addrw) awaddr, AXI4_Lite_Prot awprot);
            addr_wire <= awaddr;
            prot_wire <= awprot;
        endmethod

        // Write data channel
        interface wready = (data_buffer.notFull && strb_buffer.notFull);

        method Action m_wvalid(Bool wvalid);
            wvalid_signal <= wvalid;
        endmethod

        method Action m_wchan(Bit#(dataw) wdata, Bit#(TDiv#(dataw, 8)) wstrb);
            data_wire <= wdata;
            strb_wire <= wstrb;
        endmethod

        // Write response channel
        interface bvalid = write_resp_fifo.notEmpty;
        interface m_bready = bready_signal._write();
        interface AXI4_Lite_Resp bresp = bresp_data.resp;

    endinterface: fab   

    interface Client bus;
        interface Get request = toGet(write_fifo);
        interface Put response = toPut(write_resp_fifo);
    endinterface: bus

endmodule: mkAXI4_Lite_Slave_Wr


instance Connectable#(AXI4_Lite_Master_Rd_Fab#(addrw, dataw),
        AXI4_Lite_Slave_Rd_Fab#(addrw, dataw));

    module mkConnection#(AXI4_Lite_Master_Rd_Fab#(addrw, dataw) m,
        AXI4_Lite_Slave_Rd_Fab#(addrw, dataw) s)();

        rule connect1; m.m_arready(s.arready);          endrule
        rule connect2; s.m_arvalid(m.arvalid);          endrule
        rule connect3; s.m_archan (m.araddr, m.arprot); endrule
        rule connect4; m.m_rvalid (s.rvalid);           endrule
        rule connect5; s.m_rready (m.rready);           endrule
        rule connect6; m.m_rchan  (s.rdata, s.rresp);   endrule
    endmodule
endinstance: Connectable


instance Connectable#(AXI4_Lite_Master_Wr_Fab#(addrw, dataw),
        AXI4_Lite_Slave_Wr_Fab#(addrw, dataw));

    module mkConnection#(AXI4_Lite_Master_Wr_Fab#(addrw, dataw) m,
        AXI4_Lite_Slave_Wr_Fab#(addrw, dataw) s)();

        rule connect1; m.m_awready(s.awready);          endrule
        rule connect2; s.m_awvalid(m.awvalid);          endrule
        rule connect3; s.m_awchan (m.awaddr, m.awprot); endrule
        rule connect4; m.m_wready (s.wready);           endrule
        rule connect5; s.m_wvalid (m.wvalid);           endrule
        rule connect6; s.m_wchan  (m.wdata, m.wstrb);   endrule
        rule connect7; m.m_bvalid (s.bvalid);           endrule
        rule connect8; s.m_bready (m.bready);           endrule
        rule connect9; m.m_bresp  (s.bresp);            endrule
    endmodule
endinstance: Connectable


endpackage: AXI4LiteSlave
