from threading import Lock, Event

from cocotb.triggers import RisingEdge

import cocotb

class SimInterrupt:

    def __init__(self, dut, interrupt_handle):
        self._counter_lock = Lock()
        self._counter = 0
        self._interrupt_handle = interrupt_handle
        self.dut = dut
        self.enabled = True
        self.should_exit = False
        self.exit_event = Event()
        self._interrupt_task = None

    def __del__(self):
        self.should_exit = True
        self._interrupt_task.kill()

    def kill(self):
        self._interrupt_task.kill()

    def deregister_interrupt(self):
        self.enabled = False
        self.should_exit = True

    async def interrupt_coroutine(self):
        while not self.should_exit:
            await RisingEdge(getattr(self.dut, self._interrupt_handle))
            if self.enabled:
                self.assert_interrupt()

    def get_cocotb_task(self):
        if self._interrupt_task is None:
            self._interrupt_task = cocotb.create_task(self.interrupt_coroutine())

        return self._interrupt_task

    def assert_interrupt(self):
        self._counter_lock.acquire()
        self._counter += 1
        self._counter_lock.release()

    def clear_interrupt(self):
        self._counter_lock.acquire()
        self._counter = 0
        self._counter_lock.release()

    def get_interrupt_count(self):
        self._counter_lock.acquire()
        tmp = self._counter
        self._counter_lock.release()
        return tmp
