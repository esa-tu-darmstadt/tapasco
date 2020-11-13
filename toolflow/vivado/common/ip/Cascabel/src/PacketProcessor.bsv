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
import CascabelConfiguration::*;

interface PacketProcessor;
	(*prefix="S_AXI_CONTROL"*) interface AXI4_Lite_Slave_Rd_Fab#(CONF_AXI_ADDR_WIDTH, CONF_AXI_DATA_WIDTH) ctrl_rd;
	(*prefix="S_AXI_CONTROL"*) interface AXI4_Lite_Slave_Wr_Fab#(CONF_AXI_ADDR_WIDTH, CONF_AXI_DATA_WIDTH) ctrl_wr;

	(*prefix="S_AXI_PACKET"*) interface AXI4_Slave_Rd_Fab#(PACKET_AXI_ADDR_WIDTH, PACKET_AXI_DATA_WIDTH, PACKET_AXI_ID_WIDTH, 0) packet_rd;
	(*prefix="S_AXI_PACKET"*) interface AXI4_Slave_Wr_Fab#(PACKET_AXI_ADDR_WIDTH, PACKET_AXI_DATA_WIDTH, PACKET_AXI_ID_WIDTH, 0) packet_wr;

	(*prefix="M_AXI"*) interface AXI4_Lite_Master_Rd_Fab#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) m_rd;
	(*prefix="M_AXI"*) interface AXI4_Lite_Master_Wr_Fab#(CONFIG_ADDR_WIDTH, CONFIG_DATA_WIDTH) m_wr;

	(* always_enabled *) method Vector#(PE_COUNT, Bool) intr_host();
	(* always_ready, always_enabled *) method Action intr((*port="intr"*) Vector#(PE_COUNT, Bool) data);
endinterface

module mkPacketProcessor(Clock design_clk, Reset design_rstn, PacketProcessor intf);

	CascabelQueue queue <- mkCascabelQueue(design_clk, design_rstn);

	Dispatcher dis <- mkDispatcher(clocked_by design_clk, reset_by design_rstn);

	rule enqJobs;
		let j = queue.first;
		queue.deq;
		dis.put(j);
	endrule

	rule dummyResultFetcher;
		let x <- dis.getResult();
		$display("dummy dequeue result");
	endrule

	method Vector#(PE_COUNT, Bool) intr_host = dis.intr_host;
	
	method Action intr(Vector#(PE_COUNT, Bool) data) = dis.intr(data);

	// Connect Queue control interface
	interface ctrl_rd = queue.ctrl_rd;
	interface ctrl_wr = queue.ctrl_wr;

	// Connect Queue memory interface
	interface packet_rd = queue.packet_rd;
	interface packet_wr = queue.packet_wr;

	// Connect to tapasco architecture
	interface AXI4_Lite_Master_Rd_Fab m_rd = dis.m_rd;
	interface AXI4_Lite_Master_Wr_Fab m_wr = dis.m_wr;
endmodule

endpackage
