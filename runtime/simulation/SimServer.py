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

def partition(l, size):
    it = iter(l)
    return iter(lambda: list(itertools.islice(it, size)), [])

#todo: implement class for cocotb related things, to decouple grpc and cocotb


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
        print("==========================")
        print("=== SIMULATION STARTED ===")
        print("==========================")

    def _request_coroutine(self, func) -> Event:
        event = Event()
        self.request_queue.put((cocotb.create_task(func), lambda: event.set()))
        return event

    async def _get_status_init(self):
        print('get status core')
        datawidth = len(self.axim.bus.WDATA)
        status_size = 2**13

        #  ret = [int(await self.axim.read(self.status_base + int(datawidth / 8) * i)) for i in range(int(status_size / (datawidth / 8)))]
        bytes_left = status_size
        data = []
        while bytes_left > 0:
            length = min(bytes_left, 256*4)
            _, newdata, _ = await self.axim.read(self.status_base+(status_size-bytes_left), 256, n_bytes=4)
            data.extend(newdata)
            bytes_left -= length

        #  print(f'read status: {data=}')
        #  byte_str = reduce(lambda acc, next_val: acc + next_val.to_bytes(int(datawidth/8), byteorder='little'), ret, bytes(0))
        byte_str = reduce(lambda acc, next_val: acc + next_val.to_bytes(4, byteorder="little"), data, bytes(0))
        #  print(f'{byte_str=}')
        (size, read) = leb128.u.decode_reader(BytesIO(byte_str))
        #  print(f'{size=}, {read=}')
        self.status = status_core.Status()
        self.status.ParseFromString(byte_str[read:read + size])
        #  print(f'{self.status=}')

    async def _start_pe_coro(self, pe_id):
        #  print('start pe coro')
        if self.status is not None:
            pe = self.status.pe[pe_id]
            #  print(f"start time of pe {pe_id}: {cocotb.utils.get_sim_time(units='ps')}")
            await self.axim.write(self.status.arch_base.base + pe.offset, [0x1])
            #  print("started pe")

    async def _set_arg(self, pe_id, arg_n, arg, is_single32):
        if self.status is not None:
            pe = self.status.pe[pe_id]
            await self.axim.write(self.status.arch_base.base + pe.offset + 0x20 + arg_n * 0x10, [arg])
            #  print(f"wrote argument {arg_n=}, {arg=} of pe {pe_id}")

    async def _get_return(self, pe_id, get_return_response):
        if self.status is not None:
            pe = self.status.pe[pe_id]
            _, data, _ = await self.axim.read(self.status.arch_base.base + pe.offset + 0x10, 1)
            get_return_response.value = data

    # note: NOT READY TO BE USED!!!
    # note update: maybe now ready to be used?
    async def _read_memory(self, addr, length, values):
        await cocotb.triggers.ReadOnly()
        # memory_slice = self.memory[addr:addr+length]
        # for val in self.memory[addr: addr+length]:
        values.extend(self.memory[addr:addr+length])

    async def _write_memory(self, addr, data):
        #  print('write range')
        await cocotb.triggers.ReadOnly()
        #  print(f'{data=}, len(data)={len(data)}')
        for i, value in enumerate(data):
            self.memory[addr+i] = value.to_bytes(4, byteorder="little")[0]
            #  word_length = 4 if data.WhichOneOf("value") == "u_32" else 8
            #  word = struct.unpack("B" * word_length, value.to_bytes(word_length, byteorder="little"))
            #  self.memory[addr:addr+word_length] = word

    # thougts: this method should only retrieve an array of 32bit vectors
    # and return it. if an access is supposed to be 64 or 32 bit wide doesnt
    # concern it. 
    async def _read_platform(self, addr, read_platform_response, is_single32):
        if is_single32:
            _, read, _ = await self.axim.read(addr, 1)
            data = read[0].to_bytes(4, byteorder="little")
        else:
            _, read, _ = await self.axim.read(addr, 1)
            data = read[0].to_bytes(4, byteorder="little")
            _, read, _ = await self.axim.read(addr+0x4, 1)
            data += read[0].to_bytes(4, byteorder="little")

        #  print(f'read platform data: {data}')
        read_platform_response.value = int.from_bytes(data, byteorder="little") #int.from_bytes(data, byteorder="little") #if not is_single32 else int.from_bytes(data.to_bytes(8, byteorder="little")[:4], byteorder="little")
        #  print(f"read platform addr: {hex(addr)}, value: {data=}")

    async def _write_platform(self, addr, value, is_single32):
        transformed_value = value
        if not is_single32:
            transformed_value = list()
            for val in value:
                transformed_value.extend([int.from_bytes(val.to_bytes(8, byteorder="little")[:4], byteorder="little"), int.from_bytes(val.to_bytes(8, byteorder="little")[4:8], byteorder="little")])
            # print(f"transformed u64 values: {transformed_value}")
            # await self.axim.write(addr, transformed_value)

        beats_per_burst = 256
        for burst_num, burst in enumerate(partition(transformed_value, beats_per_burst)):
            # print(f'writing platform burst of size {len(burst)}')
            await self.axim.write(addr+4*beats_per_burst*burst_num, burst)
        # print(f'just writing one 32 bit word of platform write: {value[0]}')
        # await self.axim.write(addr, [int.from_bytes(value[0].to_bytes(8, byteorder="little")[:4], byteorder="little")])


        # await self.axim.write(addr, [int.from_bytes(value.to_bytes(8, byteorder="little")[:4], byteorder="little")])
        # await self.axim.write(addr+0x4, [int.from_bytes(value.to_bytes(8, byteorder="little")[4:8], byteorder="little")])
        #  print(f"wrote platform addr: {hex(addr)}, value: {value}, byte_enable: {'0xF' if is_single32 else '0xFF'}")

    def write_memory(self, request, context):
        #  print(f'write range request: {request}')
        #  print(f'write range request data: {request.data}')
        resp = sc.SimResponse()
        event = Event()
        resp.void.SetInParent()
        self.request_queue.put(
                (cocotb.create_task(self._write_memory(request.addr, request.data)), lambda: event.set()))
        event.wait()
        #  print(f'memory: {self.memory[request.addr:len(request.data)]}')
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
        self.request_queue.put((cocotb.create_task(self._read_platform(request.addr, resp.read_platform_response, request.num_bytes == 4)), lambda: event.set()))
        event.wait()
        return resp

    def write_platform(self, request, context):
        #  print(f'write platform addr {hex(request.addr)}: {request.data}')
        resp = sc.SimResponse(type=sc.SimResponseType.Okay)
        resp.void.SetInParent()
        whichoneof = request.WhichOneof("data")
        event = Event()
        self.request_queue.put((cocotb.create_task(self._write_platform(request.addr, getattr(request, whichoneof).value, whichoneof == "u_32")), lambda: event.set()))
        event.wait()
        return resp

    def register_interrupt(self, request, context):
        #  print(request)
        if request.fd in self.interrupts.keys():
            #  print("fd already exists")
            self.interrupts[request.fd].deregister_interrupt()

        self.interrupts[request.fd] = SimInterrupt(self.dut, f'ext_intr_PE_{request.interrupt_id}_0')
        self.request_queue.put(
            (self.interrupts[request.fd].get_cocotb_task(), lambda: None))

        return sc.SimResponse(type=sc.SimResponseType.Okay, void=sc.Void())

    def deregister_interrupt(self, request, context):
        self.interrupts.pop(request.fd)
        # print("removed interrupt")
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
            #  print(f'sending interrupt status: {ints}')
        else:
            resp.type = sc.SimResponseType.Error
            resp.error_reason = f"Interrupt id {request.fd} is not registered"

        return resp

