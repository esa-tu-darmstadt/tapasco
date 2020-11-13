package CascabelQueue;

import DefaultValue :: *;
import BRAM :: *;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAMFIFO::*;
import Clocks::*;
import BUtils :: *;

import BlueAXI :: *;
import BlueLib :: *;

import CascabelTypes::*;

typedef 12 CONF_AXI_ADDR_WIDTH;
typedef 64 CONF_AXI_DATA_WIDTH;

typedef 128 PACKET_QUEUE_ELEMENTS;
typedef TLog#(PACKET_SIZE_BYTES) PACKET_ADDR_BITS;
typedef TMul#(PACKET_SIZE_BYTES, PACKET_QUEUE_ELEMENTS) PACKET_QUEUE_SIZE;
typedef TLog#(PACKET_QUEUE_SIZE) PACKET_BYTE_ADDR_WIDTH;
typedef TLog#(PACKET_QUEUE_ELEMENTS) QUEUE_POINTER_ADDR_WIDTH;
typedef TMax#(PACKET_BYTE_ADDR_WIDTH, 12) PACKET_AXI_ADDR_WIDTH;
typedef TMul#(PACKET_SIZE_BYTES, 8) PACKET_AXI_DATA_WIDTH;

typedef 8 PACKET_AXI_ID_WIDTH;

interface CascabelQueue;
	(*prefix="S_AXI_CONTROL"*) interface AXI4_Lite_Slave_Rd_Fab#(CONF_AXI_ADDR_WIDTH, CONF_AXI_DATA_WIDTH) ctrl_rd;
	(*prefix="S_AXI_CONTROL"*) interface AXI4_Lite_Slave_Wr_Fab#(CONF_AXI_ADDR_WIDTH, CONF_AXI_DATA_WIDTH) ctrl_wr;

	(*prefix="S_AXI_PACKET"*) interface AXI4_Slave_Rd_Fab#(PACKET_AXI_ADDR_WIDTH, PACKET_AXI_DATA_WIDTH, PACKET_AXI_ID_WIDTH, 0) packet_rd;
	(*prefix="S_AXI_PACKET"*) interface AXI4_Slave_Wr_Fab#(PACKET_AXI_ADDR_WIDTH, PACKET_AXI_DATA_WIDTH, PACKET_AXI_ID_WIDTH, 0) packet_wr;

	method Action deq();
	method Job first();
endinterface

// This handler implements the increase operation needed for HSA as specified in the User mode queuing requirements
// Increases register value by one and returns the old value
function ActionValue#(Bit#(data_width)) registerAtomicIncrHandler(Reg#(a) r, AXI4_Lite_Prot p)
	provisos(Bits#(a, a_sz),
			 Arith#(a));
	actionvalue
		r <= r + 1;
		return zExtend(pack(r));
	endactionvalue
endfunction

function List#(RegisterOperator#(axiAddrWidth, axiDataWidth)) addRegisterAtomicIncrHandler(Integer register, Reg#(t) r, List#(RegisterOperator#(axiAddrWidth, axiDataWidth)) op)
	provisos(Arith#(t), Bits#(t, t_sz));
	op = List::cons(tagged Read ReadOperation { index: fromInteger(register), fun: registerAtomicIncrHandler(r) }, op);
	return op;
endfunction

module mkCascabelQueue(Clock design_clk, Reset design_rst, CascabelQueue intf);
	// Control variables
	Bit#(12) queue_elements = fromInteger(valueOf(PACKET_QUEUE_ELEMENTS));
	Reg#(Bit#(CONF_AXI_DATA_WIDTH)) info <- mkReg({32'hCA3CABE1, 'h0, queue_elements});
	Reg#(UInt#(CONF_AXI_DATA_WIDTH)) read_ptr <- mkReg(0);
	Reg#(UInt#(CONF_AXI_DATA_WIDTH)) write_ptr <- mkReg(0);
	Reg#(UInt#(CONF_AXI_DATA_WIDTH)) filllevel <- mkReg(0);
	SyncFIFOIfc#(Job) jobs <- mkSyncBRAMFIFOFromCC(8, design_clk, design_rst);
	Reg#(Bool) waitMem <- mkReg(False);
	Reg#(Bool) firstFetch <-mkReg(True);

	// status
	Bit#(QUEUE_POINTER_ADDR_WIDTH) read_truncate = pack(truncate(read_ptr));
	Bit#(QUEUE_POINTER_ADDR_WIDTH) write_truncate = pack(truncate(write_ptr));
	let empty = (read_ptr == write_ptr);
	let full = (read_truncate == write_truncate) && (read_ptr != write_ptr);

	// Addresses of S_AXI_CONTROL
	// 0x   0: Info Register
	// 0x   8: Read Pointer direct access
	// 0x  10: Write Pointer direct access
	// 0x  40: Read Pointer increase by one on read
	// 0x  80: Write Pointer increase by one on read
	Integer addr_info_reg = 'h0;
	Integer addr_read_reg = 'h8;
	Integer addr_read_atomic_reg = 'h40;
	Integer addr_write_reg = 'h10;
	Integer addr_write_atomic_reg = 'h80;
	Integer addr_filllevel_reg = 'h20;

	let control <- mkGenericAxi4LiteSlave(
			registerHandlerRO(addr_info_reg, info,
			registerHandler(addr_read_reg, read_ptr,
			addRegisterAtomicIncrHandler(addr_read_atomic_reg, read_ptr,
			registerHandler(addr_write_reg, write_ptr,
			addRegisterAtomicIncrHandler(addr_write_atomic_reg, write_ptr,
			registerHandler(addr_filllevel_reg, filllevel,
			Nil)))))), 16, 16);

	BRAM2PortBE#(Bit#(QUEUE_POINTER_ADDR_WIDTH), PacketType, PACKET_SIZE_BYTES) bram <- mkBRAM2ServerBE(defaultValue);

	let packet <- mkBlueAXIBRAM(bram.portA);

	rule warnFull if(full);
		$display("QUEUE IS FULL");
	endrule

	rule filllevelRule;
		filllevel <= write_ptr - read_ptr;
	endrule

	// use bram.portB to dequeue for dispatching
	rule requestData if(!empty && waitMem == False);
		bram.portB.request.put(BRAMRequestBE { writeen: 0, address: pack(truncate(read_ptr))});
		waitMem <= True;
	endrule

	rule readData if(waitMem);
		let d <- bram.portB.response.get();
		Job j = unpack(truncate(d));
		if (j.valid && firstFetch) begin
			firstFetch <= False;
		end else if(j.valid) begin
			firstFetch <= True;
			$display("valid job found");
			// mark as invalid in memory
			let invalidj = j;
			invalidj.valid = False;
			bram.portB.request.put(BRAMRequestBE { writeen: 'hffff_ffff_ffff_ffff, responseOnWrite: False, address: pack(truncate(read_ptr)), datain: zeroExtend(pack(invalidj))});
			read_ptr <= read_ptr + 1;
			jobs.enq(j);
		end else begin
			// invalid job -> request again
		end
		waitMem <= False;
	endrule
	
	method Action deq();
		jobs.deq();
	endmethod

	method Job first();
		return jobs.first();
	endmethod

	interface ctrl_rd = control.s_rd;
	interface ctrl_wr = control.s_wr;

	interface packet_rd = packet.rd;
	interface packet_wr = packet.wr;
endmodule

endpackage
