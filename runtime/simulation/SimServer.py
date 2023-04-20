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

import itertools
from sys import byteorder
from threading import Event
import SimInterrupt
from io import BytesIO
from grpc_gen import sim_calls_pb2_grpc as sc_grpc
from grpc_gen import sim_calls_pb2 as sc
from grpc_gen import status_core_pb2 as status_core
from SimInterrupt import SimInterrupt
import cocotb
import leb128
from functools import reduce
import queue
from math import ceil

def partition(l, size):
    it = iter(l)
    return iter(lambda: list(itertools.islice(it, size)), [])


class SimServer(sc_grpc.SimRequestServicer):

    def __init__(self, dut, server, axim, axis=None, memory=None):
        self.interrupts: dict[int, SimInterrupt] = dict()

        self.dut = dut
        self.server = server
        self.request_queue = queue.Queue()

        self.axim = axim
        self.axis = axis
        self.status_base = 0x0010000000

        self.status = None
        self.memory = memory

        self.status_read_event = Event()
        self.request_queue.put((cocotb.create_task(self._get_status_init()), lambda: self.status_read_event.set()))

    def _request_coroutine(self, func) -> Event:
        event = Event()
        self.request_queue.put((cocotb.create_task(func), lambda: event.set()))
        return event

    async def _get_status_init(self):
        datawidth = len(self.axim.bus.WDATA)
        status_size = 2**13

        bytes_left = status_size
        data = []
        while bytes_left > 0:
            length = min(bytes_left, 256*4)
            _, newdata, _ = await self.axim.read(self.status_base+(status_size-bytes_left), 256, n_bytes=4)
            data.extend(newdata)
            bytes_left -= length

        byte_str = reduce(lambda acc, next_val: acc + next_val.to_bytes(4, byteorder="little"), data, bytes(0))
        (size, read) = leb128.u.decode_reader(BytesIO(byte_str))
        self.status = status_core.Status()
        self.status.ParseFromString(byte_str[read:read + size])

    async def _start_pe_coro(self, pe_id):
        if self.status is not None:
            pe = self.status.pe[pe_id]
            await self.axim.write(self.status.arch_base.base + pe.offset, [0x1])

    async def _set_arg(self, pe_id, arg_n, arg, is_single32):
        if self.status is not None:
            pe = self.status.pe[pe_id]
            await self.axim.write(self.status.arch_base.base + pe.offset + 0x20 + arg_n * 0x10, [arg])

    async def _get_return(self, pe_id, get_return_response):
        if self.status is not None:
            pe = self.status.pe[pe_id]
            _, data, _ = await self.axim.read(self.status.arch_base.base + pe.offset + 0x10, 1)
            get_return_response.value = data

    async def _read_memory(self, addr, length, values):
        await cocotb.triggers.ReadOnly()
        values.extend(self.memory[addr:addr+length])

    async def _write_memory(self, addr, data):
        await cocotb.triggers.ReadOnly()
        for i, value in enumerate(data):
            self.memory[addr+i] = value.to_bytes(4, byteorder="little")[0]

    async def _read_platform(self, addr, read_platform_response, num_bytes):
        _bytes_left = num_bytes
        # contains 32bit wide values returned by axi read
        _data = []
        _addr = addr
        # bytes per burst
        _n_bytes = len(self.axim.bus.RDATA) // 8 # should be 4
        while _bytes_left > 0:
            # address offset calculation for next transfer
            _addr = _addr + num_bytes - _bytes_left

            # burst_length depends on num_bytes and bytes_left
            # max burst length is 256
            # burst length is either derived by max burst length or bytes left to read. 
            _burst_length = ceil(min(_bytes_left, 256 * _n_bytes) / _n_bytes)

            # since sometimes we need to read more bytes than there are left and narrow bursts are not (yet) supported,
            # valid bytes corresponds to the amount of the bytes we want in this transfer
            _valid_bytes = min(_bytes_left, _burst_length * _n_bytes)

            # perform actual memory access
            _, _newdata, _ = await self.axim.read(_addr, _burst_length, n_bytes=_n_bytes)

            # test with length one. Needs to be adjusted to support variable length bursts for last burst in request
            # _data.extend(_newdata[0].to_bytes(4, byteorder="little")[:_valid_bytes])
            _data.extend(reduce(lambda acc, word: acc + word.to_bytes(4, byteorder="little"), _newdata, bytes(0))[:_valid_bytes])

            # bytes_left is decreased by _burst_length * bus_width / 8 i.e. _burst_length * 4
            _bytes_left -= _valid_bytes

        read_platform_response.value.extend(_data)

    async def _write_platform(self, addr, value, is_single32):
        transformed_value = value
        if not is_single32:
            transformed_value = list()
            for val in value:
                transformed_value.extend([int.from_bytes(val.to_bytes(8, byteorder="little")[:4], byteorder="little"), int.from_bytes(val.to_bytes(8, byteorder="little")[4:8], byteorder="little")])

        beats_per_burst = 256
        for burst_num, burst in enumerate(partition(transformed_value, beats_per_burst)):
            await self.axim.write(addr+4*beats_per_burst*burst_num, burst)

    def write_memory(self, request, context):
        resp = sc.SimResponse()
        event = Event()
        resp.void.SetInParent()
        self.request_queue.put(
                (cocotb.create_task(self._write_memory(request.addr, request.data)), lambda: event.set()))
        event.wait()
        return resp

    def read_memory(self, request, context):
        resp = sc.SimResponse(type=sc.SimResponseType.Okay)
        resp.read_memory_response.SetInParent()
        event = Event()
        self.request_queue.put(
            (cocotb.create_task(self._read_memory(request.addr, request.length, resp.read_memory_response.value)), lambda: event.set())
        )
        event.wait()
        return resp

    def read_platform(self, request, context):
        resp = sc.SimResponse(type=sc.SimResponseType.Okay)
        event = Event()
        self.request_queue.put((cocotb.create_task(self._read_platform(request.addr, resp.read_platform_response, request.num_bytes)), lambda: event.set()))
        event.wait()
        return resp

    def write_platform(self, request, context):
        resp = sc.SimResponse(type=sc.SimResponseType.Okay)
        resp.void.SetInParent()
        whichoneof = request.WhichOneof("data")
        event = Event()
        self.request_queue.put((cocotb.create_task(self._write_platform(request.addr, getattr(request, whichoneof).value, whichoneof == "u_32")), lambda: event.set()))
        event.wait()
        return resp

    def register_interrupt(self, request, context):
        if request.fd in self.interrupts.keys():
            self.interrupts[request.fd].deregister_interrupt()

        self.interrupts[request.fd] = SimInterrupt(self.dut, f'ext_intr_PE_{request.interrupt_id}_0')
        self.request_queue.put(
            (self.interrupts[request.fd].get_cocotb_task(), lambda: None))

        return sc.SimResponse(type=sc.SimResponseType.Okay, void=sc.Void())

    def deregister_interrupt(self, request, context):
        self.interrupts.pop(request.fd)
        return sc.SimResponse(type=sc.SimResponseType.Okay, void=sc.Void())

    # reading and parsing can be delegated to runtime, use write platform
    def get_status(self, request, context):
        sim_response = sc.SimResponse()
        if self.status is None:
            self.status_read_event.wait()
        sim_response.status.CopyFrom(self.status)
        sim_response.type = sc.SimResponseType.Okay
        return sim_response

    def get_interrupt_status(self, request, context):
        resp = sc.SimResponse()

        if request.fd in self.interrupts.keys():
            ints = self.interrupts[request.fd].get_interrupt_count()
            self.interrupts[request.fd].clear_interrupt()
            resp.type = sc.SimResponseType.Okay
            resp.interrupt_status.interrupts = ints
        else:
            resp.type = sc.SimResponseType.Error
            resp.error_reason = f"Interrupt id {request.fd} is not registered"

        return resp

