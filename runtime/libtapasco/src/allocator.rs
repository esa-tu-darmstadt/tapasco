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
use crate::vfio::*;
use core::fmt::Debug;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;
use std::sync::Arc;

#[derive(Debug, Snafu, PartialEq)]
pub enum Error {
    #[snafu(display("No memory of size {} available.", size))]
    OutOfMemory { size: DeviceSize },
    #[snafu(display("Memory of size {} at offset 0x{:x} not available.", size, offset))]
    FixedNotAvailable {
        size: DeviceSize,
        offset: DeviceAddress,
    },
    #[snafu(display("Invalid memory size {}.", size))]
    InvalidSize { size: DeviceSize },
    #[snafu(display("Invalid memory alignment {}.", alignment))]
    InvalidAlignment { alignment: DeviceSize },
    #[snafu(display("Can't free unknown memory address {}.", ptr))]
    UnknownMemory { ptr: DeviceAddress },
    #[snafu(display("Could not free memory: {}", source))]
    IOCTLFree { source: nix::Error },
    #[snafu(display("Fixed allocator is not implemented in driver."))]
    NoFixedInDriver {},
    #[snafu(display("VFIO ioctl failed: {}", func))]
    VfioError {func: String},
    #[snafu(display("VFIO allocator requires va argument, none given"))]
    VfioNoVa {},
}
type Result<T, E = Error> = std::result::Result<T, E>;

/// Basic trait that allows memory allocations
///
/// Allocate returns a valid allocation of the given size in device address space.
/// The fixed variant allows the user to specify a desired location for the allocation.
/// The returned address will match the desired location or an error is return if that
/// location is not free.
pub trait Allocator: Debug {
    fn allocate(&mut self, size: DeviceSize, va: Option<u64>) -> Result<DeviceAddress>;
    fn allocate_fixed(&mut self, size: DeviceSize, offset: DeviceAddress) -> Result<DeviceAddress>;
    fn free(&mut self, ptr: DeviceAddress) -> Result<()>;
}

#[derive(Debug, Getters, Copy, Clone)]
struct MemoryFree {
    base: DeviceAddress,
    size: DeviceSize,
}
/// Simple allocator for host handled device memory
///
/// Simply finds the first free memory on the device and returns it.
/// Keeps track of allocated and free memory through lists.
/// Supports memory alignment on byte granularity.
#[derive(Debug, Getters)]
pub struct GenericAllocator {
    memory_free: Vec<MemoryFree>,
    memory_used: Vec<MemoryFree>,
    alignment: DeviceSize,
}

impl GenericAllocator {
    /// Generate a new allocator with the given size and alignment
    ///
    /// The address parameter can be used to offset all returned addresses.
    pub fn new(
        address: DeviceAddress,
        size: DeviceSize,
        alignment: DeviceSize,
    ) -> Result<Self> {
        if size == 0 {
            return Err(Error::InvalidSize { size });
        }
        if alignment == 0 {
            return Err(Error::InvalidAlignment {
                alignment
            });
        }
        Ok(Self {
            memory_free: vec![MemoryFree {
                base: address,
                size,
            }],
            memory_used: Vec::new(),
            alignment,
        })
    }

    const fn fix_alignment(&self, size: DeviceSize) -> DeviceSize {
        // Works for 64 bit values, prone to overflow on 32 bit
        (size + (self.alignment - 1)) & !(self.alignment - 1)
    }

    fn merge_memory(&mut self) {
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
    fn allocate(&mut self, size: DeviceSize, _va: Option<u64>) -> Result<DeviceAddress> {
        if size == 0 {
            return Err(Error::InvalidSize { size });
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

        if let Some(x) = element_found {
            trace!("Removing empty segment.");
            self.memory_free.remove(x);
        };

        match addr_found {
            Some(x) => Ok(x),
            None => Err(Error::OutOfMemory { size: size_aligned }),
        }
    }

    fn allocate_fixed(&mut self, size: DeviceSize, offset: DeviceAddress) -> Result<DeviceAddress> {
        if size == 0 {
            return Err(Error::InvalidSize { size });
        }
        trace!("Looking for free memory at offset 0x{:x}.", offset);
        let size_aligned = self.fix_alignment(size);
        let mut element_found = None;
        let mut addr_found = None;
        for (i, s) in &mut self.memory_free.iter_mut().enumerate() {
            let segment_end = s.base + s.size;
            if s.base <= offset && offset <= segment_end && segment_end - offset >= size_aligned {
                trace!("Found fixed free space in segment {:?}.", s);
                addr_found = Some(offset);
                self.memory_used.push(MemoryFree {
                    base: offset,
                    size: size_aligned,
                });

                element_found = Some(i);
                break;
            }
        }

        if let Some(x) = element_found {
            trace!("Splitting old segment.");
            if self.memory_free[x].base == offset {
                self.memory_free[x].base += size_aligned;
                self.memory_free[x].size -= size_aligned;
            } else {
                let left_size = offset - self.memory_free[x].base;

                let split_segment = MemoryFree {
                    base: offset + size_aligned,
                    size: self.memory_free[x].size - (left_size + size_aligned),
                };

                if split_segment.size > 0 {
                    self.memory_free.insert(x + 1, split_segment);
                    trace!("New segment right of allocated area: {:?}.", split_segment);
                }

                self.memory_free[x].size = left_size;
            }
            if self.memory_free[x].size == 0 {
                trace!("Segment left of allocated area empty -> Removed.");
                self.memory_free.remove(x);
            } else {
                trace!(
                    "New segment left of allocated area: {:?}.",
                    self.memory_free[x]
                );
            }
        };

        match addr_found {
            Some(x) => Ok(x),
            None => {
                trace!(
                    "Could not find free memory {}B @ {:x}: {:?}.",
                    size_aligned,
                    offset,
                    self
                );
                Err(Error::FixedNotAvailable {
                    size: size_aligned,
                    offset,
                })
            }
        }
    }

    fn free(&mut self, ptr: DeviceAddress) -> Result<()> {
        match self.memory_used.iter().position(|&x| x.base == ptr) {
            Some(x) => {
                let m = self.memory_used[x];
                self.memory_used.remove(x);
                trace!("Freeing memory segment {:?}", m);
                if self.memory_free.is_empty() {
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
                            self.memory_free.push(m);
                        }
                    };
                }
                self.merge_memory();
                Ok(())
            }
            None => Err(Error::UnknownMemory { ptr }),
        }
    }
}

#[cfg(test)]
mod allocator_tests {
    use crate::allocator::Allocator;
    use crate::allocator::Error;
    use crate::allocator::GenericAllocator;
    use crate::allocator::VfioAllocator;
    use crate::allocator::Result;
    use crate::vfio::*;
    use std::sync::Arc;

    fn init() {
        let _ = env_logger::builder().is_test(true).try_init();
    }

    #[test]
    fn complete_allocate() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate(1024, None)?;
        assert_eq!(m, 0);
        assert_eq!(a.free(m), Ok(()));
        Ok(())
    }

    #[test]
    fn allocated_fixed_single() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate_fixed(128, 512)?;
        assert_eq!(m, 512);
        assert_eq!(a.free(m), Ok(()));
        let m2 = a.allocate(1024, None)?;
        assert_eq!(m2, 0);
        assert_eq!(a.free(m2), Ok(()));
        Ok(())
    }

    #[test]
    fn allocated_fixed_multiple() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate_fixed(128, 512)?;
        assert_eq!(m, 512);
        let m2 = a.allocate_fixed(128, 128)?;
        assert_eq!(m2, 128);
        let m3 = a.allocate_fixed(128, 768)?;
        assert_eq!(m3, 768);
        assert_eq!(a.free(m), Ok(()));
        assert_eq!(a.free(m2), Ok(()));
        assert_eq!(a.free(m3), Ok(()));
        Ok(())
    }

    #[test]
    fn allocated_fixed_large() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 0x100000, 64)?;
        let m = a.allocate(1228, None)?;
        assert_eq!(m, 0);
        let m2 = a.allocate_fixed(2048, 0x80000)?;
        assert_eq!(m2, 0x80000);
        assert_eq!(a.free(m), Ok(()));
        assert_eq!(a.free(m2), Ok(()));
        Ok(())
    }

    #[test]
    fn alloc_free_alloc() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate(1024, None)?;
        assert_eq!(m, 0);
        assert_eq!(a.free(m), Ok(()));
        let m2 = a.allocate(1024, None)?;
        assert_eq!(m2, 0);
        assert_eq!(a.free(m2), Ok(()));
        Ok(())
    }

    #[test]
    fn alloc_free_alloc2() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate(512, None)?;
        let m2 = a.allocate(512, None)?;
        assert_eq!(m, 0);
        assert_eq!(m2, 512);
        assert_eq!(a.free(m), Ok(()));
        assert_eq!(a.allocate(1024, None), Err(Error::OutOfMemory { size: 1024 }));
        assert_eq!(a.free(m2), Ok(()));
        let m3 = a.allocate(768, None)?;
        assert_eq!(m3, 0);
        assert_eq!(a.free(m3), Ok(()));
        Ok(())
    }

    #[test]
    fn alloc_free_alloc3() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate(512, None)?;
        let m2 = a.allocate(512, None)?;
        assert_eq!(m, 0);
        assert_eq!(m2, 512);
        assert_eq!(a.free(m), Ok(()));
        let m4 = a.allocate(8, None)?;
        let m5 = a.allocate(32, None)?;
        assert_eq!(a.allocate(1024, None), Err(Error::OutOfMemory { size: 1024 }));
        assert_eq!(a.free(m2), Ok(()));
        let m3 = a.allocate(768, None)?;
        assert_eq!(a.free(m3), Ok(()));
        assert_eq!(a.free(m4), Ok(()));
        assert_eq!(a.free(m5), Ok(()));
        let _ = a.allocate(1024, None)?;
        Ok(())
    }

    #[test]
    fn freeing_unknown() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        assert_eq!(a.free(0), Err(Error::UnknownMemory { ptr: 0 }));
        Ok(())
    }

    #[test]
    fn empty_allocate() -> Result<()> {
        init();
        let mut a = GenericAllocator::new(0, 1024, 64)?;
        let m = a.allocate(0, None);
        assert_eq!(m, Err(Error::InvalidSize { size: 0 }));
        Ok(())
    }

    #[test]
    fn vfio_alloc() -> Result<()> {
        init();
        let vfio_dev = Arc::new(VfioDev::default());
        let mut a = VfioAllocator::new(&vfio_dev)?;
        let r0 = a.allocate(100, Some(1000));
        let m = vfio_dev.mappings.lock().unwrap();
        assert_eq!(r0, Ok(1000));
        assert_eq!(m[0].size, IOMMU_PAGESIZE);
        assert_eq!(m[0].iova, 0);
        std::mem::drop(m);

        let r1 = a.allocate(100, Some(4090));
        let m = vfio_dev.mappings.lock().unwrap();
        assert_eq!(r1, Ok(IOMMU_PAGESIZE + 4090));
        assert_eq!(m[1].size, 2*IOMMU_PAGESIZE);
        assert_eq!(m[1].iova, IOMMU_PAGESIZE);
        std::mem::drop(m);

        let r2 = a.allocate(5000, Some(4090));
        let m = vfio_dev.mappings.lock().unwrap();
        assert_eq!(r2, Ok(3*IOMMU_PAGESIZE + 4090));
        assert_eq!(m[2].size, 3*IOMMU_PAGESIZE);
        assert_eq!(m[2].iova, 3*IOMMU_PAGESIZE);
        Ok(())
    }
}

/// Allocate memory through TLKM
///
/// This version is currently used for Zynq based devices.
/// No actual memory handling is performed, the request is simply
/// translated to IOCTLs and forwarded to the driver.
#[derive(Debug, Getters)]
pub struct DriverAllocator {
    tlkm_file: Arc<File>,
}
impl DriverAllocator {
    pub fn new(tlkm_file: &Arc<File>) -> Result<Self> {
        Ok(Self {
            tlkm_file: tlkm_file.clone(),
        })
    }
}

impl Allocator for DriverAllocator {
    fn allocate(&mut self, size: DeviceSize, _va: Option<u64>) -> Result<DeviceAddress> {
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
            Err(_e) => Err(Error::OutOfMemory { size }),
        }
    }

    fn allocate_fixed(
        &mut self,
        _size: DeviceSize,
        _offset: DeviceAddress,
    ) -> Result<DeviceAddress> {
        Err(Error::NoFixedInDriver {})
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


/// Allocate memory through VFIO
///
/// This version may be used on ZynqMP based devices as an alternative to DriverAllocator.
/// Allocator keeps track of memory regions that are mapped using the SMMU of the ZynqMP.
#[derive(Debug, Getters)]
pub struct VfioAllocator {
    vfio_dev: Arc<VfioDev>,
}
impl VfioAllocator {
    pub fn new(vfio_dev: &Arc<VfioDev>) -> Result<Self> {
        Ok(Self {
            vfio_dev: vfio_dev.clone(),
        })
    }
}

impl Allocator for VfioAllocator {
    fn allocate(&mut self, size: DeviceSize, va: Option<u64>) -> Result<DeviceAddress> {
        let mut maps = self.vfio_dev.mappings.lock().unwrap();
        let iova_start = match maps.last() {
            Some(e) => e.iova + e.size, // new alloc starts right of last alloc
            None => 0
        };
        let offset = match va {
            Some(a) => (a % IOMMU_PAGESIZE), // position of data within page
            None => return Err(Error::VfioNoVa{})
        };
        let iova_end = to_page_boundary(iova_start + offset + size + IOMMU_PAGESIZE - 1);

        trace!("Allocating {} bytes starting at iova=0x{:x} offs=0x{:x} through vfio.",
               size, iova_start, offset);
        maps.push(VfioMapping {
            size: iova_end - iova_start,
            iova: iova_start
        });
        Ok(iova_start + offset)
    }

    fn allocate_fixed(
        &mut self,
        _size: DeviceSize,
        _offset: DeviceAddress,
    ) -> Result<DeviceAddress> {
        Err(Error::NoFixedInDriver {})
    }

    fn free(&mut self, ptr: DeviceAddress) -> Result<()> {
        trace!("Deallocating address 0x{:x} through vfio.", ptr);

        let mut maps = self.vfio_dev.mappings.lock().unwrap();
        let iova = to_page_boundary(ptr);
        match maps.iter().position(|x| x.iova == iova) {
            Some(idx) => match vfio_dma_unmap(&self.vfio_dev, HP_OFFS + maps[idx].iova, maps[idx].size) {
                Ok(()) => { maps.remove(idx); Ok(()) }
                Err(e) => Err(Error::VfioError {func: e.to_string()}),
            },
            None => Err(Error::UnknownMemory { ptr: iova })
        }
    }
}

/// Dummy allocator with no function
///
/// This allocator is used for SVM support since the allocation is handled in the TLKM in this case.
/// The allocation function do always return Ok() so that as least changes as possible are required
/// on the overall program flow.
#[derive(Debug)]
pub struct DummyAllocator {}

impl DummyAllocator {
    pub const fn new() -> Self {
        Self {}
    }
}

impl Default for DummyAllocator {
    fn default() -> Self {
        Self::new()
    }
}

impl Allocator for DummyAllocator {
    fn allocate(&mut self, _size: DeviceSize, _va: Option<u64>) -> Result<DeviceAddress> {
        Ok(u64::MAX)
    }

    fn allocate_fixed(&mut self, _size: DeviceSize, _offset: DeviceAddress) -> Result<DeviceAddress> {
        Ok(u64::MAX)
    }

    fn free(&mut self, _ptr: DeviceAddress) -> Result<()> {
        Ok(())
    }
}
