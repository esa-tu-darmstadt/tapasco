/*
 *  Implementation of the (full) AXI4 Slave Interface
 *
 *  Channel: Source -> Target (Prefix)
 *  -----------------------------------
 *  Write address channel:  M -> S (aw)
 *  Write data channel:     M -> S (w)
 *  Write response channel: S -> M (b)
 *  Read address channel:   M -> S (ar)
 *  Read data channel:      S -> M (r)
 */

package AXI4Slave;

import Connectable::*;
import FIFOF::*;
import GetPut::*;

import AXI4Types::*;
import AXI4Master::*;


// --------------------------
// AXI4 Slave / Read channels
// --------------------------


(* always_ready, always_enabled *)
interface AXI4_Slave_Rd_Fab#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);

    // Read address channel
    method Bool arready();
    (* prefix = "" *)
    method Action m_arvalid(Bool arvalid);

    (* prefix = "" *)
    method Action m_archan(
            Bit#(idw) arid,
            Bit#(addrw) araddr,
            Bit#(4) arregion,
            UInt#(8) arlen,
            AXI4_Burst_Size arsize,
            AXI4_Burst_Type arburst,
            AXI4_Lock arlock,
            AXI4_Rd_Cache arcache,
            AXI4_Prot arprot,
            Bit#(4) arqos,
            Bit#(userw) aruser
        );

    // Read data channel
    method Bool rvalid();
    (* prefix = "" *)
    method Action m_rready(Bool rready);

    method Bit#(idw) rid;
    method Bit#(dataw) rdata;
    method AXI4_Resp rresp;
    method Bit#(1) rlast;
    method Bit#(userw) ruser;

endinterface: AXI4_Slave_Rd_Fab


interface AXI4_Slave_Rd#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);
    (* prefix = "" *)
    interface AXI4_Slave_Rd_Fab#(addrw, dataw, idw, userw) fab;
    interface Get#(AXI4_Rq_Rd#(addrw, idw, userw)) req;
    interface Put#(AXI4_Rsp_Rd#(dataw, idw, userw)) resp;   
endinterface: AXI4_Slave_Rd


module mkAXI4_Slave_Rd#(Integer bufszin, Integer bufszout)
        (AXI4_Slave_Rd#(addrw, dataw, idw, userw));

    // read address channel

    FIFOF#(AXI4_Rq_Rd#(addrw, idw, userw)) req_fifo <- mkSizedFIFOF(bufszin);

    Wire#(Bool) arvalid_signal <- mkWire();
    Wire#(AXI4_Rq_Rd#(addrw, idw, userw)) addr_read_data <- mkWire();

    // read data channel

    Wire#(Bool) rready_signal <- mkWire();
    FIFOF#(AXI4_Rsp_Rd#(dataw, idw, userw)) resp_fifo <- mkSizedFIFOF(bufszout);
    Wire#(AXI4_Rsp_Rd#(dataw, idw, userw)) data_read_resp <- mkDWire(?);

    // rules - read address channel

    rule request_from_wire (req_fifo.notFull() && arvalid_signal);
        req_fifo.enq(addr_read_data);
    endrule

    function Action archan(
            Bit#(idw) arid,
            Bit#(addrw) araddr,
            Bit#(4) arregion,
            UInt#(8) arlen,
            AXI4_Burst_Size arsize,
            AXI4_Burst_Type arburst,
            AXI4_Lock arlock,
            AXI4_Rd_Cache arcache,
            AXI4_Prot arprot,
            Bit#(4) arqos,
            Bit#(userw) aruser);
        action
            addr_read_data <= AXI4_Rq_Rd {
                id     : arid,
                addr   : araddr,
                region : arregion,
                len    : arlen,
                size   : arsize,
                burst  : arburst,
                lock   : arlock,
                cache  : arcache,
                prot   : arprot,
                qos    : arqos,
                user   : aruser
            };
        endaction
    endfunction

    // rules - read data channel

    rule wire_to_response;
        let resp = resp_fifo.first();
        data_read_resp <= resp;
        if (rready_signal) begin
            resp_fifo.deq();
        end
    endrule


    interface AXI4_Slave_Rd_Fab fab;
        // Read address channel
        interface arready = req_fifo.notFull();
        interface m_arvalid = arvalid_signal._write();

        interface m_archan = archan;

        // Read data channel
        interface rvalid = resp_fifo.notEmpty;
        interface m_rready = rready_signal._write;

        interface rid = data_read_resp.id;
        interface rdata = data_read_resp.data;
        interface rresp = data_read_resp.resp;
        interface rlast = data_read_resp.last;
        interface ruser = data_read_resp.user;

    endinterface: fab

    interface Get req = toGet(req_fifo);
    interface Put resp = toPut(resp_fifo);

endmodule: mkAXI4_Slave_Rd


// ------------------------------------------------
// AXI4 Slave / Write address/data/response channel
// ------------------------------------------------


(* always_ready, always_enabled *)
interface AXI4_Slave_Wr_Fab#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);

    // write address channel
    
    method Bool awready(); 
    (* prefix = "" *)
    method Action m_awvalid(Bool awvalid); 

    (* prefix = "" *)
    method Action m_awchan(
            Bit#(addrw) awaddr,
            AXI4_Prot awprot,
            Bit#(idw) awid,
            UInt#(8) awlen,
            AXI4_Burst_Size awsize,
            AXI4_Burst_Type awburst,
            AXI4_Lock awlock,
            AXI4_Wr_Cache awcache,
            Bit#(4) awqos,
            Bit#(4) awregion,
            Bit#(userw) awuser
        );

    // write data channel

    method Bool wready(); 
    (* prefix = "" *)
    method Action m_wvalid(Bool wvalid); 

    (* prefix = "" *)
    method Action m_wchan(
            Bit#(dataw) wdata,
            Bit#(TDiv#(dataw, 8)) wstrb,
            Bit#(1) wlast,
            Bit#(userw) wuser
        );

    // write response channel

    method Bool bvalid();
    (* prefix = "" *)
    method Action m_bready(Bool bready); 
    
    method AXI4_Resp bresp();
    method Bit#(idw) bid();
    method Bit#(userw) buser();

endinterface: AXI4_Slave_Wr_Fab


interface AXI4_Slave_Wr#(numeric type addrw, numeric type dataw, numeric type idw, numeric type userw);
    interface AXI4_Slave_Wr_Fab#(addrw, dataw, idw, userw) fab;
    interface Get#(AXI4_Addr_Rq_Wr#(addrw, idw, userw)) addr;
    interface Get#(AXI4_Data_Rq_Wr#(dataw, userw)) data;
    interface Put#(AXI4_Rsp_Wr#(idw, userw)) resp;
endinterface: AXI4_Slave_Wr


module mkAXI4_Slave_Wr#(Integer bufszinaddr, Integer bufszindata, Integer bufszout)
        (AXI4_Slave_Wr#(addrw, dataw, idw, userw));

    // Write address channel
    Wire#(Bool) awvalid_signal <- mkWire();

    Wire#(AXI4_Addr_Rq_Wr#(addrw, idw, userw)) wr_addr_wire <- mkWire();
    FIFOF#(AXI4_Addr_Rq_Wr#(addrw, idw, userw)) wr_addr_buffer <- mkSizedFIFOF(bufszinaddr);

    // Write data channel
    Wire#(Bool) wvalid_signal <- mkWire(); 

    Wire#(AXI4_Data_Rq_Wr#(dataw, userw)) wr_data_wire <- mkWire();
    FIFOF#(AXI4_Data_Rq_Wr#(dataw, userw)) wr_data_buffer <- mkSizedFIFOF(bufszindata);

    // Write response channel
    FIFOF#(AXI4_Rsp_Wr#(idw, userw)) write_resp_fifo <- mkSizedFIFOF(bufszout);
    Wire#(Bool) bready_signal <- mkWire(); 
    Wire#(AXI4_Rsp_Wr#(idw, userw)) resp_wire <- mkDWire(?);

    // Rules: Write address channel
    rule write_addr_to_wire (wr_addr_buffer.notFull() && awvalid_signal);
        wr_addr_buffer.enq(wr_addr_wire);
    endrule

    function Action awchan(
                Bit#(addrw) awaddr,
                AXI4_Prot awprot,
                Bit#(idw) awid,
                UInt#(8) awlen,
                AXI4_Burst_Size awsize,
                AXI4_Burst_Type awburst,
                AXI4_Lock awlock,
                AXI4_Wr_Cache awcache,
                Bit#(4) awqos,
                Bit#(4) awregion,
                Bit#(userw) awuser
            );      
        action
            wr_addr_wire <= AXI4_Addr_Rq_Wr {
                addr   : awaddr,
                prot   : awprot,
                id     : awid,
                len    : awlen,
                size   : awsize,
                burst  : awburst,
                lock   : awlock,
                cache  : awcache,
                qos    : awqos,
                region : awregion,
                user   : awuser
            };
        endaction
    endfunction

    // Rules: Write data channel
    rule write_data_to_wire (wr_data_buffer.notFull() && wvalid_signal);
        wr_data_buffer.enq(wr_data_wire);
    endrule

    function Action wchan(
                Bit#(dataw) wdata,
                Bit#(TDiv#(dataw, 8)) wstrb,
                Bit#(1) wlast,
                Bit#(userw) wuser
            );      
        action
            wr_data_wire <= AXI4_Data_Rq_Wr {
                data : wdata,
                strb : wstrb,
                last : wlast,
                user : wuser
            };
        endaction
    endfunction

    // Rules: Write response channel
    rule resp_wire_to_buffer;
        let resp = write_resp_fifo.first();
        resp_wire <= resp;
        if (bready_signal) begin
            write_resp_fifo.deq();
        end
    endrule

    interface AXI4_Slave_Wr_Fab fab;

        // Write address channel
        interface m_awvalid = awvalid_signal._write;
        interface awready = wr_addr_buffer.notFull;

        interface m_awchan = awchan;

        // Write data channel
        interface m_wvalid = wvalid_signal._write;
        interface wready = wr_data_buffer.notFull;

        interface m_wchan = wchan;

        // Write response channel
        interface m_bready = bready_signal._write;
        interface bvalid = write_resp_fifo.notEmpty;

        interface bid = resp_wire.id;
        interface bresp = resp_wire.resp;
        interface buser = resp_wire.user;

    endinterface: fab   

    interface Get addr = toGet(wr_addr_buffer);
    interface Get data = toGet(wr_data_buffer);
    interface Put resp = toPut(write_resp_fifo);

endmodule: mkAXI4_Slave_Wr


instance Connectable#(AXI4_Master_Rd_Fab#(addrw, dataw, idw, userw),
        AXI4_Slave_Rd_Fab#(addrw, dataw, idw, userw));

    module mkConnection#(AXI4_Master_Rd_Fab#(addrw, dataw, idw, userw) m,
            AXI4_Slave_Rd_Fab#(addrw, dataw, idw, userw) s)();

        rule conn_read_1; m.m_arready(s.arready); endrule
        rule conn_read_2; s.m_arvalid(m.arvalid); endrule
        rule conn_read_3; s.m_archan(
                    m.arid,
                    m.araddr, 
                    m.arregion, 
                    m.arlen, 
                    m.arsize, 
                    m.arburst, 
                    m.arlock, 
                    m.arcache, 
                    m.arprot,
                    m.arqos,
                    m.aruser
                );
        endrule
        rule conn_read_4; m.m_rvalid(s.rvalid); endrule
        rule conn_read_5; s.m_rready(m.rready); endrule
        rule conn_read_6; m.m_rchan(
                    s.rid, 
                    s.rdata, 
                    s.rresp, 
                    s.rlast,
                    s.ruser
            );
        endrule     
    endmodule
endinstance: Connectable


instance Connectable#(AXI4_Master_Wr_Fab#(addrw, dataw, idw, userw),
        AXI4_Slave_Wr_Fab#(addrw, dataw, idw, userw));

    module mkConnection#(AXI4_Master_Wr_Fab#(addrw, dataw, idw, userw) m,
            AXI4_Slave_Wr_Fab#(addrw, dataw, idw, userw) s)();

        rule conn_write_1; m.m_awready(s.awready); endrule
        rule conn_write_2; s.m_awvalid(m.awvalid); endrule
        rule conn_write_3; s.m_awchan(
                    m.awaddr, 
                    m.awprot, 
                    m.awid, 
                    m.awlen, 
                    m.awsize,
                    m.awburst, 
                    m.awlock, 
                    m.awcache, 
                    m.awqos, 
                    m.awregion,
                    m.awuser
                );
        endrule
        rule conn_write_4; m.m_wready(s.wready); endrule
        rule conn_write_5; s.m_wvalid(m.wvalid); endrule
        rule conn_write_6; s.m_wchan(
                    m.wdata,
                    m.wstrb, 
                    m.wlast,
                    m.wuser
                ); 
        endrule
        rule conn_write_7; m.m_bvalid(s.bvalid); endrule
        rule conn_write_8; s.m_bready(m.bready); endrule
        rule conn_write_9; m.m_bid(s.bid); endrule
        rule conn_write_10; m.m_bresp(s.bresp); endrule
        rule conn_write_11; m.m_buser(s.buser); endrule
    endmodule
endinstance: Connectable


endpackage: AXI4Slave
