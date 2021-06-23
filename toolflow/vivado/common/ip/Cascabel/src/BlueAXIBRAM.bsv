package BlueAXIBRAM;

import BRAM :: *;
import BUtils :: *;

import AXI4_Types :: *;
import AXI4_Slave :: *;
import BlueLib :: *;

interface BlueAXIBRAM#(numeric type addr_width, numeric type data_width, numeric type id_width);
    interface AXI4_Slave_Rd_Fab#(addr_width, data_width, id_width, 0) rd;
    interface AXI4_Slave_Wr_Fab#(addr_width, data_width, id_width, 0) wr;
    method Maybe#(Bit#(addr_width)) write_addr;
endinterface

module mkBlueAXIBRAM#(BRAMServerBE#(Bit#(bram_addr_type_sz), Bit#(bram_data_type_sz), bram_strb_size) bramPort)(BlueAXIBRAM#(addr_width, data_width, id_width));
    AXI4_Slave_Rd#(addr_width, data_width, id_width, 0) slave_rd <- mkAXI4_Slave_Rd(16, 16);
    AXI4_Slave_Wr#(addr_width, data_width, id_width, 0) slave_wr <- mkAXI4_Slave_Wr(16, 16, 16);

    Reg#(Bit#(addr_width)) addr_counter_write <- mkReg(0);
    Reg#(UInt#(9)) transfers_left_write <- mkReg(0);
    Reg#(Bit#(id_width)) cur_id_write <- mkRegU();

    Wire#(Maybe#(Bit#(addr_width))) cur_write_addr <- mkDWire(tagged Invalid);

    rule handleWriteRequest if(transfers_left_write == 0);
        let r <- slave_wr.request_addr.get();
        transfers_left_write <= extend(r.burst_length) + 1;
        addr_counter_write <= r.addr;
        cur_id_write <= r.id;
    endrule

    rule handleWriteData if(transfers_left_write != 0);
        let r <- slave_wr.request_data.get();
        transfers_left_write <= transfers_left_write - 1;
        addr_counter_write <= addr_counter_write + fromInteger(valueOf(TDiv#(data_width, 8)));
        let addr = addr_counter_write >> valueOf(TLog#(TDiv#(data_width, 8)));

        Bit#(bram_addr_type_sz) regNum = zExtend(addr);
        bramPort.request.put(BRAMRequestBE {writeen: zExtend(r.strb), responseOnWrite: False, address: regNum, datain: zExtend(r.data)});
        cur_write_addr <= tagged Valid zExtend(addr);

        if(transfers_left_write == 1) begin
            slave_wr.response.put(AXI4_Write_Rs {id: cur_id_write, resp: OKAY, user: 0});
        end
    endrule

    Reg#(Bit#(addr_width)) addr_counter <- mkReg(0);
    Reg#(UInt#(9)) transfers_left_fetch[2] <- mkCReg(2, 0);
    Reg#(UInt#(9)) transfers_left_send <- mkReg(0);
    Reg#(Bit#(id_width)) cur_id <- mkRegU();

    rule handleReadRequest if(transfers_left_fetch[0] == 0 && transfers_left_send == 0);
        let r <- slave_rd.request.get();
        let transfers_left = extend(r.burst_length) + 1;
        transfers_left_fetch[0] <= transfers_left;
        transfers_left_send <= transfers_left;
        addr_counter <= r.addr;
        cur_id <= r.id;
    endrule

    rule fetch_reads if(transfers_left_fetch[1] != 0);
        transfers_left_fetch[1] <= transfers_left_fetch[1] - 1;
        addr_counter <= addr_counter + fromInteger(valueOf(TDiv#(data_width, 8)));

        let addr = addr_counter >> valueOf(TLog#(TDiv#(data_width, 8)));

        Bit#(bram_addr_type_sz) regNum = zExtend(addr);
        bramPort.request.put(BRAMRequestBE {writeen: 0, responseOnWrite: False, address: regNum, datain: 0});
    endrule

    rule returnReadValue if(transfers_left_send != 0);
        transfers_left_send <= transfers_left_send - 1;
        let data <- bramPort.response.get();

        slave_rd.response.put(AXI4_Read_Rs {data: zExtend(pack(data)), id: cur_id, resp: OKAY, last: transfers_left_send == 1, user: 0});
    endrule

    method write_addr = cur_write_addr;

    interface rd = slave_rd.fab;
    interface wr = slave_wr.fab;
endmodule

endpackage
