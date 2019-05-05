/*
 * Register Map:
 *
 * 0x0: Int Pending/ACK 0 - 3 (Plattform/DMA)
 * 0x8: Int Pending/ACK 0 - 63 (User IP 0)
 * 0x10: Int Pending/ACK 64 - 127 (User IP 1)
 *
 * "This interface uses single clock pulses for the req/ack.
 * The CL asserts (active high) cl_sh_apppf_irq_req[x] for a single clock to
 * assert the interrupt request to the SH.
 *
 * The SH will respond with a single clock pulse on sh_cl_apppf_irq_ack[x]
 * to acknowledge the interrupt. Once the CL asserts a request on a particular
 * bit[x], it should not assert a request for the same bit[x] until
 * it has received the ack for bit[x] from the SH. The CL may assert
 * requests on other bits[y] (y!=x).""
 *
 */

package AWSInterruptCtrl;

import AXI4LiteSlave::*;
import AXI4LiteTypes::*;

import ClientServer::*;
import Connectable::*;
import GetPut::*;
import FIFOF::*;
import MIMO::*;
import Vector::*;

import RegFile::*;

typedef 24 DATAW;
typedef 16 ADDRW;

interface AWSInterruptCtrl;

	// use axi4 lite for the configuration registers
	(* prefix = "S_AXI" *)
	interface AXI4_Lite_Slave_Rd_Fab#(ADDRW, DATAW) rd_fab;
	(* prefix = "S_AXI" *)
	interface AXI4_Lite_Slave_Wr_Fab#(ADDRW, DATAW) wr_fab;

	// PEs are connected to this port
	(* always_enabled, result = "intr" *)
	method Action m_intr(Bit#(128) intr);

	// Interrupt requests going to Shell
	(* always_enabled, result = "irq_req" *)
	method Bit#(3) irq_req;

	// Interrupt ACK coming from Shell
	(* always_enabled, result = "irq_ack" *)
	method Action m_ack(Bit#(16) ack);

endinterface

(* synthesize *)
module mkAWSInterruptCtrl(AWSInterruptCtrl);
	//AXI4LiteSlave::AXI4_Lite_Rd rd <- mkAXI4_Lite_Slave_Rd();
	//AXI4LiteSlave::AXI4_Lite_Wr wr <- mkAXI4_Lite_Slave_Wr();

    AXI4_Lite_Slave_Rd#(ADDRW, DATAW) rd <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(ADDRW, DATAW) wr <- mkAXI4_Lite_Slave_Wr(2);

	rule config_write_request;
		let r <- wr.bus.request.get();

		let addr = r.addr & 'hff;
		case (addr)
			// 0x0: Int Pending/ACK 0 - 3 (Plattform/DMA)
			'h00 : begin
				end
			// 0x8: Int Pending/ACK 0 - 63 (User IP 0)
			'h00 : begin
				end
			// Int Pending/ACK 0 - 3 (Plattform/DMA)
			'h00 : begin
				end
		endcase

		$display("SET REGISTER: %d = %d", addr, r.data);
		wr.bus.response.put(AXI4_Lite_Rsp_Wr {resp : OKAY});
	endrule

	rule config_read_request;
		let r <- rd.bus.request.get();

		Bit#(DATAW) rdata = ?;
		let addr = r.addr & 'hff;
		case (addr)
			'h20 : rdata = 0;
		endcase

		rd.bus.response.put(AXI4_Lite_Rsp_Rd {
				data : rdata,
				resp : OKAY
			});
	endrule

	method Action m_ack(Bit#(16) ack);
	endmethod

	interface AXI4LiteSlave::AXI4_Rd_Fab rd_fab = rd.fab;
	interface AXI4LiteSlave::AXI4_Wr_Fab wr_fab = wr.fab;

endmodule

endpackage