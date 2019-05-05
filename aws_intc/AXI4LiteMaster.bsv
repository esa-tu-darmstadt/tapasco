/*
 *  Implementation of the AXI 4 Lite Master Interface
 *
 *  Channel: Source -> Target (Prefix)
 *  -----------------------------------
 *  Write address channel:  M -> S (aw)
 *  Write data channel:     M -> S (w)
 *  Write response channel: S -> M (b)
 *  Read address channel:   M -> S (ar)
 *  Read data channel:      S -> M (r)
 */

package AXI4LiteMaster;

import ClientServer :: *;
import FIFOF :: *;
import GetPut :: *;

import AXI4LiteTypes :: *;


// --------------------------------
// AXI4 Lite Master / Read channels
// --------------------------------


(* always_ready, always_enabled *)
interface AXI4_Lite_Master_Rd_Fab#(numeric type addrw, numeric type dataw);

    // read address channel

    (* prefix = "" *)
    method Action m_arready(Bool arready);
    method Bool arvalid();
    
    method Bit#(addrw) araddr();
    method AXI4_Lite_Prot arprot();

    // read data channel

    (* prefix = "" *)
    method Action m_rvalid(Bool rvalid);
    method Bool rready();

    (* prefix = "" *)
    method Action m_rchan(Bit#(dataw) rdata, AXI4_Lite_Resp rresp);

endinterface: AXI4_Lite_Master_Rd_Fab

interface AXI4_Lite_Master_Rd#(numeric type addrw, numeric type dataw);
    (* prefix = "" *)
    interface AXI4_Lite_Master_Rd_Fab#(addrw, dataw) fab;
    interface Server#(AXI4_Lite_Rq_Rd#(addrw), AXI4_Lite_Rsp_Rd#(dataw)) bus;
endinterface: AXI4_Lite_Master_Rd


module mkAXI4_Lite_Master_Rd#(Integer bufsz)(AXI4_Lite_Master_Rd#(addrw, dataw));

    FIFOF#(AXI4_Lite_Rq_Rd#(addrw)) req_fifo <- mkFIFOF();
    FIFOF#(AXI4_Lite_Rsp_Rd#(dataw)) resp_fifo <- mkFIFOF();

    Wire#(Bool) arready_signal <- mkWire();
    Wire#(AXI4_Lite_Rq_Rd#(addrw)) addr_read_data <- mkDWire(?);

    Wire#(Bool) rvalid_signal <- mkWire();
    Wire#(AXI4_Lite_Rsp_Rd#(dataw)) data_read_resp <- mkWire();

    rule wire_to_response (resp_fifo.notFull() && rvalid_signal);
        resp_fifo.enq(data_read_resp);
    endrule
    
    // combine the following two rules?
    rule request_to_wire;
        addr_read_data <= req_fifo.first();
    endrule

    rule read_req_fifo_deq (req_fifo.notEmpty() && arready_signal);
        req_fifo.deq();
    endrule

    interface AXI4_Lite_Master_Rd_Fab fab;

        interface m_arready = arready_signal._write();
        interface arvalid = req_fifo.notEmpty;

        interface araddr = addr_read_data.addr;
        interface arprot = addr_read_data.prot;

        interface m_rvalid = rvalid_signal._write();
        interface rready = resp_fifo.notFull;

        method Action m_rchan(Bit#(dataw) rdata, AXI4_Lite_Resp rresp);
            AXI4_Lite_Rsp_Rd#(dataw) resp;
            resp.data = rdata;
            resp.resp = rresp;
            data_read_resp <= resp;
        endmethod

    endinterface: fab

    interface Server bus;
        interface Put request = toPut(req_fifo);
        interface Get response = toGet(resp_fifo);
    endinterface: bus

endmodule: mkAXI4_Lite_Master_Rd


// ---------------------------------
// AXI4 Lite Master / Write channels
// ---------------------------------


(* always_ready, always_enabled *)
interface AXI4_Lite_Master_Wr_Fab#(numeric type addrw, numeric type dataw);

    // write address channel
    
    (* prefix = "" *)
    method Action m_awready(Bool awready); 
    method Bool awvalid(); 
    
    method Bit#(addrw) awaddr();
    method AXI4_Lite_Prot awprot();

    // write data channel

    (* prefix = "" *)
    method Action m_wready(Bool wready); 
    method Bool wvalid(); 

    method Bit#(dataw) wdata();
    method Bit#(TDiv#(dataw, 8)) wstrb();

    // write response channel

    (* prefix = "" *)
    method Action m_bvalid(Bool bvalid);
    method Bool bready(); 
    
    (* prefix = "" *)
    method Action m_bresp(AXI4_Lite_Resp bresp);

endinterface: AXI4_Lite_Master_Wr_Fab


interface AXI4_Lite_Master_Wr#(numeric type addrw, numeric type dataw);
    interface AXI4_Lite_Master_Wr_Fab#(addrw, dataw) fab;
    interface Server#(AXI4_Lite_Rq_Wr#(addrw, dataw), AXI4_Lite_Rsp_Wr) bus;
endinterface: AXI4_Lite_Master_Wr


module mkAXI4_Lite_Master_Wr#(Integer bufsz)(AXI4_Lite_Master_Wr#(addrw, dataw));

    FIFOF#(AXI4_Lite_Rq_Wr#(addrw, dataw)) write_fifo <- mkSizedFIFOF(bufsz);
    FIFOF#(AXI4_Lite_Rsp_Wr) write_resp_fifo <- mkSizedFIFOF(bufsz);

    Wire#(AXI4_Lite_Rq_Wr#(addrw, dataw)) write_request <- mkDWire(?);

    Wire#(Bool) awready_signal <- mkWire();
    Wire#(Bool) wready_signal <- mkWire();
    Wire#(Bool) bvalid_signal <- mkWire();
 
    FIFOF#(Bit#(addrw)) addr_buffer <- mkFIFOF(); 
    FIFOF#(AXI4_Lite_Prot) prot_buffer <- mkFIFOF();
    FIFOF#(Bit#(dataw)) data_buffer <- mkFIFOF();
    FIFOF#(Bit#(TDiv#(dataw, 8))) strb_buffer <- mkFIFOF();

    Wire#(Bit#(addrw)) addr_wire <- mkDWire(?);
    Wire#(AXI4_Lite_Prot) prot_wire <- mkDWire(?);
    Wire#(Bit#(dataw)) data_wire <- mkDWire(?);
    Wire#(Bit#(TDiv#(dataw, 8))) strb_wire <- mkDWire(?);   

    Wire#(AXI4_Lite_Resp) resp_wire <- mkWire();


    rule request_to_buffer;
        let rq = write_fifo.first();
        addr_buffer.enq(rq.addr);
        prot_buffer.enq(rq.prot);
        data_buffer.enq(rq.data);
        strb_buffer.enq(rq.strb);
        write_fifo.deq();
    endrule

    rule addr_and_prot_to_wire;
        addr_wire <= addr_buffer.first();
        prot_wire <= prot_buffer.first();
    endrule

    rule data_and_strb_to_wire;
        data_wire <= data_buffer.first();
        strb_wire <= strb_buffer.first();
    endrule

    rule addr_and_prot_deq (awready_signal);
        addr_buffer.deq();
        prot_buffer.deq();
    endrule

    rule data_and_strb_deq (wready_signal);
        data_buffer.deq();
        strb_buffer.deq();
    endrule

    rule resp_wire_to_buffer (write_resp_fifo.notFull && bvalid_signal);
        write_resp_fifo.enq(AXI4_Lite_Rsp_Wr { resp : resp_wire });
    endrule

    interface AXI4_Lite_Master_Wr_Fab fab;
        // write address channel
        interface awvalid = (addr_buffer.notEmpty && prot_buffer.notEmpty);
        interface m_awready = awready_signal._write();

        interface awaddr = addr_wire;
        interface awprot = prot_wire;

        // write data channel
        interface wvalid = (data_buffer.notEmpty && strb_buffer.notEmpty);
        interface m_wready = wready_signal._write();

        interface wdata = data_wire;
        interface wstrb = strb_wire;

        // write response channel
        interface bready = write_resp_fifo.notFull;
        interface m_bvalid = bvalid_signal._write();

        interface m_bresp = resp_wire._write();

    endinterface: fab   

    interface Server bus;
        interface Put request = toPut(write_fifo);
        interface Get response = toGet(write_resp_fifo);
    endinterface: bus

endmodule: mkAXI4_Lite_Master_Wr


endpackage: AXI4LiteMaster
