# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
#
# This file is part of TaPaSCo
# (see https://github.com/esa-tu-darmstadt/tapasco).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

from typing import List
import cocotb
from cocotb import simulator
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

from grpc import server as grpc_server
from threading import Thread
from grpc_gen import sim_calls_pb2_grpc as sc_grpc
from SimServer import SimServer
from concurrent import futures
from amba import AXI4Master, AXI4Slave

import os

CLK_PERIOD = 10

sim_server = None
run_servicer = True

def run_server(dut, axim, memory):
    """Main method for the gRPC server thread.
    Parameters
    ----------
    dut: cocotb.handle.HierarchyObject
        Handle to the TaPaSCo design provided by cocotb. Needed for the initialization of the SimServer.
    axim: amba.AXI4Master
        AXI4 master interface used to transfer data to and from the design
    memory: bytearray
        Memory of size 1 GiB connected to the AXI4 slaveof the TaPaSCo design.
    """
    global sim_server
    server = grpc_server(futures.ThreadPoolExecutor(max_workers=10))
    sim_server = SimServer(dut, axim, memory)
    sc_grpc.add_SimRequestServicer_to_server(sim_server, server)
    server.add_insecure_port(f"[::]:{os.environ['SIM_PORT']}")
    server.start()
    print('started server')
    server.wait_for_termination()
    print('terminated server')


async def request_servicer():
    """Helper coroutine for scheduling coroutines with cocotb from the gRPC server thread.
    """
    global sim_server
    while run_servicer:
        await Timer(400, units="ns")
        if sim_server is not None and not sim_server.request_queue.empty():
            coro, callback = sim_server.request_queue.get()
            cocotb.start_soon(request_coroutine(coro, callback))


async def request_coroutine(coro, cb):
    """Helper wrapper for coroutines
    """
    task = await cocotb.start(coro)
    await task
    cb()


@cocotb.test()
async def sim_entry(dut):
    """
    main entry point into the simulation. It runs until the make process is ended by a user interrupt or an exception occurs
    """

    # start the clock at 100MHZ
    # the external clock to the composition is hard coded to be ext_ps_clk_in
    cocotb.start_soon(Clock(dut.ext_ps_clk_in, CLK_PERIOD, units="ns").start())

    # on synthesized designs waiting for stable clock is not necessary, as it happens almost instantly
    # the output clocks need to be stable for the respective resets of the clocks and interrupts subsystem
    # to work correctly
    # the sim platform therefore configures the clocking wizard with the locked output, signaling when its
    # output clocks are stable
    await RisingEdge(dut.locked)

    # the axi4 master port is called S_AXI, since, when the composition is viewed as a ip-core, the external
    # port would have the mode Slave
    # thanks to axi smartconnects the associated bus clock is simply dut.ext_ps_clk_in
    axim = AXI4Master(dut, 'S_AXI', dut.ext_ps_clk_in, dut.ext_reset_in)

    memory = bytearray(2**30)

    # same reason as with the axi master
    axis = AXI4Slave(dut, 'M_AXI', dut.ext_ps_clk_in, dut.ext_reset_in, memory, big_endian=False)

    dut.ext_reset_in.value = 0
    await Timer(CLK_PERIOD * 12, units="ns")
    dut.ext_reset_in.value = 1
    await Timer(CLK_PERIOD * 120, units="ns")

    server_thread = Thread(target=run_server, args=(dut, axim, memory))
    server_thread.start()

    task = await cocotb.start(request_servicer())
    # lets the parent process know, that the simulation has been successfully started
    cocotb.log.info('[tapasco-message] simulation-started')
    await task.join()
