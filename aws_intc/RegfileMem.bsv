package RegfileMem;

import AXI4LiteMaster::*;
import AXI4LiteSlave::*;
import AXI4LiteTypes::*;

import ClientServer::*;
import Connectable::*;
import GetPut::*;
import FIFOF::*;

import RegFile::*;


interface RegfileMem#(numeric type addrw, numeric type dataw);
    (* prefix = "S_AXI" *)
    interface AXI4_Lite_Slave_Rd_Fab#(addrw, dataw) rd_fab;
    (* prefix = "S_AXI" *)
    interface AXI4_Lite_Slave_Wr_Fab#(addrw, dataw) wr_fab;
endinterface: RegfileMem

(* default_clock_osc = "S_AXI_ACLK", default_reset = "S_AXI_ARESETN" *)
module mkRegfileMem(RegfileMem#(addrw, dataw));
    AXI4_Lite_Slave_Rd#(addrw, dataw) rd <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(addrw, dataw) wr <- mkAXI4_Lite_Slave_Wr(2);

    RegFile#(Bit#(addrw), Bit#(dataw)) regmem <- mkRegFileFull();

    rule write_request;
        let r <- wr.bus.request.get();

        regmem.upd(r.addr, r.data);
        wr.bus.response.put(AXI4_Lite_Rsp_Wr {
                resp : OKAY
            });     

        $display("--> WRITE to %x: %x (Strobe: %b) <--",
            r.addr, r.data, r.strb);
    endrule

    rule read_request;
        let r <- rd.bus.request.get();
        
        let data = regmem.sub(r.addr);
        rd.bus.response.put(AXI4_Lite_Rsp_Rd {
                data : data,
                resp : OKAY
            });

        $display("--> READ from %x: %x <--", r.addr, data);
    endrule

    interface AXI4_Lite_Slave_Rd_Fab rd_fab = rd.fab;
    interface AXI4_Lite_Slave_Wr_Fab wr_fab = wr.fab;
endmodule: mkRegfileMem

endpackage: RegfileMem
