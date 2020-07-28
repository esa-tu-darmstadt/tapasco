/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

use crate::device::DataTransferPrealloc;
use crate::device::DeviceAddress;
use crate::device::DeviceSize;
use crate::device::OffchipMemory;
use crate::device::PEParameter;
use crate::tlkm::tlkm_ioctl_reg_user;
use crate::tlkm::tlkm_register_interrupt;
use memmap::MmapMut;
use nix::sys::eventfd::eventfd;
use nix::sys::eventfd::EfdFlags;
use nix::unistd::close;
use nix::unistd::read;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::io::RawFd;
use std::os::unix::prelude::*;
use std::sync::Arc;

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

    #[snafu(display("Error creating interrupt eventfd: {}", source))]
    ErrorEventFD { source: nix::Error },

    #[snafu(display("Error reading interrupt eventfd: {}", source))]
    ErrorEventFDRead { source: nix::Error },

    #[snafu(display("Could not register eventfd with driver: {}", source))]
    ErrorEventFDRegister { source: nix::Error },
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

    #[set = "pub"]
    #[get = "pub"]
    local_memory: Option<Arc<OffchipMemory>>,

    interrupt: RawFd,
}

impl Drop for PE {
    fn drop(&mut self) {
        let _ = close(self.interrupt);
    }
}

impl PE {
    pub fn new(
        id: usize,
        type_id: PEId,
        offset: DeviceAddress,
        size: DeviceSize,
        name: String,
        memory: Arc<MmapMut>,
        completion: &File,
    ) -> Result<PE> {
        let fd = eventfd(0, EfdFlags::EFD_NONBLOCK).context(ErrorEventFD)?;
        let mut ioctl_fd = tlkm_register_interrupt {
            fd: fd,
            pe_id: id as i32,
        };

        unsafe {
            tlkm_ioctl_reg_user(completion.as_raw_fd(), &mut ioctl_fd)
                .context(ErrorEventFDRegister)?;
        };

        Ok(PE {
            id: id,
            type_id: type_id,
            offset: offset,
            size: size,
            name: name,
            active: false,
            copy_back: None,
            memory: memory,
            local_memory: None,
            interrupt: fd,
        })
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

    pub fn release(
        &mut self,
        return_value: bool,
    ) -> Result<(u64, Option<Vec<DataTransferPrealloc>>)> {
        trace!(
            "Waiting for PE {} to complete processing (interrupt signal).",
            self.id
        );
        self.wait_for_completion()?;
        trace!("PE {} done.", self.id);
        let rv = if return_value { self.return_value() } else { 0 };
        Ok((rv, self.get_copyback()))
    }

    fn wait_for_completion(&mut self) -> Result<()> {
        if self.active {
            let mut buf = [0u8; 8];
            while self.active {
                let r = read(self.interrupt, &mut buf);
                match r {
                    Ok(_) => {
                        trace!("Cleaning up PE {} after release.", self.id);
                        self.active = false;
                        self.reset_interrupt(true)?;
                    }
                    Err(e) => {
                        let e_no = e.as_errno();
                        match e_no {
                            Some(e_no_matched) => {
                                if e_no_matched != nix::errno::Errno::EAGAIN {
                                    r.context(ErrorEventFDRead)?;
                                } else {
                                    std::thread::yield_now();
                                }
                            }
                            None => {
                                r.context(ErrorEventFDRead)?;
                            }
                        }
                    }
                }
            }
        } else {
            trace!("Wait requested but {:?} is already idle.", self.id);
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

    pub fn return_value(&self) -> u64 {
        let offset = (self.offset as usize + 0x10) as isize;
        let r = unsafe {
            let ptr = self.memory.as_ptr().offset(offset);
            (*(ptr as *const Volatile<u64>)).read()
        };
        trace!("Reading return value: {}", r);
        r
    }

    pub fn add_copyback(&mut self, param: DataTransferPrealloc) {
        self.copy_back.get_or_insert(Vec::new()).push(param);
    }

    fn get_copyback(&mut self) -> Option<Vec<DataTransferPrealloc>> {
        self.copy_back.take()
    }
}
