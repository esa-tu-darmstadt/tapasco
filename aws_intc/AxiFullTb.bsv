package AxiFullTb;

import AXI4Master::*;
import AXI4Slave::*;
import AXI4Types::*;

import ClientServer::*;
import Connectable::*;
import GetPut::*;
import FIFOF::*;

import RegfileMemFull::*;

typedef 16 ADDR;
typedef 64 DATA;

(* synthesize *)
module mkAxiFullTb();
    
    RegfileMemFull#(ADDR, DATA) mem <- mkRegfileMemFull();

    AXI4_Master_Rd#(ADDR, DATA, 1, 1) m_rd <- mkAXI4_Master_Rd(2, 2);
    AXI4_Master_Wr#(ADDR, DATA, 1, 1) m_wr <- mkAXI4_Master_Wr(2, 2, 2);
    
    mkConnection(m_rd.fab, mem.rd_fab);
    mkConnection(m_wr.fab, mem.wr_fab);


    Reg#(UInt#(ADDR)) write_counter_1 <- mkReg(0);
    Reg#(Bool) write_addr_sent_1 <- mkReg(False);
    Reg#(Bool) write_ok_1 <- mkReg(False);

    Reg#(UInt#(ADDR)) read_counter <- mkReg(0);
    Reg#(Bool) read_addr_sent <- mkReg(False);
    Reg#(Bool) read_ok <- mkReg(False);


    rule put_write_addr_1 (write_addr_sent_1 == False);
        AXI4_Addr_Rq_Wr#(ADDR, 1, 1) rq = AXI4_Addr_Rq_Wr {
            id     : 1,
            addr   : 0,
            region : 0,
            len    : 9,
            size   : B1,
            burst  : INCR,
            lock   : NORMAL,
            cache  : DEVICE_NON_BUFFERABLE,
            prot   : UNPRIV_SECURE_DATA,
            qos    : 0,
            user   : 0
        };
        m_wr.addr.put(rq);

        write_addr_sent_1 <= True;
    endrule

    rule put_write_data_1 (write_counter_1 < 10);
        AXI4_Data_Rq_Wr#(DATA, 1) rq = AXI4_Data_Rq_Wr {
            data : extend(pack(write_counter_1)) + 64'hdecafbad000,
            strb : -1,
            last : pack(write_counter_1 == 9),
            user : 0
        };
        m_wr.data.put(rq);

        write_counter_1 <= write_counter_1 + 1;
    endrule

    rule get_write_response;
        let resp <- m_wr.resp.get();
        $display("Test: Got WRITE response: Id = %d Status = %d %t",
            resp.id, resp.resp, $time);

        write_ok_1 <= True;
    endrule
    
    rule put_read_request (read_addr_sent == False && write_ok_1);
        AXI4_Rq_Rd#(ADDR, 1, 1) rq = AXI4_Rq_Rd {
            id     : 0,
            addr   : 0,
            region : 0,
            len    : 9,
            size   : B1, // TODO parameter not considered
            burst  : INCR,
            lock   : NORMAL,
            cache  : DEVICE_NON_BUFFERABLE,
            prot   : UNPRIV_SECURE_DATA,
            qos    : 0,
            user   : 0
        };
        m_rd.req.put(rq);

        read_addr_sent <= True;
    endrule

    rule get_read_response;
        let resp <- m_rd.resp.get();
        $display("Test: Got READ response: Status = %d, Data = %x, Last = %d %t", 
            resp.resp, resp.data, resp.last, $time);

        if (resp.last == 1) begin
            read_ok <= True;
        end
    endrule

    rule all_done (/*write_ok_1 && write_ok_2 && */read_ok);
        $display("TB: Finished.");
        $finish();
    endrule

endmodule: mkAxiFullTb

endpackage
