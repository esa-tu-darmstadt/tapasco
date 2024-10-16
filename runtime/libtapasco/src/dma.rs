/*
 * Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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
use crate::protos::simcalls::ReadPlatform;
use crate::tlkm::{tlkm_copy_cmd_from, tlkm_ioctl_svm_migrate_to_dev, tlkm_ioctl_svm_migrate_to_ram, tlkm_svm_migrate_cmd};
use crate::tlkm::tlkm_copy_cmd_to;
use crate::tlkm::tlkm_ioctl_copy_from;
use crate::tlkm::tlkm_ioctl_copy_to;
use core::fmt::Debug;
use memmap::MmapMut;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;
use std::sync::Arc;
use crate::sim_client::SimClient;
use crate::protos::simcalls::{
    write_platform::Data,
    Data32,
    WritePlatform,
    WriteMemory,
    ReadMemory,
};
use crate::sim_client;

#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum Error {
    #[snafu(display("Could not transfer to device {}", source))]
    DMAToDevice { source: nix::Error },

    #[snafu(display("Could not transfer from device {}", source))]
    DMAFromDevice { source: nix::Error },

    #[snafu(display("Could not allocate DMA buffer {}", source))]
    DMABufferAllocate { source: nix::Error },

    #[snafu(display(
        "Transfer 0x{:x} - 0x{:x} outside of memory region 0x{:x}.",
        ptr,
        end,
        size
    ))]
    OutOfRange {
        ptr: DeviceAddress,
        end: DeviceAddress,
        size: DeviceSize,
    },

    #[snafu(display("Mutex has been poisoned"))]
    MutexError {},

    #[snafu(display("Failed flushing the memory for DirectDMA: {}", source))]
    FailedFlush { source: std::io::Error },

    #[snafu(display("Failed to mmap DMA buffer: {}", source))]
    FailedMMapDMA { source: std::io::Error },

    #[snafu(display("Error during interrupt handling: {}", source))]
    ErrorInterrupt { source: crate::interrupt::Error },

    #[snafu(display(
        "Got interrupt but outstanding buffers are empty. This should never happen."
    ))]
    TooManyInterrupts {},

    #[snafu(display("VFIO failed: {}", source))]
    VfioError { source: crate::vfio::Error },

    #[snafu(display("Error during gRPC communictaion {}", source))]
    SimClientError { source: sim_client::Error },

    #[snafu(display("Streams not supported on this platform"))]
    StreamsNotSupported {},
}
pub(crate) type Result<T, E = Error> = std::result::Result<T, E>;

/// Specifies a method to interact with DMA methods
///
/// The methods will block and the transfer is assumed complete when they return.
pub trait DMAControl: Debug {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()>;
    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()>;
    fn h2c_stream(&self, data: &[u8]) -> Result<()>;
    fn c2h_stream(&self, data: &mut [u8]) -> Result<()>;
}

#[derive(Debug, Getters)]
pub struct DriverDMA {
    tlkm_file: Arc<File>,
}

impl DriverDMA {
    pub fn new(tlkm_file: &Arc<File>) -> Self {
        Self {
            tlkm_file: tlkm_file.clone(),
        }
    }
}

/// Use TLKM IOCTLs to transfer data
///
/// Is currently used for Zynq based devices.
impl DMAControl for DriverDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        trace!(
            "Copy Host({:?}) -> Device(0x{:x}) ({} Bytes)",
            data.as_ptr(),
            ptr,
            data.len()
        );
        unsafe {
            tlkm_ioctl_copy_to(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_copy_cmd_to {
                    dev_addr: ptr,
                    length: data.len(),
                    user_addr: data.as_ptr(),
                },
            )
            .context(DMAToDeviceSnafu)?;
        };
        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        trace!(
            "Copy Device(0x{:x}) -> Host({:?}) ({} Bytes)",
            ptr,
            data.as_mut_ptr(),
            data.len()
        );
        unsafe {
            tlkm_ioctl_copy_from(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_copy_cmd_from {
                    dev_addr: ptr,
                    length: data.len(),
                    user_addr: data.as_mut_ptr(),
                },
            ).context(DMAFromDeviceSnafu)?;
        };
        Ok(())
    }

    fn c2h_stream(&self, _data: &mut [u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }

    fn h2c_stream(&self, _data: &[u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }
}

#[derive(Debug, Getters)]
pub struct VfioDMA {}

impl VfioDMA {
    pub fn new() -> Self {
        Self {}
    }
}

/// Use VFIO to transfer data
///
/// This version may be used on ZynqMP based devices as an alternative to DriverDMA.
/// It makes use of the SMMU to provide direct access to userspace memory to the PL.
/// Thus, there is no need to copy any data.
impl DMAControl for VfioDMA {
    fn copy_to(&self, data: &[u8], iova: DeviceAddress) -> Result<()> {
        trace!(
            "Copy Host({:?}) -> Device(0x{:x}) ({} Bytes)",
            data.as_ptr(),
            iova,
            data.len()
        );
        Ok(())
    }

    fn copy_from(&self, iova: DeviceAddress, data: &mut [u8]) -> Result<()> {
        trace!(
            "Copy Device(0x{:x}) -> Host({:?}) ({} Bytes)",
            iova,
            data.as_mut_ptr(),
            data.len()
        );

        // nothing to copy, 'data' is same buffer that PE operated on
        Ok(())
    }

    fn c2h_stream(&self, _data: &mut [u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }

    fn h2c_stream(&self, _data: &[u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }
}

/// Use the CPU to transfer data
///
/// Can be used for all memory that is directly accessible by the host.
/// This might be BAR mapped device off-chip-memory or PE local memory.
/// The latter is the main use case for this kind of transfer.
#[derive(Debug, Getters)]
pub struct DirectDMA {
    offset: DeviceAddress,
    size: DeviceSize,
    memory: Arc<MmapMut>,
    dev_name: String,
}

impl DirectDMA {
    pub fn new(offset: DeviceAddress, size: DeviceSize, memory: Arc<MmapMut>, dev_name: String) -> Self {
        Self {
            offset,
            size,
            memory,
            dev_name,
        }
    }
}

impl DMAControl for DirectDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        let end = ptr + data.len() as u64;
        if end > self.size {
            return Err(Error::OutOfRange {
                ptr,
                end,
                size: self.size,
            });
        }

        trace!(
            "Copy Host -> Device(0x{:x} + 0x{:x}) ({} Bytes)",
            self.offset,
            ptr,
            data.len()
        );

        // This is necessary as MMapMut is Protected by an Arc but access without
        // an explicit lock is necessary
        // Locking the mmap would slow down PE start etc too much
        unsafe {
            let p = self.memory.as_ptr().offset((self.offset + ptr) as isize) as *mut u8;
            
            //on armv8 unaligned accesses to device memory result in a bus error
            if self.dev_name == "zynqmp" {
                let remaining_bytes = data.len() % 8;
                let aligned_bytes = data.len() - remaining_bytes;
                let unaligned = remaining_bytes != 0;
                
                //use clone_from_slice for the aligned portion of the data to
                //maintain fast transfer speeds
                let s: *mut [u8] = std::ptr::slice_from_raw_parts_mut(p, aligned_bytes);
                (*s).clone_from_slice(&data[..(aligned_bytes)]);

                if unaligned {
                    let rem_s: *mut [u8] = std::ptr::slice_from_raw_parts_mut(p.offset(aligned_bytes as isize), remaining_bytes);
                    //transfer the remaining bytes individually
                    for i in 0..remaining_bytes {
                        (*rem_s)[i] = data[aligned_bytes + i];
                    }
                }
            } else {
                let s: *mut [u8] = std::ptr::slice_from_raw_parts_mut(p, data.len());
                (*s).clone_from_slice(data);                
            }
            
        }
        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        let end = ptr + data.len() as u64;
        if end > self.size {
            return Err(Error::OutOfRange {
                ptr,
                end,
                size: self.size,
            });
        }

        trace!(
            "Copy Device(0x{:x} + 0x{:x}) -> Host ({} Bytes)",
            self.offset,
            ptr,
            data.len()
        );
        
        if self.dev_name == "zynqmp" {
            let remaining_bytes = data.len() % 8;
            let aligned_bytes = data.len() - remaining_bytes;
            let unaligned = remaining_bytes != 0;
            let aligned_end = end - remaining_bytes as u64;

            data[..(aligned_bytes)].clone_from_slice(
                &self.memory[(self.offset + ptr) as usize..(self.offset + aligned_end) as usize]
            );
            
            if unaligned {
                for i in 0..remaining_bytes {
                    let mem_idx: usize = (self.offset + aligned_end) as usize + i;
                    data[aligned_bytes + i] = self.memory[mem_idx];
                }
            }
        } else {
            data[..].clone_from_slice(
                &self.memory[(self.offset + ptr) as usize..(self.offset + end) as usize],
            );
        }

        Ok(())
    }

    fn c2h_stream(&self, _data: &mut [u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }

    fn h2c_stream(&self, _data: &[u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }
}

/// DMA implementation for SVM support
///
/// When using SVM buffer migrations to/from device memory can still be explicitly triggered,
/// however, are controlled completely in the TLKM
#[derive(Debug, Getters)]
pub struct SVMDMA {
    tlkm_file: Arc<File>,
}

impl SVMDMA {
    pub fn new(tlkm_file: &Arc<File>) -> Self {
        Self {
            tlkm_file: tlkm_file.clone(),
        }
    }
}

impl DMAControl for SVMDMA {
    fn copy_to(&self, data: &[u8], _ptr: DeviceAddress) -> Result<()> {
        let base = data.as_ptr() as u64;
        let size = data.len() as u64;
        trace!("Start migration to device memory with base address = {:#02x} and size = {:#02x}.", base, size);
        unsafe {
            tlkm_ioctl_svm_migrate_to_dev(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_svm_migrate_cmd {
                    vaddr: base,
                    size,
                },
            ).context(DMAToDeviceSnafu)?;
        }
        trace!("Migration to device memory complete.");
        Ok(())
    }

    fn copy_from(&self, _ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        let base = data.as_ptr() as u64;
        let size = data.len() as u64;
        trace!("Start migration to host memory with base address = {:#02x} and size = {:#02x}.", base, size);
        unsafe {
            tlkm_ioctl_svm_migrate_to_ram(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_svm_migrate_cmd {
                    vaddr: base,
                    size,
                },
            ).context(DMAFromDeviceSnafu)?;
        }
        trace!("Migration to host memory complete.");
        Ok(())
    }

    fn c2h_stream(&self, _data: &mut [u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }

    fn h2c_stream(&self, _data: &[u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }
}

#[derive(Debug, Getters)]
pub struct SimDMA {
    client: SimClient,
    offset: DeviceAddress,
    size: DeviceSize,
    is_platform: bool,
}

impl SimDMA {
    pub fn new(
        offset: DeviceAddress,
        size: DeviceSize,
        is_platform: bool
    ) -> Result<Self> {
        Ok(Self {
            client: SimClient::new().context(SimClientSnafu)?,
            offset,
            size,
            is_platform,
        })
    }
}


impl DMAControl for SimDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        let end = ptr + data.len() as u64;
        if end > self.size {
            return Err(Error::OutOfRange {
                ptr,
                end,
                size: self.size,
            });
        }
        if self.is_platform {
            let (_, ints, _) = unsafe {data.align_to::<u32>()};
            self.client.write_platform(WritePlatform {
                addr: self.offset + ptr as u64,
                data: Some(Data::U32(Data32 {value: ints.to_vec()})),
            }).context(SimClientSnafu)?;
        } else {
            self.client.write_memory(WriteMemory {
                addr: self.offset + ptr as u64,
                data: data.iter().map(|b| *b as u32).collect(),
            }).context(SimClientSnafu)?;
        }
        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        let end = ptr + data.len() as u64;
        if end > self.size {
            return Err(Error::OutOfRange {
                ptr,
                end,
                size: self.size,
            });
        }

        if self.is_platform {
            let request = ReadPlatform {
                addr: self.offset + ptr as u64,
                num_bytes: data.len() as u32,
            };
            let read_platform_response = self.client.read_platform(request).context(SimClientSnafu)?;
            data.copy_from_slice(read_platform_response.iter().map(|val| *val as u8).collect::<Vec<u8>>().as_mut_slice());
        } else {
            let request = ReadMemory {
                addr: self.offset + ptr as u64,
                length: data.len() as u64,
            };
            let read_memory_response = self.client.read_memory(request).context(SimClientSnafu)?;
            data.copy_from_slice(read_memory_response.iter().map(|val| *val as u8).collect::<Vec<u8>>().as_mut_slice());
        }

        Ok(())
    }

    fn c2h_stream(&self, _data: &mut [u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }

    fn h2c_stream(&self, _data: &[u8]) -> Result<()> {
        Err(Error::StreamsNotSupported {})
    }
}
