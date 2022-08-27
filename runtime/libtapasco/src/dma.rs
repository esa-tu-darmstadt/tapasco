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
use crate::tlkm::{tlkm_copy_cmd_from, tlkm_ioctl_svm_migrate_to_dev, tlkm_ioctl_svm_migrate_to_ram, tlkm_svm_migrate_cmd};
use crate::tlkm::tlkm_copy_cmd_to;
use crate::tlkm::tlkm_ioctl_copy_from;
use crate::tlkm::tlkm_ioctl_copy_to;
use crate::vfio::*;
use core::fmt::Debug;
use memmap::MmapMut;
use snafu::ResultExt;
use std::fs::File;
use std::net::TcpStream;
use std::os::unix::prelude::*;
use std::sync::{Arc, Mutex};
use crate::dma::Error::SimError;
use crate::sim_client::SimClient;
use crate::device::simcalls::{
    WriteMemory,
    ReadMemory,
};

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

    SimError { message: String },
}

type Result<T, E = Error> = std::result::Result<T, E>;

/// Specifies a method to interact with DMA methods
///
/// The methods will block and the transfer is assumed complete when they return.
pub trait DMAControl: Debug {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()>;
    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()>;
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
            )
                .context(DMAFromDeviceSnafu)?;
        };
        Ok(())
    }
}

#[derive(Debug, Getters)]
pub struct VfioDMA {
    vfio_dev: Arc<VfioDev>,
}

impl VfioDMA {
    pub fn new(vfio_dev: &Arc<VfioDev>) -> Self {
        Self {
            vfio_dev: vfio_dev.clone(),
        }
    }
}

/// Use VFIO to transfer data
///
/// This version may be used on ZynqMP based devices as an alternative to DriverDMA.
/// It makes use of the SMMU to provide direct access to userspace memory to the PL.
impl DMAControl for VfioDMA {
    fn copy_to(&self, data: &[u8], iova: DeviceAddress) -> Result<()> {
        // No actual data is copied here. Instead, the page-aligned address region
        // [va_start, va_start+map_len] is mapped to the I/O virtual address region
        // [iova_start, iova_start+map_len] using the SMMU.
        //
        // The interval [va_start, va_start+map_len] is the smallest page-aligned
        // interval that contains the 'data' buffer.
        let va_start = to_page_boundary(data.as_ptr() as u64);
        let iova_start = to_page_boundary(iova);
        let map_len = self.vfio_dev
            .get_region_size(iova_start)
            .context(VfioSnafu)?;

        trace!(
            "Copy Host({:?}) -> Device(0x{:x}) ({} Bytes). Map va=0x{:x} -> iova=0x{:x} len=0x{:x}",
            data.as_ptr(), iova, data.len(), va_start, iova_start, map_len
        );
        match vfio_dma_map(&self.vfio_dev, map_len, HP_OFFS + iova_start, va_start) {
            Ok(_) => Ok(()),
            Err(e) => Err(Error::VfioError { source: e })
        }
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
}

impl DirectDMA {
    pub fn new(offset: DeviceAddress, size: DeviceSize, memory: Arc<MmapMut>) -> Self {
        Self {
            offset,
            size,
            memory,
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
            let s = std::ptr::slice_from_raw_parts_mut(p, data.len());
            (*s).clone_from_slice(data);
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

        data[..].clone_from_slice(
            &self.memory[(self.offset + ptr) as usize..(self.offset + end) as usize],
        );

        Ok(())
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
}

#[derive(Debug, Getters)]
#[allow(unused)]
pub struct SimDMA {
    client: SimClient,
}

#[allow(unused)]
impl SimDMA {
    pub fn new() -> Result<Self> {
        Ok(Self {
            client: SimClient::new().map_err(|_| SimError { message: "Error instantiating sim client from SimDMA".to_string() })?
        })
    }
}


impl DMAControl for SimDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        trace!("SimDMA copy_to {:?}, {:?}", data, ptr);
        self.client.write_memory(WriteMemory {
            addr: ptr as u64,
            data: data.iter().map(|b| *b as u32).collect(),
        }).map_err(|_| SimError { message: "error copying data to device".to_string() })?;
        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        trace!("SimDMA copy_from {:?}, {:?}", data, ptr);
        let request = ReadMemory {
            addr: ptr as u64,
            length: data.len() as u64,
        };
        let read_range_response = self.client.read_memory(request).map_err(|_| SimError { message: "error copying data from device".to_string() })?;
        data.copy_from_slice(read_range_response.iter().map(|val| *val as u8).collect::<Vec<u8>>().as_mut_slice());
        Ok(())
    }
}