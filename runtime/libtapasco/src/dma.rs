use crate::device::DeviceAddress;
use crate::tlkm::tlkm_copy_cmd_from;
use crate::tlkm::tlkm_copy_cmd_to;
use crate::tlkm::tlkm_ioctl_copy_from;
use crate::tlkm::tlkm_ioctl_copy_to;
use core::fmt::Debug;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;
use std::sync::Arc;

#[derive(Debug, Snafu, PartialEq)]
pub enum Error {
    #[snafu(display("Could not transfer to device {}", source))]
    DMAToDevice { source: nix::Error },

    #[snafu(display("Could not transfer from device {}", source))]
    DMAFromDevice { source: nix::Error },
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
