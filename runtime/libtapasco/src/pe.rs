use crate::device::DataTransferPrealloc;
use crate::device::DeviceAddress;
use crate::device::DeviceSize;
use crate::device::PEParameter;
use bytes::Buf;
use lockfree::set::Set;
use memmap::MmapMut;
use snafu::ResultExt;
use std::fs::File;
use std::io::Cursor;
use std::io::Read;
use std::sync::Arc;
use std::sync::Mutex;
use std::{thread, time};
use volatile::Volatile;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display(
        "Param {:?} is unsupported. Only 32 and 64 Bit value can interact with device registers.",
        param
    ))]
    UnsupportedParameter { param: PEParameter },

    #[snafu(display(
        "Transfer width {} Bit is unsupported. Only 32 and 64 Bit value can interact with device registers.",
        param * 8
    ))]
    UnsupportedRegisterSize { param: usize },

    #[snafu(display("PE {} is already running.", id))]
    PEAlreadyActive { id: usize },

    #[snafu(display("Could not read completion file: {}", source))]
    ReadCompletionError { source: std::io::Error },

    #[snafu(display("Could not insert PE {} into active PE set.", pe_id))]
    CouldNotInsertPE { pe_id: usize },
}

type Result<T, E = Error> = std::result::Result<T, E>;

pub type PEId = usize;

#[derive(Debug, Getters, Setters)]
pub struct PE {
    #[get = "pub"]
    id: usize,
    #[get = "pub"]
    type_id: PEId,
    offset: DeviceAddress,
    size: DeviceSize,
    name: String,
    #[get = "pub"]
    active: bool,
    copy_back: Option<Vec<DataTransferPrealloc>>,
    memory: Arc<MmapMut>,
    active_pes: Arc<(Mutex<File>, Set<usize>)>,
}

impl PE {
    pub fn new(
        id: usize,
        type_id: PEId,
        offset: DeviceAddress,
        size: DeviceSize,
        name: String,
        memory: Arc<MmapMut>,
        active_pes: Arc<(Mutex<File>, Set<usize>)>,
    ) -> PE {
        PE {
            id: id,
            type_id: type_id,
            offset: offset,
            size: size,
            name: name,
            active: false,
            copy_back: None,
            memory: memory,
            active_pes: active_pes,
        }
    }

    pub fn start(&mut self) -> Result<()> {
        ensure!(!self.active, PEAlreadyActive { id: self.id });
        trace!("Starting PE {}.", self.id);
        let offset = self.offset as isize;
        unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        self.active = true;
        Ok(())
    }

    pub fn release(&mut self) -> Result<Option<Vec<DataTransferPrealloc>>> {
        trace!("Releasing PE {}.", self.id);
        self.wait_for_completion()?;
        trace!("PE {} released.", self.id);
        Ok(self.get_copyback())
    }

    fn wait_for_completion_loop(&self, completion: &mut File) -> Result<()> {
        let mut active = true;
        while active {
            trace!("Waiting for completion notices from driver.");
            let mut buffer = [u8::max_value(); 128 * 4];
            completion.read(&mut buffer).context(ReadCompletionError)?;
            trace!("Fetched completion notices from driver.");
            let mut buf = Cursor::new(&buffer[..]);
            while buf.remaining() >= 4 {
                let id = buf.get_u32_le();
                if id != u32::max_value() {
                    trace!("Checking PE ID {}", id);
                    if id as usize == self.id {
                        active = false;
                    }
                    match self.active_pes.1.insert(id as usize) {
                        Err(i) => Err(Error::CouldNotInsertPE { pe_id: i })?,
                        _ => {}
                    }
                }
            }
        }
        Ok(())
    }

    fn wait_for_completion(&mut self) -> Result<()> {
        if self.active {
            while self.active {
                if self.active_pes.1.contains(&self.id()) {
                    trace!("Cleaning up PE {} after release.", self.id);
                    self.active_pes.1.remove(&self.id());
                    self.active = false;
                    // TODO: Why is GIER reset without any write to it?
                    // This call should not be necessary
                    self.enable_interrupt()?;
                    self.reset_interrupt(true)?;
                } else {
                    match self.active_pes.0.try_lock() {
                        Ok(mut x) => {
                            trace!("Waiting for completion of {:?}.", self);
                            self.wait_for_completion_loop(&mut x)?;
                            trace!("PE finished execution.");
                        }
                        Err(_) => thread::sleep(time::Duration::from_micros(1)),
                    };
                }
            }
        } else {
            trace!("Wait requested but {:?} is already idle.", self);
        }
        Ok(())
    }

    pub fn interrupt_set(&self) -> Result<bool> {
        let offset = (self.offset as usize + 0x0c) as isize;
        let r = unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).read()
        };
        let s = (r & 1) == 1;
        trace!("Reading interrupt status from 0x{:x} -> {}", offset, s);
        Ok(s)
    }

    pub fn reset_interrupt(&self, v: bool) -> Result<()> {
        let offset = (self.offset as usize + 0x0c) as isize;
        trace!("Resetting interrupts: 0x{:x} -> {}", offset, v);
        unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(if v { 1 } else { 0 });
        }
        Ok(())
    }

    pub fn interrupt_status(&self) -> Result<(bool, bool)> {
        let mut offset = (self.offset as usize + 0x04) as isize;
        let g = unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).read()
        } & 1
            == 1;
        offset = (self.offset as usize + 0x08) as isize;
        let l = unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).read()
        } & 1
            == 1;
        trace!("Interrupt status is {}, {}", g, l);
        Ok((g, l))
    }

    pub fn enable_interrupt(&self) -> Result<()> {
        ensure!(!self.active, PEAlreadyActive { id: self.id });
        let mut offset = (self.offset as usize + 0x04) as isize;
        trace!("Enabling interrupts: 0x{:x} -> 1", offset);
        unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        offset = (self.offset as usize + 0x08) as isize;
        trace!("Enabling global interrupts: 0x{:x} -> 1", offset);
        unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        Ok(())
    }

    pub fn set_arg(&self, argn: usize, arg: PEParameter) -> Result<()> {
        let offset = (self.offset as usize + 0x20 + argn * 0x10) as isize;
        trace!("Writing argument: 0x{:x} ({}) -> {:?}", offset, argn, arg);
        unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            match arg {
                PEParameter::Single32(x) => (*(ptr as *mut Volatile<u32>)).write(x),
                PEParameter::Single64(x) => (*(ptr as *mut Volatile<u64>)).write(x),
                _ => return Err(Error::UnsupportedParameter { param: arg }),
            };
        }
        Ok(())
    }

    pub fn read_arg(&self, argn: usize, bytes: usize) -> Result<PEParameter> {
        let offset = (self.offset as usize + 0x20 + argn * 0x10) as isize;
        let r = unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            match bytes {
                4 => Ok(PEParameter::Single32(
                    (*(ptr as *const Volatile<u32>)).read(),
                )),
                8 => Ok(PEParameter::Single64(
                    (*(ptr as *const Volatile<u64>)).read(),
                )),
                _ => Err(Error::UnsupportedRegisterSize { param: bytes }),
            }
        };
        trace!(
            "Reading argument: 0x{:x} ({} x {}B) -> {:?}",
            offset,
            argn,
            bytes,
            r
        );
        r
    }

    pub fn add_copyback(&mut self, param: DataTransferPrealloc) {
        self.copy_back.get_or_insert(Vec::new()).push(param);
    }

    fn get_copyback(&mut self) -> Option<Vec<DataTransferPrealloc>> {
        self.copy_back.take()
    }
}
