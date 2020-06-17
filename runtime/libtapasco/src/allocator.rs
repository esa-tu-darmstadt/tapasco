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

use crate::device::DeviceAddress;
use crate::device::DeviceSize;
use crate::tlkm::tlkm_ioctl_alloc;
use crate::tlkm::tlkm_ioctl_free;
use crate::tlkm::tlkm_mm_cmd;
use core::fmt::Debug;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;
use std::sync::Arc;

#[derive(Debug, Snafu, PartialEq)]
pub enum Error {
    #[snafu(display("No memory of size {} available.", size))]
    OutOfMemory { size: DeviceSize },
    #[snafu(display("Invalid memory size {}.", size))]
    InvalidSize { size: DeviceSize },
    #[snafu(display("Invalid memory alignment {}.", alignment))]
    InvalidAlignment { alignment: DeviceSize },
    #[snafu(display("Can't free unknown memory address {}.", ptr))]
    UnknownMemory { ptr: DeviceAddress },
    #[snafu(display("Could not free memory: {}", source))]
    IOCTLFree { source: nix::Error },
}
type Result<T, E = Error> = std::result::Result<T, E>;

pub trait Allocator: Debug {
    fn allocate(&mut self, size: DeviceSize) -> Result<DeviceAddress>;
    fn free(&mut self, ptr: DeviceAddress) -> Result<()>;
}

#[derive(Debug, Getters, Copy, Clone)]
struct MemoryFree {
    base: DeviceAddress,
    size: DeviceSize,
}

#[derive(Debug, Getters)]
pub struct GenericAllocator {
    memory_free: Vec<MemoryFree>,
    memory_used: Vec<MemoryFree>,
    alignment: DeviceSize,
}

impl GenericAllocator {
    pub fn new(
        address: DeviceAddress,
        size: DeviceSize,
        alignment: DeviceSize,
    ) -> Result<GenericAllocator> {
        if size == 0 {
            return Err(Error::InvalidSize { size: size });
        }
        if alignment == 0 {
            return Err(Error::InvalidAlignment {
                alignment: alignment,
            });
        }
        Ok(GenericAllocator {
            memory_free: vec![MemoryFree {
                base: address,
                size: size,
            }],
            memory_used: Vec::new(),
            alignment: alignment,
        })
    }

    fn fix_alignment(&self, size: DeviceSize) -> DeviceSize {
        // Works for 64 bit values, prone to overflow on 32 bit
        (size + (self.alignment - 1)) & !(self.alignment - 1)
    }

    fn merge_memory(&mut self) -> () {
        let mut i = 0;
        trace!("Merging memory, currently at {:?}.", self.memory_free);
        while i < self.memory_free.len() {
            let n = i + 1;
            if n < self.memory_free.len()
                && self.memory_free[i].base + self.memory_free[i].size == self.memory_free[n].base
            {
                trace!(
                    "Merging {:?} and {:?}.",
                    self.memory_free[i],
                    self.memory_free[n]
                );
                self.memory_free[i].size += self.memory_free[n].size;
                self.memory_free.remove(n);
            } else {
                trace!("Checking next element.");
                i += 1;
            }
        }
    }
}

impl Allocator for GenericAllocator {
    fn allocate(&mut self, size: DeviceSize) -> Result<DeviceAddress> {
        if size == 0 {
            return Err(Error::InvalidSize { size: size });
        }
        trace!("Looking for free memory.");
        let size_aligned = self.fix_alignment(size);
        let mut element_found = None;
        let mut addr_found = None;
        for (i, s) in &mut self.memory_free.iter_mut().enumerate() {
            if s.size >= size_aligned {
                trace!("Found free space in segment {:?}.", s);
                let addr = s.base;
                addr_found = Some(addr);
                self.memory_used.push(MemoryFree {
                    base: addr,
                    size: size_aligned,
                });
                s.size -= size_aligned;
                s.base += size_aligned;
                if s.size == 0 {
                    element_found = Some(i);
                } else {
                    trace!("New segment is {:?}.", s);
                }
            }
        }

        match element_found {
            Some(x) => {
                trace!("Removing empty segment.");
                self.memory_free.remove(x);
            }
            None => (),
        };

        match addr_found {
            Some(x) => Ok(x),
            None => Err(Error::OutOfMemory { size: size_aligned }),
        }
    }

    fn free(&mut self, ptr: DeviceAddress) -> Result<()> {
        match self.memory_used.iter().position(|&x| x.base == ptr) {
            Some(x) => {
                let m = self.memory_used[x];
                self.memory_used.remove(x);
                trace!("Freeing memory segment {:?}", m);
                if self.memory_free.len() == 0 {
                    trace!("No free memory right now, adding directly.");
                    self.memory_free.push(m);
                } else {
                    match self.memory_free.iter().position(|&x| x.base > m.base) {
                        Some(x) => {
                            trace!("Adding memory left of {}.", x);
                            self.memory_free.insert(x, m);
                        }
                        None => {
                            trace!("Adding memory to the end.");
                            self.memory_free.push(m)
                        }
                    };
                }
                self.merge_memory();
                Ok(())
            }
            None => Err(Error::UnknownMemory { ptr: ptr }),
        }
    }
}

#[test]
fn complete_allocate() -> Result<()> {
    let mut a = GenericAllocator::new(0, 1024, 64)?;
    let m = a.allocate(1024)?;
    assert_eq!(m, 0);
    assert_eq!(a.free(m), Ok(()));
    Ok(())
}

#[test]
fn alloc_free_alloc() -> Result<()> {
    let mut a = GenericAllocator::new(0, 1024, 64)?;
    let m = a.allocate(1024)?;
    assert_eq!(m, 0);
    assert_eq!(a.free(m), Ok(()));
    let m2 = a.allocate(1024)?;
    assert_eq!(m2, 0);
    assert_eq!(a.free(m2), Ok(()));
    Ok(())
}

#[test]
fn alloc_free_alloc2() -> Result<()> {
    let mut a = GenericAllocator::new(0, 1024, 64)?;
    let m = a.allocate(512)?;
    let m2 = a.allocate(512)?;
    assert_eq!(m, 0);
    assert_eq!(m2, 512);
    assert_eq!(a.free(m), Ok(()));
    assert_eq!(a.allocate(1024), Err(Error::OutOfMemory { size: 1024 }));
    assert_eq!(a.free(m2), Ok(()));
    let m3 = a.allocate(768)?;
    assert_eq!(m3, 0);
    assert_eq!(a.free(m3), Ok(()));
    Ok(())
}

#[test]
fn alloc_free_alloc3() -> Result<()> {
    let mut a = GenericAllocator::new(0, 1024, 64)?;
    let m = a.allocate(512)?;
    let m2 = a.allocate(512)?;
    assert_eq!(m, 0);
    assert_eq!(m2, 512);
    assert_eq!(a.free(m), Ok(()));
    let m4 = a.allocate(8)?;
    let m5 = a.allocate(32)?;
    assert_eq!(a.allocate(1024), Err(Error::OutOfMemory { size: 1024 }));
    assert_eq!(a.free(m2), Ok(()));
    let m3 = a.allocate(768)?;
    assert_eq!(a.free(m3), Ok(()));
    assert_eq!(a.free(m4), Ok(()));
    assert_eq!(a.free(m5), Ok(()));
    let _ = a.allocate(1024)?;
    Ok(())
}

#[test]
fn freeing_unknown() -> Result<()> {
    let mut a = GenericAllocator::new(0, 1024, 64)?;
    assert_eq!(a.free(0), Err(Error::UnknownMemory { ptr: 0 }));
    Ok(())
}

#[test]
fn empty_allocate() -> Result<()> {
    let mut a = GenericAllocator::new(0, 1024, 64)?;
    let m = a.allocate(0);
    assert_eq!(m, Err(Error::InvalidSize { size: 0 }));
    Ok(())
}

#[derive(Debug, Getters)]
pub struct DriverAllocator {
    tlkm_file: Arc<File>,
}
impl DriverAllocator {
    pub fn new(tlkm_file: &Arc<File>) -> Result<DriverAllocator> {
        Ok(DriverAllocator {
            tlkm_file: tlkm_file.clone(),
        })
    }
}

impl Allocator for DriverAllocator {
    fn allocate(&mut self, size: DeviceSize) -> Result<DeviceAddress> {
        trace!("Allocating {} bytes through driver.", size);
        let mut cmd = tlkm_mm_cmd {
            sz: size as usize,
            dev_addr: std::u64::MAX,
        };
        match unsafe { tlkm_ioctl_alloc(self.tlkm_file.as_raw_fd(), &mut cmd) } {
            Ok(_x) => {
                trace!("Received address 0x{:x} from driver.", cmd.dev_addr);
                Ok(cmd.dev_addr)
            }
            Err(_e) => Err(Error::OutOfMemory { size: size }),
        }
    }
    fn free(&mut self, ptr: DeviceAddress) -> Result<()> {
        trace!("Dellocating address 0x{:x} through driver.", ptr);
        let mut cmd = tlkm_mm_cmd {
            sz: 0,
            dev_addr: ptr,
        };
        unsafe { tlkm_ioctl_free(self.tlkm_file.as_raw_fd(), &mut cmd).context(IOCTLFree)? };
        Ok(())
    }
}