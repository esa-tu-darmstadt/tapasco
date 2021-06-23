package MergeCompleter;

import FIFO::*;
import BRAM::*;
import Vector::*;

import CascabelTypes::*;
import CascabelConfiguration::*;

typedef struct {
`ifdef SIM
	Bit#(8) magic;
`endif
	Bit#(AXIS_ONCHIP_USERWIDTH) return_pe; // PE id for signaling/return value
	KID_TYPE merge_pe; // PE kernel type for merge PE, is called with up to 4 return values; grouped by job_id.
	Bit#(2) padding5;
	Maybe#(MergeJob) parent; // if this is a cascaded merge
	Bit#(4) padding4;
	Bool isReturn;
	Bit#(3) param_count;
	Bit#(7) padding0; Bool param0valid;
	Bit#(7) padding1; Bool param1valid;
	Bit#(7) padding2; Bool param2valid;
	Bit#(7) padding3; Bool param3valid;
	Bit#(64) param0;
	Bit#(64) param1;
	Bit#(64) param2;
	Bit#(64) param3;
} MergeBramType deriving(Bits, Eq, FShow);

interface MergeCompleter;
	method ActionValue#(MergeEntryAddr) getAddress(JOBID_TYPE jid, Bit#(AXIS_ONCHIP_USERWIDTH) pe, Bit#(3) merge_param_count);
	method Action releasePe(Bit#(AXIS_ONCHIP_USERWIDTH) pe);
	method Action bendReality(MergeJob m, Bit#(AXIS_ONCHIP_USERWIDTH) pe);
	method Action put(JobResult r, Bool writeParent);
	method ActionValue#(Job) get();
	method Action asyncJobReq(Job j);
	method ActionValue#(Job) asyncJobGet();
endinterface

module mkMergeCompleter(MergeCompleter);
	FIFO#(Job) jobFifo <- mkFIFO();
	FIFO#(MergeEntryAddr) addrFifo <- mkSizedFIFO(valueOf(NumEntries));
	Reg#(UInt#(TAdd#(TLog#(NumEntries), 1))) fifoFill <- mkReg(0);
	FIFO#(MergeEntryAddr) bramReqAddrFifo <- mkFIFO();

	BRAM_Configure bram_cfg = defaultValue;
	bram_cfg.latency = 2;
`ifdef SIM
	BRAM1PortBE#(MergeEntryAddr, MergeBramType, 43) bram <- mkBRAM1ServerBE(bram_cfg);
`else
	BRAM1PortBE#(MergeEntryAddr, MergeBramType, 42) bram <- mkBRAM1ServerBE(bram_cfg);
`endif
	Vector#(PE_COUNT, Reg#(MergeEntryAddr)) peAddr <- replicateM(mkRegU());
	Vector#(PE_COUNT, Reg#(JOBID_TYPE)) peJob <- replicateM(mkRegU());
	Vector#(PE_COUNT, Reg#(Bit#(3))) peJobParamCount <- replicateM(mkReg(0));
	Vector#(PE_COUNT, Reg#(Bit#(3))) peMergeLaunchesOutstanding <- replicateM(mkReg(0));
	Vector#(PE_COUNT, Reg#(MergeJob)) peParentMerge <- replicateM(mkRegU());
	FIFO#(Job) asyncJob <- mkFIFO();
	FIFO#(Job) asyncJobRes <- mkFIFO();
	FIFO#(Tuple2#(MergeJob, Bit#(AXIS_ONCHIP_USERWIDTH))) bendRealityFifo <- mkFIFO();

	rule readoutBram;
		let r <- bram.portA.response.get();
		bramReqAddrFifo.deq();
		if (r.param0valid && r.param1valid && r.param2valid && r.param3valid
`ifdef SIM
			&& r.magic == 0
`endif
		) begin
			// all input results are available
			MergeJob mj;
			if (isValid(r.parent)) begin
				mj = fromMaybe(MergeJob {}, r.parent);
			end else begin
				mj = MergeJob {return_action: ReturnToPE};
			end
			Job j = Job {valid: True, kerneltype: LaunchJob, kernel_id: r.merge_pe, param_count: r.param_count, param0: r.param0, param1: r.param1, param2: r.param2, param3: r.param3, signal_host: False, job_id: 12, return_pe: 0, async: True, merge: mj, parent: tagged Invalid// TODO return
`ifdef SIM
			, magic: 'h0
`endif
			};
			jobFifo.enq(j);
			// mark bram entry as invalid
			let bram_data = MergeBramType {param0valid: False, param1valid: False, param2valid: False, param3valid: False, parent: tagged Invalid};
			bram.portA.request.put(BRAMRequestBE {responseOnWrite: False, address: bramReqAddrFifo.first, datain: bram_data, writeen: 'h7f_ffff_ffff});
			addrFifo.enq(bramReqAddrFifo.first);
			$display("Launch merge job, parameters %x %d %d %d %d", bramReqAddrFifo.first, r.param0, r.param1, r.param2, r.param3);
		end else begin
			$display("Launch merge job not all params availble yet %d %d %d %d", r.param0valid, r.param1valid, r.param2valid, r.param3valid);
		end
	endrule

	rule initialFifoFill if(fifoFill < fromInteger(valueOf(NumEntries)));
		addrFifo.enq(truncate(pack(fifoFill)));
		fifoFill <= fifoFill + 1;
	endrule

	rule asyncJobProcessing if (peMergeLaunchesOutstanding[asyncJob.first.return_pe] > 0);
		let j = asyncJob.first;
		if (peMergeLaunchesOutstanding[j.return_pe] > 0) begin
			asyncJob.deq;
			j.parent = tagged Valid peParentMerge[j.return_pe];
			if (peMergeLaunchesOutstanding[j.return_pe] == -1) begin
				peMergeLaunchesOutstanding[j.return_pe] <= asyncJob.first.merge.merge_param_count - 1;
			end else begin
				peMergeLaunchesOutstanding[j.return_pe] <= peMergeLaunchesOutstanding[j.return_pe] - 1;
			end
			asyncJobRes.enq(j);
		end
	endrule

	rule bendRealityProcessing;
		let m = tpl_1(bendRealityFifo.first);
		let pe = tpl_2(bendRealityFifo.first);
		$display ("bendrealityprocessing %x %x", pe, peMergeLaunchesOutstanding[pe]);
		if (peMergeLaunchesOutstanding[pe] == 0) begin
			peMergeLaunchesOutstanding[pe] <= -1;
			peParentMerge[pe] <= m;
			bendRealityFifo.deq;
			$display("set merge outstanding %x, param count %x", pe, m.merge_param_count);
		end
	endrule

	/*
	Return the BRAM address for a merge job.
	Subsequent calls for the same Job-ID from the same PE has the same address, but only if there was no other Job-ID from that PE inbetween.
	*/
	method ActionValue#(MergeEntryAddr) getAddress(JOBID_TYPE jid, Bit#(AXIS_ONCHIP_USERWIDTH) pe, Bit#(3) merge_param_count);
		if (peJob[pe] == jid && peJobParamCount[pe] < merge_param_count) begin
			$display("JobId %x: return existing merge bram address %x", jid, peAddr[pe]);
			peJobParamCount[pe] <= peJobParamCount[pe] + 1;
			return peAddr[pe];
		end else begin
			addrFifo.deq;
			peJob[pe] <= jid;
			peAddr[pe] <= addrFifo.first;
			peJobParamCount[pe] <= 1;
			$display("JobId %x: return NEW merge bram address %x", jid, addrFifo.first);
			return addrFifo.first;
		end
	endmethod

	method Action releasePe(Bit#(AXIS_ONCHIP_USERWIDTH) pe);
		peJob[pe] <= -1;
	endmethod

	method Action put(JobResult r, Bool writeParent);
		let m = r.merge;
		bramReqAddrFifo.enq(fromMaybe(0,m.bram_addr));
		m.merge_param0 = m.merge_param0 || (m.merge_param_count < 1);
		m.merge_param1 = m.merge_param1 || (m.merge_param_count < 2);
		m.merge_param2 = m.merge_param2 || (m.merge_param_count < 3);
		m.merge_param3 = m.merge_param3 || (m.merge_param_count < 4);
		let writeen = {
`ifdef SIM
			1'h1,
`endif
			1'h1, pack(writeParent), pack(writeParent), pack(writeParent), pack(writeParent), 1,
			pack(m.merge_param0), pack(m.merge_param1), pack(m.merge_param2), pack(m.merge_param3), // 1 byte for every valid
			pack(m.merge_param0), pack(m.merge_param0), pack(m.merge_param0), pack(m.merge_param0), // 8 byte parameters
			pack(m.merge_param0), pack(m.merge_param0), pack(m.merge_param0), pack(m.merge_param0), 
			pack(m.merge_param1), pack(m.merge_param1), pack(m.merge_param1), pack(m.merge_param1), 
			pack(m.merge_param1), pack(m.merge_param1), pack(m.merge_param1), pack(m.merge_param1), 
			pack(m.merge_param2), pack(m.merge_param2), pack(m.merge_param2), pack(m.merge_param2), 
			pack(m.merge_param2), pack(m.merge_param2), pack(m.merge_param2), pack(m.merge_param2), 
			pack(m.merge_param3), pack(m.merge_param3), pack(m.merge_param3), pack(m.merge_param3), 
			pack(m.merge_param3), pack(m.merge_param3), pack(m.merge_param3), pack(m.merge_param3)};
		let bram_data = MergeBramType {param0valid: True, param1valid: True, param2valid: True, param3valid: True, parent: r.parent,
`ifdef SIM
			magic: 0,
`endif
			param0: r.result, param1: r.result, param2: r.result, param3: r.result, param_count: m.merge_param_count, merge_pe: m.merge_pe};
		bram.portA.request.put(BRAMRequestBE {responseOnWrite: True, address: fromMaybe(0,m.bram_addr), datain: bram_data, writeen: writeen});
		if (fromMaybe(MergeJob {return_action: MergeByPE}, r.parent).return_action == Ignore) begin
			$display("write a Ignore as parent to blockram");
		end
	endmethod

	method Action bendReality(MergeJob m, Bit#(AXIS_ONCHIP_USERWIDTH) pe);
		bendRealityFifo.enq(tuple2(m, pe));
	endmethod

	method Action asyncJobReq(Job j);
		asyncJob.enq(j);
	endmethod

	method ActionValue#(Job) asyncJobGet;
		let j = asyncJobRes.first;
		asyncJobRes.deq;
		return j;
	endmethod

	method ActionValue#(Job) get();
		jobFifo.deq;
		$display("Merge: Launch new job");
		return jobFifo.first;
	endmethod
endmodule

endpackage
