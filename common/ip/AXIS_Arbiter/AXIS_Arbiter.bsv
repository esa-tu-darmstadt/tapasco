package AXIS_Arbiter;
import AXI4_Stream  :: *;
import GetPut       :: *;

interface Arbiter;
  interface AXI4_Stream_Wr_Fab#(64,1) axis_M;
  interface AXI4_Stream_Rd_Fab#(64,1) axis_S;
  (* always_ready, always_enabled, prefix = "" *)
  method Action  arbiter_turnover((* port = "maxClients" *) Bit#(5) b);
endinterface


module mkAXIS_Arbiter(Arbiter);
  AXI4_Stream_Wr#(64, 1) streamOut   <- mkAXI4_Stream_Wr(1);
  AXI4_Stream_Rd#(64, 1)  streamIn   <- mkAXI4_Stream_Rd(1);
//---------------------------------------------------
  Wire#(Bit#(5)) turnover  <- mkDWire(0);
  Reg#(Bit#(5))  arbiter   <- mkReg(0);
//---------------------------------------------------
  rule axiStream1;
    AXI4_Stream_Pkg_64 in <- streamIn.pkg.get();
    in.dest = arbiter[3:0];
    streamOut.pkg.put(in);
    arbiter <= in.last? (arbiter+1) % turnover : arbiter;
  endrule
  
    method arbiter_turnover = turnover._write;
    interface AXI4_Stream_Receive axis_S     = streamIn.fab;
    interface AXI4_Stream_Send    axis_M     = streamOut.fab;
  endmodule
endpackage
