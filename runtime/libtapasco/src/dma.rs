use crate::device::DeviceAddress;
use crate::device::DeviceSize;
use crate::tlkm::tlkm_copy_cmd_from;
use crate::tlkm::tlkm_copy_cmd_to;
use crate::tlkm::tlkm_ioctl_copy_from;
use crate::tlkm::tlkm_ioctl_copy_to;
use core::fmt::Debug;
use memmap::MmapMut;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;
use std::sync::Arc;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Could not transfer to device {}", source))]
    DMAToDevice { source: nix::Error },

    #[snafu(display("Could not transfer from device {}", source))]
    DMAFromDevice { source: nix::Error },

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

    #[snafu(display("Failed flushing the memory for DirectDMA: {}", source))]
    FailedFlush { source: std::io::Error },
}
type Result<T, E = Error> = std::result::Result<T, E>;

pub trait DMAControl: Debug {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()>;
    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()>;
}

#[derive(Debug, Getters)]
pub struct DriverDMA {
    tlkm_file: Arc<File>,
}

impl DriverDMA {
    pub fn new(tlkm_file: &Arc<File>) -> DriverDMA {
        DriverDMA {
            tlkm_file: tlkm_file.clone(),
        }
    }
}

impl DMAControl for DriverDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        trace!("Copy Host -> Device(0x{:x}) ({} Bytes)", ptr, data.len());
        unsafe {
            tlkm_ioctl_copy_to(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_copy_cmd_to {
                    dev_addr: ptr,
                    length: data.len(),
                    user_addr: data.as_ptr(),
                },
            )
            .context(DMAToDevice)?;
        };
        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        trace!("Copy Device(0x{:x}) -> Host ({} Bytes)", ptr, data.len());
        unsafe {
            tlkm_ioctl_copy_from(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_copy_cmd_from {
                    dev_addr: ptr,
                    length: data.len(),
                    user_addr: data.as_mut_ptr(),
                },
            )
            .context(DMAFromDevice)?;
        };
        Ok(())
    }
}

#[derive(Debug, Getters)]
pub struct DirectDMA {
    offset: DeviceAddress,
    size: DeviceSize,
    memory: Arc<MmapMut>,
}

impl DirectDMA {
    pub fn new(offset: DeviceAddress, size: DeviceSize, memory: Arc<MmapMut>) -> DirectDMA {
        DirectDMA {
            offset: offset,
            size: size,
            memory: memory,
        }
    }
}

impl DMAControl for DirectDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        let end = ptr + data.len() as u64;
        if ptr + end > self.size {
            return Err(Error::OutOfRange {
                ptr: ptr,
                end: end,
                size: self.size,
            });
        }

        trace!("Copy Host -> Device(0x{:x}) ({} Bytes)", ptr, data.len());

        // This is necessary as MMapMut is Protected by an Arc but access without
        // an explicit lock is necessary
        // Locking the mmap would slow down PE start etc too much
        unsafe {
            let p = self.memory.as_ptr().offset(ptr as isize) as *mut u8;
            let s = std::ptr::slice_from_raw_parts_mut(p, data.len());
            (*s).clone_from_slice(&data[..]);
        }

        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        let end = ptr + data.len() as u64;
        if ptr + end > self.size {
            return Err(Error::OutOfRange {
                ptr: ptr,
                end: end,
                size: self.size,
            });
        }

        trace!("Copy Device(0x{:x}) -> Host ({} Bytes)", ptr, data.len());

        data[..].clone_from_slice(&self.memory[ptr as usize..end as usize]);

        Ok(())
    }
}
