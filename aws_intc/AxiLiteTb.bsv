package AxiLiteTb;

import AXI4LiteMaster::*;
import AXI4LiteSlave::*;
import AXI4LiteTypes::*;

import ClientServer::*;
import Connectable::*;
import GetPut::*;
import FIFOF::*;

import RegfileMem::*;

import StmtFSM::*;

import BlueCheck::*;


typedef 10 NUMREQ;
typedef 24 DATAW;
typedef 16 ADDRW;


module [BlueCheck] mkAxiLiteSpec();
    RegfileMem#(ADDRW, DATAW) mem <- mkRegfileMem(); // AXI4LiteSlave

    AXI4_Lite_Master_Rd#(ADDRW, DATAW) m_rd <- mkAXI4_Lite_Master_Rd(2);
    AXI4_Lite_Master_Wr#(ADDRW, DATAW) m_wr <- mkAXI4_Lite_Master_Wr(2);

    mkConnection(m_rd.fab, mem.rd_fab);
    mkConnection(m_wr.fab, mem.wr_fab);

    Ensure ensure <- getEnsure;

    function Stmt testReadWrite(Int#(ADDRW) x, Int#(DATAW) y) = 
    seq
        action
            AXI4_Lite_Rq_Wr#(ADDRW, DATAW) req;
            req.addr = pack(x);
            req.prot = UNPRIV_SECURE_DATA;
            req.strb = -1;
            req.data = pack(y);

            m_wr.bus.request.put(req);
        endaction
        action
            let resp <- m_wr.bus.response.get();        
            //$display("Got write response %t", $time);        
        endaction
        action
            AXI4_Lite_Rq_Rd#(ADDRW) req;
            req.addr = pack(x);
            req.prot = UNPRIV_SECURE_DATA;
            
            m_rd.bus.request.put(req);  
        endaction
        action
            let resp <- m_rd.bus.response.get();
            //$display("Got read response: Data = %x %t", resp.data, $time);
            ensure(resp.data == pack(y));
        endaction
    endseq;

    prop("testReadWrite", testReadWrite);
endmodule

module [Module] mkAxiLiteTb();
  blueCheck(mkAxiLiteSpec);
endmodule


// module mkAxiLiteTb();
    
//     RegfileMem#(ADDRW, DATAW) mem <- mkRegfileMem(); // AXI4LiteSlave

//     AXI4_Lite_Master_Rd#(ADDRW, DATAW) m_rd <- mkAXI4_Lite_Master_Rd(2);
//     AXI4_Lite_Master_Wr#(ADDRW, DATAW) m_wr <- mkAXI4_Lite_Master_Wr(2);
    
//     mkConnection(m_rd.fab, mem.rd_fab);
//     mkConnection(m_wr.fab, mem.wr_fab);

//     Reg#(Int#(ADDRW)) read_counter <- mkReg(0);

//     Reg#(Int#(ADDRW)) counter <- mkReg(0);
//     Reg#(Bool) not_started <- mkReg(True);

//     Stmt putrequests = 
//     seq
//         counter <= 0;
//         while (counter < fromInteger(valueOf(NUMREQ))) seq
//             action
//                 AXI4_Lite_Rq_Wr#(ADDRW, DATAW) req;
//                 req.addr = pack(counter);
//                 req.prot = UNPRIV_SECURE_DATA;
//                 req.strb = -1;
//                 req.data = extend(pack(counter));

//                 m_wr.bus.request.put(req);
//                 counter <= counter + 1;
//         endaction
//         endseq
//         counter <= 0;
//         while (counter < fromInteger(valueOf(NUMREQ))) seq
//             action
//                 AXI4_Lite_Rq_Rd#(ADDRW) req;
//                 req.addr = pack(counter);
//                 req.prot = UNPRIV_SECURE_DATA;
                
//                 m_rd.bus.request.put(req);  
//                 counter <= counter + 1;
//             endaction
//         endseq
//     endseq;

//     FSM putrequestsFSM <- mkFSM(putrequests);

//     rule start if (not_started);
//         putrequestsFSM.start();
//         not_started <= False;
//     endrule

//     rule finish if (read_counter == fromInteger(valueOf(NUMREQ)));
//         $finish();
//     endrule

//     rule fetch_write_response;
//         let resp <- m_wr.bus.response.get();
//         $display("Got write response %t", $time);
//     endrule

//     rule fetch_read_response;
//         read_counter <= read_counter + 1;
//         let resp <- m_rd.bus.response.get();
//         $display("Got read response: Data = %x %t", resp.data, $time);
//     endrule

// endmodule

endpackage
