package AXI4_Stream;

import GetPut :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;
import Connectable :: *;
// Project specific

/*
=============
	Types
=============
*/
typedef struct {
		Bit#(datawidth) data;
		Bit#(userwidth) user;
		Bit#(TDiv#(datawidth, 8)) keep;
		Bit#(4) dest;
		Bool last;
	} AXI4_Stream_Pkg#(numeric type datawidth, numeric type userwidth) deriving(Bits, Eq, FShow);

typedef AXI4_Stream_Pkg#(32, 1) AXI4_Stream_Pkg_32;
typedef AXI4_Stream_Pkg#(64, 1) AXI4_Stream_Pkg_64;
typedef AXI4_Stream_Pkg#(128, 1) AXI4_Stream_Pkg_128;
typedef AXI4_Stream_Pkg#(256, 1) AXI4_Stream_Pkg_256;
typedef AXI4_Stream_Pkg#(512, 1) AXI4_Stream_Pkg_512;

/*
========================
	AXI 4 Stream Read
========================
*/

(* always_ready, always_enabled *)
interface AXI4_Stream_Rd_Fab#(numeric type datawidth, numeric type userwidth);
  method Bool tready;
  (*prefix=""*)method Action ptvalid((*port="tvalid"*) Bool tvalid);
  (*prefix=""*)method Action ptdata((*port="tdata"*)Bit#(datawidth) data);
  (*prefix=""*)method Action ptuser((*port="tuser"*)Bit#(userwidth) user);
  (*prefix=""*)method Action ptkeep((*port="tkeep"*)Bit#(TDiv#(datawidth, 8)) keep);
  (*prefix=""*)method Action ptDest((*port="tDest"*)Bit#(4) dest);
  (*prefix=""*)method Action ptlast((*port="tlast"*)Bool last);
endinterface

interface AXI4_Stream_Rd#(numeric type datawidth, numeric type userwidth);
  (* prefix="" *)
  interface AXI4_Stream_Rd_Fab#(datawidth, userwidth) fab;
  interface Get#(AXI4_Stream_Pkg#(datawidth, userwidth)) pkg;
endinterface

module mkAXI4_Stream_Rd#(Integer bufferSize)(AXI4_Stream_Rd#(datawidth, userwidth))
	provisos(Div#(datawidth, 8, keepwidth));

	Wire#(Bool) 					  tvalidIn <- mkBypassWire();
	Wire#(Bit#(datawidth)) 			  dataIn <- mkBypassWire();
	Wire#(Bit#(userwidth)) 			  userIn <- mkBypassWire();
	Wire#(Bit#(keepwidth))	 		  keepIn <- mkBypassWire();
    Wire#(Bit#(4))	 		          destIn <- mkBypassWire();
	Wire#(Bool) 					  lastIn <- mkBypassWire();

	FIFOF#(AXI4_Stream_Pkg#(datawidth, userwidth)) in <- mkSizedFIFOF(bufferSize);
	if(bufferSize == 1)
		in <- mkPipelineFIFOF();
	if(bufferSize == 2)
		in <- mkFIFOF();

	rule writeFIFO if(tvalidIn && in.notFull());
		AXI4_Stream_Pkg#(datawidth, userwidth) s;
		s.data = dataIn;
		s.user = userIn;
		s.keep = keepIn;
		s.dest = destIn;
		s.last = lastIn;
		in.enq(s);
	endrule

	interface Get pkg = toGet(in);

	interface AXI4_Stream_Rd_Fab fab;
		interface tready = in.notFull();
		interface ptvalid = tvalidIn._write;
		interface ptdata = dataIn._write;
		interface ptuser = userIn._write;
		interface ptkeep = keepIn._write;
		interface ptDest = destIn._write;
		interface ptlast = lastIn._write;
	endinterface
endmodule

/*
========================
	AXI 4 Stream Write
========================
*/

(* always_ready, always_enabled *)
interface AXI4_Stream_Wr_Fab#(numeric type datawidth, numeric type userwidth);
  method Bool tvalid;
  (*prefix=""*)method Action ptready((*port="tready"*) Bool tr);
  method Bit#(datawidth) tdata;
  method Bool tlast;
  method Bit#(userwidth) tuser;
  method Bit#(TDiv#(datawidth, 8)) tkeep;
  method Bit#(4) tDest;
endinterface

interface AXI4_Stream_Wr#(numeric type datawidth, numeric type userwidth);
  (* prefix="" *)
  interface AXI4_Stream_Wr_Fab#(datawidth, userwidth) fab;
  interface Put#(AXI4_Stream_Pkg#(datawidth, userwidth)) pkg;
endinterface

module mkAXI4_Stream_Wr#(Integer bufferSize)(AXI4_Stream_Wr#(datawidth, userwidth))
	provisos(Div#(datawidth, 8, keepwidth));

	FIFOF#(AXI4_Stream_Pkg#(datawidth, userwidth)) out <- mkSizedFIFOF(bufferSize);
	if(bufferSize == 1)
		out <- mkPipelineFIFOF();
	if(bufferSize == 2)
		out <- mkFIFOF();

	Wire#(Bool) treadyIn <- mkBypassWire;
	Wire#(Bool) tvalidOut <- mkDWire(False);
	Wire#(Bit#(datawidth)) tdataOut <- mkDWire(unpack(0));
	Wire#(Bit#(userwidth)) tuserOut <- mkDWire(unpack(0));
	Wire#(Bit#(keepwidth)) tkeepOut <- mkDWire(unpack(0));
	Wire#(Bit#(4)) tdestOut <- mkDWire(unpack(0));
	Wire#(Bool) tlastOut <- mkDWire(False);

	rule deqFIFO if(treadyIn && out.notEmpty());
		out.deq();
	endrule

	rule writeOutputs;
		tdataOut <= out.first().data();
		tlastOut <= out.first().last();
		tuserOut <= out.first().user();
		tkeepOut <= out.first().keep();
		tdestOut <= out.first().dest();
	endrule

	interface AXI4_Stream_Wr_Fab fab;
		interface tvalid = out.notEmpty();
		interface ptready = treadyIn._write();
		interface tdata = tdataOut;
		interface tlast = tlastOut;
		interface tuser = tuserOut;
		interface tkeep = tkeepOut;
		interface tDest = tdestOut;
	endinterface

	interface Put pkg = toPut(out);
endmodule

/*
========================
	Connectable
========================
*/

instance Connectable#(AXI4_Stream_Wr_Fab#(datawidth, userwidth), AXI4_Stream_Rd_Fab#(datawidth, userwidth));
	module mkConnection#(AXI4_Stream_Wr_Fab#(datawidth, userwidth) wr, AXI4_Stream_Rd_Fab#(datawidth, userwidth) rd)(Empty);

		rule forward1;
			wr.ptready(rd.tready());
		endrule
		rule forward2;
			rd.ptvalid(wr.tvalid());
		endrule
		rule forward3;
			rd.ptdata(wr.tdata());
		endrule
		rule forward4;
			rd.ptlast(wr.tlast());
		endrule
		rule forward5;
			rd.ptuser(wr.tuser());
		endrule
		rule forward6;
			rd.ptkeep(wr.tkeep());
		endrule
		rule forward7;
			rd.ptDest(wr.tDest());
		endrule

	endmodule
endinstance

endpackage
