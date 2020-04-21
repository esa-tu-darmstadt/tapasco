use crate::device::DeviceAddress;
use crate::tlkm::tlkm_copy_cmd_from;
use crate::tlkm::tlkm_copy_cmd_to;
use crate::tlkm::tlkm_ioctl_copy_from;
use crate::tlkm::tlkm_ioctl_copy_to;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;

#[derive(Debug, Snafu, PartialEq)]
pub enum Error {
    #[snafu(display("Could not transfer to device {}", source))]
    DMAToDevice { source: nix::Error },

    #[snafu(display("Could not transfer from device {}", source))]
    DMAFromDevice { source: nix::Error },
}
type Result<T, E = Error> = std::result::Result<T, E>;

pub trait DMAControl {
    fn copy_to(&self, tlkm_file: &File, data: &[u8], ptr: DeviceAddress) -> Result<()>;
    fn copy_from(&self, tlkm_file: &File, ptr: DeviceAddress, data: &mut [u8]) -> Result<()>;
}

impl std::fmt::Debug for dyn DMAControl {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

#[derive(Debug, Getters)]
pub struct DriverDMA {}

impl DMAControl for DriverDMA {
    fn copy_to(&self, tlkm_file: &File, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        trace!("Copy Host -> Device(0x{:x}) ({} Bytes)", ptr, data.len());
        unsafe {
            tlkm_ioctl_copy_to(
                tlkm_file.as_raw_fd(),
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

    fn copy_from(&self, tlkm_file: &File, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        trace!("Copy Device(0x{:x}) -> Host ({} Bytes)", ptr, data.len());
        unsafe {
            tlkm_ioctl_copy_from(
                tlkm_file.as_raw_fd(),
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
