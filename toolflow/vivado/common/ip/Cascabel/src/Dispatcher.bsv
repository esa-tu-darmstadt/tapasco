package Dispatcher;

import GetPut::*;
import Connectable::*;
import Vector::*;
import FIFO::*;
import DReg::*;

import BlueAXI :: *;
import BlueLib :: *;
import CascabelQueue::*;
import CascabelTypes::*;

import CascabelConfiguration::*;

// Implement the Queues for all kernel types
// available PEs are stored within queues seperated by kernel id.
interface PEQueues#(type gid);
	method Action enq(KID_TYPE kid, gid pe);
	method Action deq(KID_TYPE kid);
	method gid first(KID_TYPE kid);
endinterface

typedef enum { InitIER, InitGIER, InitDone } INIT_STATES deriving(Eq, Bits, FShow);

function Integer kid_lookup(KID_TYPE kid);
	Integer tmp = 0;
	for (Integer i = 0; i < valueOf(KID_COUNT); i = i + 1) begin
		if (kid_arr[i] == kid)
			tmp = i;
	end
	return tmp;
endfunction

module mkPEQueues(PEQueues#(gid))
	provisos(Bits#(gid, a__));

	Vector#(KID_COUNT, FIFO#(gid)) queueVec <- replicateM(mkSizedFIFO(16));

	method Action enq(KID_TYPE kid, gid pe);
		$display("enqueue %d (PE #%d) -> Queue %02d", kid, pe, kid_lookup(kid));
		queueVec[kid_lookup(kid)].enq(pe);
	endmethod

	method Action deq(KID_TYPE kid);
		$display("dequeue %d", kid);
		queueVec[kid].deq;
	endmethod

	method gid first(KID_TYPE kid);
		return queueVec[kid].first;
	endmethod
endmodule

function Bool isTrue (Bool a);
	return a;
endfunction

interface Dispatcher;
	method Action put(Job job);

	(*prefix="M_AXI"*) interface AXI4_Lite_Master_Rd_Fab#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) m_rd;
	(*prefix="M_AXI"*) interface AXI4_Lite_Master_Wr_Fab#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) m_wr;

	(* always_enabled *) method Vector#(PE_COUNT, Bool) intr_host();
	(* always_ready, always_enabled *) method Action intr((*port="intr"*) Vector#(PE_COUNT, Bool) data);
	method ActionValue#(JobResult) getResult();
endinterface

module mkDispatcher(Dispatcher);
// hard code status core function
	function Bit#(CONFIG_ADDR_WIDTH) getBaseFromGID(Bit#(TLog#(PE_COUNT)) pe);
		return {'h0,pe,16'h0000};
	endfunction

	FIFO#(Job) queue <- mkFIFO();

	Reg#(Vector#(PE_COUNT, Bool)) interrupts <- mkReg(replicate(True));
	Reg#(Vector#(PE_COUNT, Bool)) externalInterrupts <-mkReg(replicate(False));
	Reg#(Vector#(PE_COUNT, Bool)) externalInterrupts_buf <-mkReg(replicate(False));
	Vector#(PE_COUNT, Reg#(Bool)) clearInts <- replicateM(mkDWire(False));
	Vector#(PE_COUNT, Reg#(Bool)) barrierInts <- replicateM(mkDWire(False));
	Reg#(Vector#(PE_COUNT, Bool)) hostInterrupts <-mkReg(replicate(False));
	Vector#(PE_COUNT, Reg#(Bool)) forwardIntHost <- replicateM(mkReg(False));
	Reg#(Vector#(PE_COUNT, Maybe#(JOBID_TYPE))) associatedJob <-mkReg(replicate(tagged Invalid));
	PEQueues#(Bit#(TLog#(PE_COUNT))) emptyPEsQueues <- mkPEQueues();
	Reg#(Bool) jobStatus <- mkReg(False);
	Reg#(Bit#(8)) activeJobCount <- mkReg(0);
	Reg#(Bit#(CONFIG_ADDR_WIDTH)) jobBaseAdr <- mkRegU();
	Reg#(Job) job_reg <- mkRegU();
	Reg#(Bit#(TLog#(PE_COUNT))) initPE <- mkReg(fromInteger(valueOf(PE_COUNT)-1));
	Reg#(INIT_STATES) init <- mkReg(InitIER);
	FIFO#(JOBID_TYPE) resultFetchJID <- mkFIFO();

	// Create axi master port
	AXI4_Lite_Master_Rd#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) rd_m <- mkAXI4_Lite_Master_Rd(16);
	AXI4_Lite_Master_Wr#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) wr_m <- mkAXI4_Lite_Master_Wr(16);

	// block dequeuing if there is a barrier
	rule barrierContinue if(!jobStatus && queue.first.kerneltype == Barrier && init == InitDone && activeJobCount == 0);
		$display("[%04d] Found Barrier, all jobs completed, continue!", $time);
		queue.deq;
		if (queue.first.signal_host) begin
			// should issue an interrupt
			barrierInts[queue.first.param0] <= True;
		end
	endrule

	// check all kid queues non-blocking to select PE
	for (Integer i = 0; i < valueOf(KID_COUNT); i = i + 1) begin
		rule assignJob if(!jobStatus && queue.first.kerneltype == LaunchJob && kid_arr[i] == queue.first.kernel_id && init == InitDone);
			let pe = emptyPEsQueues.first(fromInteger(i));
			emptyPEsQueues.deq(fromInteger(i));
			queue.deq;
			$display("[%04d] start job on PE #%d...", $time, pe);
			jobStatus <= True;
			jobBaseAdr <= getBaseFromGID(pe);
			job_reg <= queue.first;
			forwardIntHost[pe] <= queue.first.signal_host;
			if (valueOf(PE_COUNT) == 1)
				associatedJob[0] <= tagged Valid queue.first.job_id;
			else
				associatedJob[pe] <= tagged Valid queue.first.job_id;
		endrule
	end

	rule initPE_IER if(init == InitIER);
		// set IER to 1 (0x08)
		axi4_lite_write_strb(wr_m, getBaseFromGID(initPE) + 'h8, 1, 1);
		$display("Init IER %02d", initPE);
		init <= InitGIER;
	endrule

	rule initPE_GIER if(init == InitGIER);
		// set GIER to 1 (0x04)
		axi4_lite_write_strb(wr_m, getBaseFromGID(initPE), 1 << 32, 1 << 4);
		$display("Init GIER %02d", initPE);
		init <= (initPE == 0) ? InitDone : InitIER;
		initPE <= initPE - 1;
	endrule

	rule startPE if(jobStatus && init == InitDone);
		if (job_reg.param_count > 0) begin
			// write 64bit parameter (at 0x20, 0x30 ...)
			axi4_lite_write(wr_m, jobBaseAdr + 'h10 + 'h10*pack(extend(job_reg.param_count)), job_reg.param0);
			Job tmp;
			tmp = job_reg;
			tmp.param0 = job_reg.param1;
			tmp.param1 = job_reg.param2;
			tmp.param2 = job_reg.param3;
			tmp.param_count = job_reg.param_count - 1;
			job_reg <= tmp;
		end else begin
			// set start bit
			axi4_lite_write_strb(wr_m, jobBaseAdr + 'h0, 1, 1);
			activeJobCount <= activeJobCount + 1;
			jobStatus <= False;
		end
	endrule
	
	rule dropWriteResponse;
		let r <- axi4_lite_write_response(wr_m);
	endrule

	// currently blocking if any of the queues is full
	rule enqueueFinished if (any(isTrue, interrupts));
		let i = fromMaybe(0, findIndex(isTrue, interrupts));
		$display ("[%04d] enqueue finished PE #%03d", $time, i);
		emptyPEsQueues.enq(pe_arr[i], pack(i));
		// unset interrupt
		clearInts[i] <= True;
		if (externalInterrupts[i]) begin
			// Acknowledge interrupt (ISR reg)
			axi4_lite_write_strb(wr_m, getBaseFromGID(pack(i)) + 'h8, 1 << 32, 1 << 4);
			activeJobCount <= activeJobCount - 1;
		end

		// read result register
		if (associatedJob[i] matches tagged Valid .jobid) begin
			axi4_lite_read(rd_m, getBaseFromGID(pack(i)) + 'h10);
			resultFetchJID.enq(jobid);
		end
	endrule

	rule clearInterrupts;
		Vector#(PE_COUNT, Bool) tmp;
		for (Integer i = 0; i < valueOf(PE_COUNT); i = i + 1) begin
			if (externalInterrupts[i] && !externalInterrupts_buf[i]) begin
				$display("[%04d] External interrupt from %d", $time, i);
			end
			// clear pending interrupts or detect new interrupt (rising edge)
			tmp[i] = (!clearInts[i] && interrupts[i]) || (externalInterrupts[i] && !externalInterrupts_buf[i]);
		end
		interrupts <= tmp;
		externalInterrupts_buf <= externalInterrupts;
	endrule

	// filter internal interrupts to forward to host
	rule filterHostIntr;
		Vector#(PE_COUNT, Bool) tmp;
		for (Integer i = 0; i < valueOf(PE_COUNT); i = i + 1) begin
			tmp[i] = (forwardIntHost[i] ? interrupts[i] : False) || barrierInts[i];
		end
		hostInterrupts <= tmp;
	endrule

	method Vector#(PE_COUNT, Bool) intr_host = hostInterrupts;
	
	method Action intr(Vector#(PE_COUNT, Bool) data);
		externalInterrupts <= data;
	endmethod

	method Action put(Job job);
		queue.enq(job);
	endmethod

	method ActionValue#(JobResult) getResult();
		let value <- axi4_lite_read_response(rd_m);
		let jobid = resultFetchJID.first;
		resultFetchJID.deq();
		return JobResult {result: value, job_id: jobid};
	endmethod

	// Connect to tapasco architecture
	interface AXI4_Lite_Master_Rd_Fab m_rd = rd_m.fab;
	interface AXI4_Lite_Master_Wr_Fab m_wr = wr_m.fab;
endmodule

endpackage
