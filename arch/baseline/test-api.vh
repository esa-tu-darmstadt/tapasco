//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
`ifndef __TEST_API_VH__
`define __TEST_API_VH__ 1
  // Simple API to write tests:
  `define INTC_BASE			32'h41800000
  `define TARGETIP_BASE 		32'h43C00000
  `define TARGETIP_OFFS 		32'h00010000
  
  task pre_load_mem_from_file;
  input [(1024*8-1):0] filename;
  input [31:0] addr;
  input [31:0] no_bytes;
  begin
   tb.system_i.ps7.inst.ocmc.ocm.pre_load_mem_from_file(
     filename,
     addr,
     no_bytes
   );
  end
  endtask
  
  task setup_system;
  input [7:0] no_inst;
  output [2:0] resp;
  reg [7:0] i;
  reg [31:0] data;
  begin
    // configure slave profiles
    system_i.ps7.inst.set_slave_profile("S_AXI_HP0", 2'b00); // best case
    system_i.ps7.inst.set_slave_profile("S_AXI_ACP", 2'b00); // best case
  
    // setup AXI interrupt controller to receive all irqs
    system_i.ps7.inst.write_data(
      `INTC_BASE + 32'h08, 4, 32'hFFFFFFFF, resp
    );
    system_i.ps7.inst.write_data(
      `INTC_BASE + 32'h1C, 4, 32'h3, resp
    );
    // read ISR
    system_i.ps7.inst.read_data(
      `INTC_BASE, 4, data, resp
    );
  
    for (i = 0; i < no_inst; i = i + 1) begin
      // activate interrupts on first instance of target IP
      system_i.ps7.inst.write_data(
        `TARGETIP_BASE + i * `TARGETIP_OFFS + 32'h04, 4, 32'h1, resp
      );
      system_i.ps7.inst.write_data(
        `TARGETIP_BASE + 32'h08, 4, 32'h1, resp
      );
    end

    $display("--- SYSTEM SETUP FINISHED @ %0d ---", $time);
  end
  endtask
  
  task launch_kernel;
  input [7:0] inst_no;
  output [3:0] irqs;
  reg [2:0] resp;
  begin
    // start run
    system_i.ps7.inst.write_data(
      `TARGETIP_BASE + inst_no * `TARGETIP_OFFS , 4, 32'h1, resp
    );
    
    // wait for ap_done
    system_i.ps7.inst.wait_interrupt( 0, irqs );
  end
  endtask
  
  task read_kernel_reg;
  input [7:0] inst_no;
  input [9:0] register;
  output [31:0] data;
  output [2:0] resp;
  begin
    // read register
    system_i.ps7.inst.read_data(
      `TARGETIP_BASE + inst_no * `TARGETIP_OFFS + (register << 2), 4, data, resp
    );
  end
  endtask
  
  task write_kernel_reg;
  input [7:0] inst_no;
  input [9:0] register;
  input [31:0] data;
  output [2:0] resp;
  begin
    // write register
    system_i.ps7.inst.write_data(
      `TARGETIP_BASE + inst_no * `TARGETIP_OFFS + (register << 2), 4, data, resp
    );
  end
  endtask
  
  task read_mem;
  input [31:0] start_addr;
  input [6:0] no_of_bytes;
  output [1023:0] data;
  begin
    system_i.ps7.inst.ocmc.ocm.read_mem(
      data,
      start_addr,
      no_of_bytes
    );
  end
  endtask
`endif /* __TEST_API_VH__ */
