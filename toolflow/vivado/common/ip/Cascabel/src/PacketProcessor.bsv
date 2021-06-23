package PacketProcessor;

import GetPut::*;
import Connectable::*;
import Vector::*;
import FIFO::*;
import DReg::*;

import BlueAXI :: *;
import BlueLib :: *;
import CascabelQueue::*;
import CascabelTypes::*;
import Dispatcher::*;
`ifdef ONCHIP
import MergeCompleter::*;
`endif
import CascabelConfiguration::*;

interface PacketProcessor;
	(*prefix="S_AXI_CONTROL"*) interface AXI4_Lite_Slave_Rd_Fab#(CONF_AXI_ADDR_WIDTH, CONF_AXI_DATA_WIDTH) ctrl_rd;
	(*prefix="S_AXI_CONTROL"*) interface AXI4_Lite_Slave_Wr_Fab#(CONF_AXI_ADDR_WIDTH, CONF_AXI_DATA_WIDTH) ctrl_wr;

	(*prefix="S_AXI_PACKET"*) interface AXI4_Slave_Rd_Fab#(PACKET_AXI_ADDR_WIDTH, PACKET_AXI_DATA_WIDTH, PACKET_AXI_ID_WIDTH, 0) packet_rd;
	(*prefix="S_AXI_PACKET"*) interface AXI4_Slave_Wr_Fab#(PACKET_AXI_ADDR_WIDTH, PACKET_AXI_DATA_WIDTH, PACKET_AXI_ID_WIDTH, 0) packet_wr;

	(*prefix="M_AXI"*) interface AXI4_Lite_Master_Rd_Fab#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) m_rd;
	(*prefix="M_AXI"*) interface AXI4_Lite_Master_Wr_Fab#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) m_wr;
`ifdef ONCHIP
	(*prefix="ONCHIP_IN"*) interface AXI4_Stream_Rd_Fab#(AXIS_ONCHIP_IN_DATAWIDTH, AXIS_ONCHIP_USERWIDTH) onchip_in;
	(*prefix="ONCHIP_OUT"*) interface AXI4_Stream_Wr_Fab#(AXIS_ONCHIP_OUT_DATAWIDTH, AXIS_ONCHIP_USERWIDTH) onchip_out;
`endif

	(* always_enabled *) method Vector#(PE_COUNT, Bool) intr_host();
	(* always_ready, always_enabled *) method Action intr((*port="intr"*) Vector#(PE_COUNT, Bool) data);
endinterface

module mkPacketProcessor(Clock design_clk, Reset design_rstn, PacketProcessor intf);

	CascabelQueue queue <- mkCascabelQueue(design_clk, design_rstn);

	Dispatcher dis <- mkDispatcher(clocked_by design_clk, reset_by design_rstn);

`ifdef ONCHIP
	let stream_out <- mkAXI4_Stream_Wr(16,clocked_by design_clk, reset_by design_rstn);
	let stream_input <- mkAXI4_Stream_Rd(16,clocked_by design_clk, reset_by design_rstn);
	let mergeUnit <- mkMergeCompleter(clocked_by design_clk, reset_by design_rstn);
	FIFO#(Job) asyncQueue <- mkFIFO(clocked_by design_clk, reset_by design_rstn);
`endif

	rule enqJobs;
		let j = queue.first;
		queue.deq;
`ifdef ONCHIP
		if (j.merge.return_action == MergeByPE && !isValid(j.merge.bram_addr)) begin
			let bram_addr <- mergeUnit.getAddress(j.job_id, j.return_pe, j.merge.merge_param_count);
			j.merge.bram_addr = tagged Valid bram_addr;
			$display("requested bram_addr %x", bram_addr);
		end else if (j.merge.return_action == MergeByPE) begin
			$display("Valid merge bram_addr found");
		end
`endif
		dis.put(j);
	endrule

`ifdef ONCHIP
	rule finalizeJob;
		let r <- dis.getResult();
		$display("PacketProcessor: got a result %d", r.result);
		if (r.result == mERGE_RETURN_MAGIC) begin
			mergeUnit.bendReality(r.merge, r.running_pe);
			if (r.merge.return_action == MergeByPE) begin
				// store result anyway, otherwise we will loose the merge parent
				r.merge.merge_param0 = False;
				r.merge.merge_param1 = False;
				r.merge.merge_param2 = False;
				r.merge.merge_param3 = False;
				mergeUnit.put(r, True);
			end
		end else if (r.merge.return_action == ReturnToPE) begin
			$display("PacketProcessor: got a result, return to PE");
			let pkg = AXI4_Stream_Pkg {data: pack(r.result), user: 0, keep: 'hFF, dest: r.return_pe, last: True};
			stream_out.pkg.put(pkg);
		end else if (r.merge.return_action == MergeByPE) begin
			$display("PacketProcessor: got a result, forward to mergeUnit");
			mergeUnit.put(r, isValid(r.parent));
		end else begin
			$display("PacketProcessor: Result not handled, is probably of type Ignore");
		end
	endrule

	rule enqueueMergeJob;
		let j <- mergeUnit.get();
		queue.enq(j);
	endrule

	rule enqeueOnChipJob;
		let p <- stream_input.pkg.get();
		Job j = unpack(truncate(p.data));
		j.valid = True;
		if (j.return_pe == -1) begin
			j.return_pe = p.user;
		end
		if (j.async) begin
			asyncQueue.enq(j);
			mergeUnit.asyncJobReq(j);
		end else begin
			queue.enq(j);
		end
	endrule

	rule asyncJobReturn;
		let j = asyncQueue.first;
		asyncQueue.deq;
		let j2 <- mergeUnit.asyncJobGet();
		queue.enq(j2);
	endrule
`else
	rule dummyResultFetcher;
		let x <- dis.getResult();
		$display("dummy dequeue result");
	endrule
`endif

	method Vector#(PE_COUNT, Bool) intr_host = dis.intr_host;
	
	method Action intr(Vector#(PE_COUNT, Bool) data) = dis.intr(data);

	// Connect Queue control interface
	interface ctrl_rd = queue.ctrl_rd;
	interface ctrl_wr = queue.ctrl_wr;

	// Connect Queue memory interface
	interface packet_rd = queue.packet_rd;
	interface packet_wr = queue.packet_wr;

`ifdef ONCHIP
	// Connect on-chip launching
	interface AXI4_Stream_Rd_Fab onchip_in = stream_input.fab;
	interface AXI4_Stream_Wr_Fab onchip_out = stream_out.fab;
`endif

	// Connect to tapasco architecture
	interface AXI4_Lite_Master_Rd_Fab m_rd = dis.m_rd;
	interface AXI4_Lite_Master_Wr_Fab m_wr = dis.m_wr;
endmodule

endpackage
