# Copyright (c) 2014 Potential Ventures Ltd
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Potential Ventures Ltd,
#       SolarFlare Communications Inc nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL POTENTIAL VENTURES LTD BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Modified by Embedded Systems and Application Group at Technichal University
# Darmstadt 2022
# esa.informatik.tu-darmstadt.de

"""Drivers for Advanced Microcontroller Bus Architecture."""

from math import log2
import cocotb
from cocotb.utils import get_sim_time
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Lock, NextTimeStep
from cocotb_bus.drivers import BusDriver
from cocotb.queue import Queue, QueueEmpty
from random import randint
from axi_types import *
from typing import List
from functools import partial


class AXIProtocolError(Exception):
    pass


axi4_lite_signals = [
    "AWVALID", "AWADDR", "AWREADY", "AWPROT",       # Write address channel
    "WVALID", "WREADY", "WDATA", "WSTRB",           # Write data channel
    "BVALID", "BREADY", "BRESP",                    # Write response channel
    "ARVALID", "ARADDR", "ARREADY", "ARPROT",       # Read address channel
    "RVALID", "RREADY", "RRESP", "RDATA"            # Read data channel
]

axi4_additional_signals = [
    "WLAST",
    "RLAST",
    "ARSIZE",
    "AWSIZE",
    "ARBURST",
    "AWBURST",
    "ARLEN",
    "AWLEN",
    "ARLOCK",
    "AWLOCK",
    "ARCACHE",
    "AWCACHE",
    "ARPROT",
    "AWPROT"
]

axi4_id_signals = [
    "ARID",
    "RID",
    "AWID",
    "BID"
]

async def wait_cycles(clk, n_cycles):
    for i in range(0, n_cycles):
        await RisingEdge(clk)

def log(msg):
    print("[{}]: {}".format(get_sim_time("ns"), msg))

class AXI4LiteMaster(BusDriver):
    """AXI4-Lite Master.
    """

    def __init__(self, entity, name, clock, reset, signals=None, n_inflight=0, random_delay=0, **kwargs):
        """
        Create AXI4-Lite master which can be used as BFM for driver classes.

        Args:
            entity (cocotb.handle.SimHandleBase): Object in the hierarchy to which we are connecting, e.g. `cocotb.top`.
            name (str): Name of the connecting slave interface at the simulation entity.
            clock (cocotb.handle.SimHandleBase): ACLK signal handle driving the AXI interface.
            reset (cocotb.handle.SimHandleBase): ARESETN signal handle for bus resets.
            signals (list, optional): List of supported AXI signals, mainly used to extend the lite slave to a full AXI4 slave.. Defaults to None.
            n_inflight (int, optional): Number of elements in request, data and response FIFOs. Leave at 0 for infinite size, use some small value to potentially encounter some blocking. Defaults to 0.
            random_delay (int, optional): Random delay for handling responses. Defaults to 0.
        """
        self._signals = axi4_lite_signals if signals is None else signals
        BusDriver.__init__(self, entity, name, clock, **kwargs)
        self.reset = reset
        # Drive some sensible defaults (setimmediatevalue to avoid x asserts)
        self.bus.AWVALID.setimmediatevalue(0)
        self.bus.WVALID.setimmediatevalue(0)
        self.bus.ARVALID.setimmediatevalue(0)
        self.bus.BREADY.setimmediatevalue(1)
        self.bus.RREADY.setimmediatevalue(1)

        # Queues for relevant transfer data
        self.n_inflight = n_inflight # used during reset
        self.read_requestQueue = Queue(n_inflight)
        self.read_responseQueue = Queue(n_inflight)
        self.write_requestQueue = Queue(n_inflight)
        self.write_dataQueue = Queue(n_inflight)
        self.write_responseQueue = Queue(n_inflight)

        # optionally randomly delay transfers
        self.random_delay = random_delay
        self.open_read_request = False
        self.open_write_request = False

        # Mutex for each channel that we master to prevent contention
        self.write_busy = Lock("%s_wabusy" % name)
        self.read_busy = Lock("%s_rabusy" % name)
        self.write_data_busy = Lock("%s_wbusy" % name)

        self.n_lanes = len(self.bus.WDATA) // 8 # byte width of data bus (used for strb computation)

        cocotb.start_soon(self.reset_bus())
        # we store these because we need to actively kill them upon reset
        self.start_channels()

    def start_channels(self):
        self.ar_coroutine = cocotb.start_soon(self.ar_channel())
        self.r_coroutine = cocotb.start_soon(self.r_channel())
        self.aw_coroutine = cocotb.start_soon(self.aw_channel())
        self.w_coroutine = cocotb.start_soon(self.w_channel())
        self.b_coroutine = cocotb.start_soon(self.b_channel())

    async def read(self, addr, prot=AXPROT.UNPRIV_SEC_DATA):
        """
        Blocking read from the provided address.

        Args:
            addr (int): Address from which to read.
            prot (AXPROT, optional): AXI4 protection level. Defaults to AXPROT.UNPRIV_SEC_DATA.

        Returns:
            Tuple[XRESP, int]: Tuple containing AXI response and data for the transfer.
        """
        rsp = None
        while rsp is None:
            await self.read_busy.acquire()
            await self.read_requestQueue.put((addr, prot))
            self.open_read_request = True
            self.read_busy.release()
            rsp, data = await self.read_responseQueue.get()
            await self.read_busy.acquire()
            self.open_read_request = False
            self.read_busy.release()
        return rsp, data

    async def write(self, addr, data, prot=AXPROT.UNPRIV_SEC_DATA):
        """
        Blocking write to the provided address.

        Args:
            addr (int): Target address
            data (int): Write data.
            prot (AXPROT, optional): AWPROT value. Defaults to AXPROT.UNPRIV_SEC_DATA.

        Returns:
            XRESP: Write response.
        """
        rsp = None
        while rsp is None:
            await self.write_busy.acquire()
            await self.write_requestQueue.put((addr, prot))
            nibble = addr % self.n_lanes
            wstrb = (2**self.n_lanes - 1) - (2**nibble - 1)
            await self.write_dataQueue.put((data, wstrb))
            self.open_write_request = True
            self.write_busy.release()
            rsp = await self.write_responseQueue.get()
            await self.write_busy.acquire()
            self.open_write_request = False
            self.write_busy.release()
        return rsp

    async def reset_bus(self):
        while True:
            await FallingEdge(self.reset)
            self.ar_coroutine.kill()
            self.r_coroutine.kill()
            self.aw_coroutine.kill()
            self.w_coroutine.kill()
            self.b_coroutine.kill()
            self.bus.AWVALID.setimmediatevalue(0)
            self.bus.WVALID.setimmediatevalue(0)
            self.bus.ARVALID.setimmediatevalue(0)

            # handle requests which got aborted by bus reset
            await self.read_busy.acquire()
            self.read_requestQueue._init(self.n_inflight)
            self.read_responseQueue._init(self.n_inflight)
            if self.open_read_request:
                await self.read_responseQueue.put((None, None))
            self.read_busy.release()
            await self.write_busy.acquire()
            self.write_requestQueue._init(self.n_inflight)
            self.write_dataQueue._init(self.n_inflight)
            self.write_responseQueue._init(self.n_inflight)
            if self.open_write_request:
                await self.write_responseQueue.put(None)
            self.write_busy.release()
            await RisingEdge(self.reset)
            await RisingEdge(self.clock)
            await FallingEdge(self.clock) # we need to wait an entire cycle before asserting any valids
            self.start_channels()
            print("Master reset finished")


    #### READING DATA ####
    async def ar_channel(self):
        while True:
            addr, prot = await self.read_requestQueue.get()
            if not self.bus.ARVALID.value:
                await wait_cycles(self.clock, randint(0, self.random_delay))
            self.bus.ARVALID.value = True
            self.bus.ARADDR.value = addr
            self.bus.ARPROT.value = prot.value
            await RisingEdge(self.clock)
            while not self.bus.ARREADY.value:
                await RisingEdge(self.clock)
            print(f"[{cocotb.utils.get_sim_time(units='ns')}] Accepted AR req")
            self.bus.ARVALID.value = not self.read_requestQueue.empty()

    async def r_channel(self):
        while True:
            self.bus.RREADY.value = not self.read_responseQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.RREADY.value: # We just go back to evaluating our own handshake signal
                continue
            while not self.bus.RVALID.value:
                await RisingEdge(self.clock)
            print(f"[{cocotb.utils.get_sim_time(units='ns')}] Accepted R rsp")
            rsp = XRESP(self.bus.RRESP.value.integer)
            data = self.bus.RDATA.value.integer
            await self.read_responseQueue.put((rsp, data))

    #### WRITING DATA ####
    async def aw_channel(self):
        while True:
            addr, prot = await self.write_requestQueue.get()
            if not self.bus.AWVALID.value:
                await wait_cycles(self.clock, randint(0, self.random_delay))
            await RisingEdge(self.clock)
            print("Assert AWVALID")
            self.bus.AWVALID.value = True
            self.bus.AWADDR.value = addr - (addr % self.n_lanes) # provide aligned address, STRBs handle unalignment
            self.bus.AWPROT.value = prot.value
            #await RisingEdge(self.clock)
            while True:
                await ReadOnly()
                if self.bus.AWREADY.value:
                    break
                await RisingEdge(self.clock)
            print(f"[{cocotb.utils.get_sim_time(units='ns')}] Accepted AW req")
            await RisingEdge(self.clock)
            print("Deassert AWVALID")

            self.bus.AWVALID.value = False

    async def w_channel(self):
        while True:
            data, strb = await self.write_dataQueue.get()
            if not self.bus.WVALID.value:
                await wait_cycles(self.clock, randint(0, self.random_delay))
            self.bus.WVALID.value = True
            self.bus.WDATA.value = data
            self.bus.WSTRB.value = strb
            await RisingEdge(self.clock)
            while not self.bus.WREADY.value:
                await RisingEdge(self.clock)
            print(f"[{cocotb.utils.get_sim_time(units='ns')}] Accepted W data")
            self.bus.WVALID.value = False#not self.write_dataQueue.empty()

    async def b_channel(self):
        while True:
            self.bus.BREADY.value = not self.write_responseQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.BREADY.value:
                continue
            while not self.bus.BVALID.value:
                await RisingEdge(self.clock)
            print(f"[{cocotb.utils.get_sim_time(units='ns')}] Accepted B rsp")
            rsp = XRESP(self.bus.BRESP.value.integer)
            await self.write_responseQueue.put(rsp)

class AXI4LiteSlave(BusDriver):
    """
    Class implementing simple AXI4 Lite slave.

    An instance can either run as a standalone reactive slave if a `bytearray` serving as `memory` is provided.
    Otherwise it is supposed to be used as a BFM which needs to be handled by some reactive slave testbench components, e.g. a reactive
    slave agent in UVM.
    """
    def __init__(self, entity, name, clock, reset, memory: bytearray=None, signals=None, n_inflight=0, random_delay=0, **kwargs):
        """
        Create AXI4 lite slave.

        Args:
            entity (cocotb.handle.SimHandleBase): The simulation object holding the master interface connecting to this slave.
            name (str): Name of the simulated master interface at the `entity`.
            clock (cocotb.handle.SimHandleBase): ACLK handle or the general clock driving the module.
            reset (cocotb.handle.SimHandleBase): ARESETN handle or the general active low reset for the module.
            memory (bytearray, optional): Simulated memory which is accessed by the DUT master. Defaults to None.
            signals (List[str], optional): Additional signals, leave blank for AXI4 Lite slave. Defaults to None.
            n_inflight (int, optional): Size of FIFOs for requests, data and responses, leave at 0 for infinite size. Defaults to 0.
            random_delay (int, optional): Max number of random cycles between serving beats. Defaults to 0.
        """
        self._signals = axi4_lite_signals if signals is None else signals
        BusDriver.__init__(self, entity, name, clock, **kwargs)

        self.reset = reset
        # Drive some sensible defaults (setimmediatevalue to avoid x asserts)
        self.bus.AWREADY.setimmediatevalue(1)
        self.bus.WREADY.setimmediatevalue(1)
        self.bus.ARREADY.setimmediatevalue(1)
        self.bus.BVALID.setimmediatevalue(0)
        self.bus.RVALID.setimmediatevalue(0)

        # Queues for relevant transfer data
        self.n_inflight = n_inflight # used during reset
        self.read_requestQueue = Queue(n_inflight)
        self.read_responseQueue = Queue(n_inflight)
        self.write_requestQueue = Queue(n_inflight)
        self.write_dataQueue = Queue(n_inflight)
        self.write_responseQueue = Queue(n_inflight)

        # max random delay in cycles
        self.random_delay = random_delay

        # if memory is provided the slave will handle the transaction itself, otherwise it exposes queues for
        # an external entity to handle the requests
        self.memory = None
        if memory is not None:
            self.memory = memory

        self.start_channels()
        cocotb.start_soon(self.reset_bus())


    def start_channels(self):
        self.ar_coroutine = cocotb.start_soon(self.ar_channel())
        self.r_coroutine = cocotb.start_soon(self.r_channel())
        self.aw_coroutine = cocotb.start_soon(self.aw_channel())
        self.w_coroutine = cocotb.start_soon(self.w_channel())
        self.b_coroutine = cocotb.start_soon(self.b_channel())
        if self.memory is not None:
            self.mem_coroutine = cocotb.start_soon(self.handle_mem_req())

    async def reset_bus(self):
        while True:
            await FallingEdge(self.reset)
            self.ar_coroutine.kill()
            self.r_coroutine.kill()
            self.aw_coroutine.kill()
            self.w_coroutine.kill()
            self.b_coroutine.kill()
            if self.memory is not None:
                self.mem_coroutine.kill()
            self.bus.BVALID.setimmediatevalue(0)
            self.bus.RVALID.setimmediatevalue(0)
            self.read_requestQueue._init(self.n_inflight)
            self.read_responseQueue._init(self.n_inflight)
            self.write_requestQueue._init(self.n_inflight)
            self.write_dataQueue._init(self.n_inflight)
            self.write_responseQueue._init(self.n_inflight)
            await RisingEdge(self.reset)
            await RisingEdge(self.clock)
            await FallingEdge(self.clock)
            self.start_channels()
            print("Slave reset finished")

    async def ar_channel(self):
        while True:
            self.bus.ARREADY.value = not self.read_requestQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.ARREADY.value:
                continue
            while not self.bus.ARVALID.value:
                await RisingEdge(self.clock)
            araddr = self.bus.ARADDR.value.integer
            arprot = AXPROT(self.bus.ARPROT.value.integer)
            await self.read_requestQueue.put((araddr, arprot))

    async def r_channel(self):
        while True:
            rsp, rdata = await self.read_responseQueue.get()
            if not self.bus.RVALID.value:
                await wait_cycles(self.clock, randint(0, self.random_delay))
            self.bus.RVALID.value = True
            self.bus.RRESP.value = rsp.value
            self.bus.RDATA.value = rdata
            await RisingEdge(self.clock)
            while not self.bus.RREADY.value:
                await RisingEdge(self.clock)
            self.bus.RVALID.value = not self.read_responseQueue.empty()

    async def handle_mem_req(self):
        """
        This method essentially handles the standalone reactive slave behavior. Make this arbitrarily complex in inheriting classes.
        """
        assert self.memory is not None, "Running handle_read_req although slave not self-sustained."
        while True:
            await RisingEdge(self.clock)
            try:
                araddr, _ = self.read_requestQueue.get_nowait()
                # TODO: implement different protection levels for self contained memory (or leave that behaviour up to the memory?)
                # check if address is lower than memory
                if len(self.memory) < araddr - (araddr % 4) + 4:
                    rresp = XRESP.SLVERR
                    rdata = 42
                else:
                    rresp = XRESP.OKAY
                    rdata = int.from_bytes(self.memory[araddr-(araddr % 4):araddr+4], 'little') # read always returns aligned data
                await self.read_responseQueue.put((rresp, rdata))
            except QueueEmpty:
                pass # just want to ensure that write requests in the same cycle are handled
            await FallingEdge(self.clock) # writes occur at the end of cycles in our model
            # Writing
            if not self.write_requestQueue.empty() and not self.write_dataQueue.empty():
                awaddr, _ = self.write_requestQueue.get_nowait()
                wdata, wstrb = self.write_dataQueue.get_nowait() # we don't need to except here, as we know the queues are non-empty
                if len(self.memory) < awaddr - (awaddr % 4) + 4:
                    bresp = XRESP.SLVERR
                else:
                    bresp = XRESP.OKAY
                    wdata_bytes = int.to_bytes(wdata, 4, 'little')
                    lane0_addr = (awaddr // 4) * 4
                    for i in range(0, 4):
                        if wstrb & 1 == 1:
                            self.memory[lane0_addr+i] = wdata_bytes[i]
                        wstrb = wstrb >> 1
                await self.write_responseQueue.put(bresp)

    async def aw_channel(self):
        while True:
            self.bus.AWREADY.value = not self.write_requestQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.AWREADY.value:
                continue
            while not self.bus.AWVALID.value:
                await RisingEdge(self.clock)
            awaddr = self.bus.AWADDR.value.integer
            awprot = AXPROT(self.bus.AWPROT.value.integer)
            await self.write_requestQueue.put((awaddr, awprot))

    async def w_channel(self):
        while True:
            self.bus.WREADY.value = not self.write_dataQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.WREADY.value:
                continue
            while not self.bus.WVALID.value:
                await RisingEdge(self.clock)
            wdata = self.bus.WDATA.value.integer
            wstrb = self.bus.WSTRB.value.integer
            await self.write_dataQueue.put((wdata, wstrb))

    async def b_channel(self):
        while True:
            rsp = await self.write_responseQueue.get()
            # randomly delay the response if we did not have it ready before
            if not self.bus.BVALID.value:
                await wait_cycles(self.clock, randint(0, self.random_delay))
            self.bus.BVALID.value = True
            self.bus.BRESP.value = rsp.value
            await RisingEdge(self.clock)
            while not self.bus.BREADY.value:
                await RisingEdge(self.clock)
            self.bus.BVALID.value = not self.write_responseQueue.empty()


def check_for_id(entity, name):
    """
    Check if provided DUT provides AXI ID signals.

    Args:
        entity (cocotb.handle.SimHandleBase): Handle to simulated object, e.g. ``cocotb.top``.
        name (str): Interface name on the ``entity``.

    Returns:
        bool: `True` if ID signals were found, `False` otherwise.
    """
    bus_signals = [sig[0] for sig in entity._sub_handles.items() if name in sig[0]]
    arid = [arid for arid in bus_signals if "arid" in arid.lower()]
    return len(arid) > 0

# Utility functions for AXI4 full
def _lower_lane0(addr, n_lanes):
    return addr - (addr // n_lanes) * n_lanes

def _lower_laneN(address_n, n_lanes):
    return address_n - (address_n // n_lanes) * n_lanes

def _upper_laneN(lower_lane_n, size):
    return lower_lane_n + size - 1

def _upper_lane0(addr, aligned_addr, size, n_lanes):
    return aligned_addr + (size - 1) - (addr // n_lanes) * n_lanes

def _align_addr(addr, size):
    return (addr // size) * size

def _compute_lanes(aligned_addr, size, data, n_lanes):
    address_n_l = [aligned_addr + (n-1) * size for n in range(1, len(data))]

    lower_lanes = list(map(partial(_lower_laneN, n_lanes=n_lanes), address_n_l))
    upper_lanes = list(map(partial(_upper_laneN, size=size), lower_lanes))
    return lower_lanes, upper_lanes

class AXI4Master(AXI4LiteMaster):
    """
    Full AXI4 Master
    """

    def __init__(self, entity, name, clock, reset, random_delay=0, n_inflight=0):
        """
        Create instance of full master BFM.

        Args:
            entity (cocotb.handle.SimHandleBase): DUT to whose slave we are connecting.
            name (str): Interface name on `entity`.
            clock (cocotb.handle.SimHandleBase): ACLK or other CLK signal handle driving the `entity`.
            reset (cocotb.handle.SimHandleBase): ARESETN or other active low reset signal handle connected to the bus or the `entity`.
            random_delay (int, optional): Not yet implemented random delay for AXI transfers.
            n_inflight (int, optional): FIFO size for request, data or response buffers. Leave at 0 for infinite size, use some positive value for potential blocking. Defaults to 0.
        """
        signals = axi4_lite_signals + axi4_additional_signals
        self._has_id = check_for_id(entity, name)
        if self._has_id:
            signals += axi4_id_signals
        AXI4LiteMaster.__init__(self, entity, name, clock, reset, signals=signals,
                                    n_inflight=n_inflight, random_delay=random_delay)

        # Drive some sensible defaults (setimmediatevalue to avoid x asserts)
        self.bus.WLAST.setimmediatevalue(0)
        self.bus.ARSIZE.setimmediatevalue(0b010) # 4 bytes
        self.bus.AWSIZE.setimmediatevalue(0b010) # 4 bytes
        self.bus.ARBURST.setimmediatevalue(1) # INCR
        self.bus.AWBURST.setimmediatevalue(1) # INCR
        self.bus.ARLEN.setimmediatevalue(0)
        self.bus.AWLEN.setimmediatevalue(0)
        self.bus.ARLOCK.setimmediatevalue(0)
        self.bus.AWLOCK.setimmediatevalue(0)
        self.bus.ARCACHE.setimmediatevalue(0)
        self.bus.AWCACHE.setimmediatevalue(0)
        self.bus.ARPROT.setimmediatevalue(0)
        self.bus.AWPROT.setimmediatevalue(0)
        if self._has_id:
            self.bus.ARID.setimmediatevalue(0)
            self.bus.AWID.setimmediatevalue(0)



    async def write(self, addr: int, data: List[int], burst: AXBURST=AXBURST.INCR, prot: AXPROT=AXPROT.UNPRIV_SEC_DATA, id: int=0):
        """
        Perform burst write of all elements in `data` to the provided address.

        .. note:: This implementation does not provide support for narrow bursts or unaligned transfers, yet. Add it if you need it.

        Args:
            addr (int): Target base address.
            data (List[int]): Beat data to write in the transfers.
            burst (AXBURST, optional): Burst type. Defaults to AXBURST.INCR.
            prot (AXPROT, optional): Protection level. Defaults to AXPROT.UNPRIV_SEC_DATA.
            id (int, optional): Transfer ID, only relevant if the connected interface provides ID signals. Defaults to 0.

        Raises:
            NotImplementedError: Raised when `burst` is set to `AXBURST.WRAP` as this burst mode is not implemented, yet.

        Returns:
            Tuple[XRESP, int]: Tuple containing the write response and the ID for the transfer.
        """
        # size is not AWSIZE, but the number of bytes (appears more user friendly to me)
        size = self.n_lanes # make sure the data fits onto the data bus #TODO: no support for narrow burst yet
        rsp = None
        while rsp is None:
            aligned_addr = _align_addr(addr, size)
            await self.write_busy.acquire()
            await self.write_requestQueue.put((id, aligned_addr, size, len(data), burst, prot))
            # compute strobes
            strbs = []
            lower_lane0 = _lower_lane0(addr, self.n_lanes)
            upper_lane0 = _upper_lane0(addr, aligned_addr, size, self.n_lanes)
            def strb_from_lanes(upper, lower):
                strb = 2**upper
                for i in range(lower, upper):
                    strb = strb | (1 << i)
                return strb
            if burst == AXBURST.FIXED:
                # always set the same lanes
                strb = strb_from_lanes(upper_lane0, lower_lane0)
                strbs = [strb for i in range(0, len(data))]
            elif burst == AXBURST.INCR:
                lower_lanes, upper_lanes = _compute_lanes(aligned_addr, size, data, self.n_lanes)
                lower_lanes.insert(0, lower_lane0)
                upper_lanes.insert(0, upper_lane0)
                strbs = list(map(strb_from_lanes, upper_lanes, lower_lanes))
            elif burst == AXBURST.WRAP:
                raise NotImplementedError("Wrapping bursts not yet supported")

            await self.write_dataQueue.put((data, strbs))
            self.open_write_request = True
            self.write_busy.release()
            rsp = await self.write_responseQueue.get()
            if rsp is not None:
                rsp, id = rsp
            await self.write_busy.acquire()
            self.open_write_request = False
            self.write_busy.release()
        return rsp, id

    async def read(self, addr, length, n_bytes=4, burst=AXBURST.INCR, prot=AXPROT.UNPRIV_SEC_DATA, id=0):
        """
        Blocking read from the provided address. This implementation should support narrow bursts, although they
        are not tested, yet. Use at your own risk!

        Args:
            addr (int): Base address for read start.
            length (int): Number of beats to read.
            n_bytes (int, optional): Number of bytes per beat. Set this to the bus width (in bytes) for non-narrow transfers. Defaults to 4.
            burst (AXBURST, optional): Burst mode. Defaults to AXBURST.INCR.
            prot (AXPROT, optional): Protection mode. Defaults to AXPROT.UNPRIV_SEC_DATA.
            id (int, optional): Transfer ID, only used if the connected interface provides ID signals. Defaults to 0.

        Returns:
            Tuple[XRESP, int, int]: Tuple consisting of transfer response, transfer data and transfer ID.
        """
        rsp = None
        while rsp is None:
            aligned_addr = (addr // n_bytes) * n_bytes # to me it makes not sense to align to the transfer size instead of the bus width
            await self.read_busy.acquire()
            await self.read_requestQueue.put((id, aligned_addr, length, n_bytes, burst, prot))
            self.open_read_request = True
            self.read_busy.release()
            rsp, data, id = await self.read_responseQueue.get()

            await self.read_busy.acquire()
            low0 = _lower_lane0(addr, self.n_lanes)
            upper0 = _upper_lane0(addr, aligned_addr, n_bytes, self.n_lanes)

            lower_lanes, upper_lanes = _compute_lanes(aligned_addr, n_bytes, data, self.n_lanes)
            lower_lanes.insert(0, low0)
            upper_lanes.insert(0, upper0)
            def apply_lanes(word, lower, upper, rsp):
                adjusted = 0
                if rsp == XRESP.OKAY:
                    for i in range(lower, upper+1):
                        mask = 0xFF << (i * 8)
                        adjusted = adjusted | (word & mask)
                return adjusted
            data = list(map(apply_lanes, data, lower_lanes, upper_lanes, rsp))

            self.open_read_request = False
            self.read_busy.release()
            return rsp, data, id

    async def ar_channel(self):
        while True:
            arid, araddr, arlen_add1, n_bytes, burst, prot = await self.read_requestQueue.get()
            await RisingEdge(self.clock)
            self.bus.ARVALID.value = True
            if self._has_id:
                self.bus.ARID.value = arid
            self.bus.ARADDR.value = araddr
            self.bus.ARLEN.value = arlen_add1 - 1
            self.bus.ARSIZE.value = int(log2(n_bytes))
            self.bus.ARBURST.value = burst.value
            self.bus.ARPROT.value = prot.value

            while True:
                await ReadOnly()
                if self.bus.ARREADY.value:
                    break
                await RisingEdge(self.clock)
            await RisingEdge(self.clock)
            self.bus.ARVALID.value = False

    async def r_channel(self):
        responses = {} # dict: channel => (list((rsp, data))), flushed upon rlast
        responses[0] = []
        if self._has_id:
            for i in range(1, 2**len(self.bus.RID)):
                responses[i] = []
        while True:
            self.bus.RREADY.value = not self.read_responseQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.RREADY.value:
                continue
            while not self.bus.RVALID.value:
                await RisingEdge(self.clock)
            rsp = XRESP(self.bus.RRESP.value.integer)
            data = self.bus.RDATA.value.integer
            rid = 0
            if self._has_id:
                rid = self.bus.RID.value.integer
            rlast = self.bus.RLAST.value
            responses[rid].append((rsp, data))
            if rlast:
                rsps, datas = zip(*responses[rid])
                rsps = list(rsps)
                datas = list(datas)
                responses[rid] = [] # flush for next transfer
                await self.read_responseQueue.put((rsps, datas, rid))
            self.bus.RREADY.value = not self.read_responseQueue.full()

    async def aw_channel(self):
        while True:
            awid, awaddr, n_bytes, len_add1, awburst, awprot = await self.write_requestQueue.get()
            await RisingEdge(self.clock)
            self.bus.AWVALID.value = True
            if self._has_id:
                self.bus.AWID.value = awid
            self.bus.AWADDR.value = awaddr
            self.bus.AWSIZE.value = int(log2(n_bytes))
            self.bus.AWLEN.value = len_add1 - 1
            self.bus.AWBURST.value = awburst.value
            self.bus.AWPROT.value = awprot.value
            while True:
                await ReadOnly()
                if self.bus.AWREADY.value:
                    break
                await RisingEdge(self.clock)
            await RisingEdge(self.clock)

            self.bus.AWVALID.value = False

    async def w_channel(self):
        while True:
            wdata, wstrb = await self.write_dataQueue.get()
            for i in range(0, len(wdata)):
                await RisingEdge(self.clock)
                self.bus.WDATA.setimmediatevalue(wdata[i])
                self.bus.WSTRB.setimmediatevalue(wstrb[i])
                self.bus.WVALID.value = True
                self.bus.WLAST.value = i == len(wdata)-1
                while True:
                    await ReadOnly()
                    if self.bus.WREADY.value:
                        break
                    await RisingEdge(self.clock)
                await RisingEdge(self.clock)
                self.bus.WVALID.value = False
            self.bus.WLAST.value = False

    async def b_channel(self):
        while True:
            self.bus.BREADY.value = not self.write_responseQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.BREADY.value:
                continue
            while not self.bus.BVALID.value:
                await RisingEdge(self.clock)
            rsp = XRESP(self.bus.BRESP.value.integer)
            bid = 0
            if self._has_id:
                bid = self.bus.BID.value.integer
            await self.write_responseQueue.put((rsp, bid))


class AXI4Slave(AXI4LiteSlave):
    '''
    AXI4 Slave

    Monitors an internal memory and handles read and write requests.
    '''


    # Not currently supported by this driver
    _optional_signals = [
        "RCOUNT",  "WCOUNT",  "RACOUNT", "WACOUNT",
        "ARLOCK",  "AWLOCK",  "ARCACHE", "AWCACHE",
        "ARQOS",   "AWQOS",   "WID"
    ]

    def __init__(self, entity, name, clock, reset, memory=None, n_inflight=0, random_delay=0, callback=None, event=None,
                 big_endian=False, **kwargs):
        signals = axi4_lite_signals + axi4_additional_signals
        self._has_id = check_for_id(entity, name)
        if self._has_id:
            signals += axi4_id_signals
        AXI4LiteSlave.__init__(self, entity, name, clock, reset, memory, signals, n_inflight=n_inflight, random_delay=random_delay)

        self.callback = callback
        self.n_lanes = len(self.bus.WDATA) // 8 # we assume WDATA width == RDATA width

        self.big_endian = big_endian
        self.bus.ARREADY.setimmediatevalue(0)
        self.bus.RVALID.setimmediatevalue(0)
        self.bus.RLAST.setimmediatevalue(0)
        self.bus.AWREADY.setimmediatevalue(0)
        self.bus.BVALID.setimmediatevalue(0)
        self.bus.BRESP.setimmediatevalue(0)
        self.bus.RRESP.setimmediatevalue(0)
        if self._has_id:
            self.bus.BID.setimmediatevalue(0)
            self.bus.RID.setimmediatevalue(0)


        self.write_address_busy = Lock("%s_wabusy" % name)
        self.read_address_busy = Lock("%s_rabusy" % name)
        self.write_data_busy = Lock("%s_wbusy" % name)

    def start_channels(self):
        self.ar_coroutine = cocotb.start_soon(self.ar_channel())
        self.r_coroutine = cocotb.start_soon(self.r_channel())
        self.aw_coroutine = cocotb.start_soon(self.aw_channel())
        self.w_coroutine = cocotb.start_soon(self.w_channel())
        self.b_coroutine = cocotb.start_soon(self.b_channel())
        if self.memory is not None:
            self.mem_read_coroutine = cocotb.start_soon(self.handle_read_req())
            self.mem_write_coroutine = cocotb.start_soon(self.handle_write_req())

    async def reset_bus(self):
        while True:
            await FallingEdge(self.reset)
            self.ar_coroutine.kill()
            self.r_coroutine.kill()
            self.aw_coroutine.kill()
            self.w_coroutine.kill()
            self.b_coroutine.kill()
            if self.memory is not None:
                self.mem_read_coroutine.kill()
                self.mem_write_coroutine.kill()
            self.bus.BVALID.setimmediatevalue(0)
            self.bus.RVALID.setimmediatevalue(0)
            self.read_requestQueue._init(self.n_inflight)
            self.read_responseQueue._init(self.n_inflight)
            self.write_requestQueue._init(self.n_inflight)
            self.write_dataQueue._init(self.n_inflight)
            self.write_responseQueue._init(self.n_inflight)
            await RisingEdge(self.reset)
            await RisingEdge(self.clock)
            await FallingEdge(self.clock)
            self.start_channels()
            print("Slave reset finished")

    def _size_to_bytes_in_beat(self, AxSIZE):
        if AxSIZE < 7:
            return 2 ** AxSIZE
        return None

    async def ar_channel(self):
        while True:
            self.bus.ARREADY.value = not self.read_requestQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.ARREADY.value:
                continue
            while not self.bus.ARVALID.value:
                await RisingEdge(self.clock)
            araddr = self.bus.ARADDR.value.integer
            arprot = AXPROT(self.bus.ARPROT.value.integer)
            arsize = self.bus.ARSIZE.value.integer
            arburst = AXBURST(self.bus.ARBURST.value.integer)
            arlen = self.bus.ARLEN.value.integer
            arid = 0
            if self._has_id:
                arid = self.bus.ARID.value.integer
            await self.read_requestQueue.put((arid, araddr, arprot, arsize, arlen, arburst))

    async def r_channel(self):
        while True:
            rresp, rdata, rid, rlast = await self.read_responseQueue.get()
            self.bus.RVALID.value = True
            self.bus.RDATA.value = rdata
            if self._has_id:
                self.bus.RID.value = rid
            self.bus.RRESP.value = rresp.value
            self.bus.RLAST.value = rlast
            await RisingEdge(self.clock)
            while not self.bus.RREADY.value:
                await RisingEdge(self.clock)
            self.bus.RVALID.value = not self.read_responseQueue.empty()
            self.bus.RLAST.value = False

    async def handle_read_req(self):
        assert self.memory is not None, "Running handle_read_req although slave not self-sustained."
        while True:
            arid, araddr, arprot, arsize, arlen, arburst = await self.read_requestQueue.get()
            n_beats = arlen + 1
            n_bytes = self._size_to_bytes_in_beat(arsize)
            aligned_addr = (araddr // n_bytes) * n_bytes
            addr_i = aligned_addr
            for i in range(0, n_beats):
                # check if address is within memory capacity
                if addr_i + n_bytes <= len(self.memory):
                    rsp = XRESP.OKAY # ignoring exclusive access for now
                    lane_0_addr = (addr_i // self.n_lanes) * self.n_lanes # we always just put the entire word on the bus. The master has to discard the unused bytes
                    rdata = int.from_bytes(self.memory[lane_0_addr:lane_0_addr+self.n_lanes], 'little')
                else:
                    rsp = XRESP.SLVERR
                    rdata = 42
                await self.read_responseQueue.put((rsp, rdata, arid, i == arlen))
                if arburst != AXBURST.FIXED:
                    addr_i = addr_i + n_bytes
                await FallingEdge(self.clock) # This is to synchronize with writes occurring in the same cycle

    async def aw_channel(self):
        while True:
            self.bus.AWREADY.value = not self.write_requestQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.AWREADY.value:
                continue
            while not self.bus.AWVALID.value:
                await RisingEdge(self.clock)
            awaddr = self.bus.AWADDR.value.integer
            awprot = AXPROT(self.bus.AWPROT.value.integer)
            awsize = self.bus.AWSIZE.value.integer
            awburst = AXBURST(self.bus.AWBURST.value.integer)
            awlen = self.bus.AWLEN.value.integer
            awid = 0
            if self._has_id:
                awid = self.bus.AWID.value.integer
            await self.write_requestQueue.put((awid, awaddr, awprot, awsize, awlen, awburst))

    async def w_channel(self):
        while True:
            self.bus.WREADY.value = not self.write_dataQueue.full()
            await RisingEdge(self.clock)
            if not self.bus.WREADY.value:
                continue
            while not self.bus.WVALID.value:
                await RisingEdge(self.clock)
            wdata = self.bus.WDATA.value.integer
            wstrb = self.bus.WSTRB.value.integer
            wlast = self.bus.WLAST.value
            await self.write_dataQueue.put((wdata, wstrb, wlast))

    async def b_channel(self):
         while True:
            rsp, bid = await self.write_responseQueue.get()
            if not self.bus.BVALID.value:
                await wait_cycles(self.clock, randint(0, self.random_delay))
            self.bus.BVALID.value = True
            self.bus.BRESP.value = rsp.value
            if self._has_id:
                self.bus.BID.value = bid
            await RisingEdge(self.clock)
            while not self.bus.BREADY.value:
                await RisingEdge(self.clock)
            self.bus.BVALID.value = not self.write_responseQueue.empty()

    async def handle_write_req(self):
        while True:
            awid, awaddr, awprot, awsize, awlen, awburst = await self.write_requestQueue.get()
            n_beats = awlen + 1
            n_bytes = self._size_to_bytes_in_beat(awsize)
            addr_i = _align_addr(awaddr, n_bytes)
            for i in range(0, n_beats):
                wdata, wstrb, wlast = await self.write_dataQueue.get()
                await FallingEdge(self.clock) # synchronization for writes in the same cycle
                strb_offset = addr_i % self.n_lanes
                wstrb = wstrb >> strb_offset # Aligned address == 0x2 on 32 bit => only need to look at upper 2 strb bits
                wdata_bytes = int.to_bytes(wdata, self.n_lanes, 'little')
                if addr_i + n_bytes <= len(self.memory):
                    rsp = XRESP.OKAY
                    for j in range(0, n_bytes):
                        if wstrb & 1 == 1:
                            self.memory[addr_i+j] = wdata_bytes[strb_offset + j]
                        wstrb = wstrb >> 1
                else:
                    rsp = XRESP.SLVERR # we still iterate through all beats to handle the entire transfer
                if awburst != AXBURST.FIXED:
                    addr_i += n_bytes
            assert wlast, "Received {}/{} beats but did not see wlast".format(n_beats, n_beats)
            await self.write_responseQueue.put((rsp, awid))

