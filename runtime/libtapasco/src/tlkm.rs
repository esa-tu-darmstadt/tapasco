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

use crate::device::Error as DevError;
use crate::device::{Device, DeviceAddress};
use libc::c_char;
use snafu::ResultExt;
use std::ffi::CString;
use std::fs::File;
use std::fs::OpenOptions;
use std::os::unix::prelude::*;
use std::path::PathBuf;
use std::sync::Arc;

#[derive(Debug, Snafu)]
#[repr(C)]
pub enum Error {
    #[snafu(display("Could not open driver chardev {}: {}", filename.display(), source))]
    DriverOpen {
        source: std::io::Error,
        filename: PathBuf,
    },

    #[snafu(display("Could not retrieve version information from driver: {}", source))]
    IOCTLVersion { source: nix::Error },

    #[snafu(display("Could not enumerate devices: {}", source))]
    IOCTLEnum { source: nix::Error },

    #[snafu(display("Could not create device: {}", source))]
    DeviceError { source: DevError },

    #[snafu(display("Error creating CString from Rust: {}", source))]
    FFINulError { source: std::ffi::NulError },

    #[snafu(display("Could not find device {}", id))]
    DeviceNotFound { id: DeviceId },
}

type Result<T, E = Error> = std::result::Result<T, E>;

pub type DeviceId = u32;

const TLKM_VERSION_SZ: usize = 30;
const TLKM_DEVNAME_SZ: usize = 30;
const TLKM_DEVS_SZ: usize = 10;

const TLKM_DEVICE_IOC_MAGIC: u8 = b'd';

const TLKM_DEVICE_IOCTL_ALLOC: u8 = 0x10;
const TLKM_DEVICE_IOCTL_FREE: u8 = 0x11;

#[repr(C)]
#[derive(Default)]
pub struct tlkm_mm_cmd {
    pub sz: usize,
    pub dev_addr: DeviceAddress,
}

ioctl_readwrite!(
    tlkm_ioctl_alloc,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_DEVICE_IOCTL_ALLOC,
    tlkm_mm_cmd
);

ioctl_readwrite!(
    tlkm_ioctl_free,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_DEVICE_IOCTL_FREE,
    tlkm_mm_cmd
);

const TLKM_DEVICE_IOCTL_COPYTO: u8 = 0x12;
const TLKM_DEVICE_IOCTL_COPYFROM: u8 = 0x13;

#[repr(C)]
pub struct tlkm_copy_cmd_from {
    pub length: usize,
    pub user_addr: *mut u8,
    pub dev_addr: DeviceAddress,
}

#[repr(C)]
pub struct tlkm_copy_cmd_to {
    pub length: usize,
    pub user_addr: *const u8,
    pub dev_addr: DeviceAddress,
}

ioctl_readwrite!(
    tlkm_ioctl_copy_to,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_DEVICE_IOCTL_COPYTO,
    tlkm_copy_cmd_to
);

ioctl_readwrite!(
    tlkm_ioctl_copy_from,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_DEVICE_IOCTL_COPYFROM,
    tlkm_copy_cmd_from
);

const TLKM_IOC_MAGIC: u8 = b't';
const TLKM_IOCTL_VERSION: u8 = 1;

#[repr(C)]
#[derive(Default)]
pub struct tlkm_ioctl_version_cmd {
    version: [u8; TLKM_VERSION_SZ],
}

ioctl_readwrite!(
    tlkm_ioctl_version,
    TLKM_IOC_MAGIC,
    TLKM_IOCTL_VERSION,
    tlkm_ioctl_version_cmd
);

const TLKM_IOCTL_ENUM_DEVICES: u8 = 2;

#[repr(C)]
#[derive(Default)]
pub struct tlkm_device_info {
    dev_id: DeviceId,
    vendor_id: u32,
    product_id: u32,
    name: [u8; TLKM_DEVNAME_SZ],
}

#[repr(C)]
#[derive(Default)]
pub struct tlkm_ioctl_enum_devices_cmd {
    num_devs: usize,
    devs: [tlkm_device_info; TLKM_DEVS_SZ],
}

ioctl_readwrite!(
    tlkm_ioctl_enum,
    TLKM_IOC_MAGIC,
    TLKM_IOCTL_ENUM_DEVICES,
    tlkm_ioctl_enum_devices_cmd
);

#[repr(C)]
#[derive(Debug, PartialEq, Clone, Copy)]
pub enum tlkm_access {
    TlkmAccessExclusive = 0,
    TlkmAccessMonitor,
    TlkmAccessShared,
    TlkmAccessTypes,
}

#[repr(C)]
#[derive(Debug, Getters, Setters, PartialEq)]
pub struct tlkm_ioctl_device_cmd {
    #[get = "pub"]
    pub dev_id: DeviceId,

    #[get = "pub"]
    #[set = "pub"]
    pub access: tlkm_access,
}

const TLKM_IOCTL_CREATE_DEVICE: u8 = 3;
const TLKM_IOCTL_DESTROY_DEVICE: u8 = 4;

ioctl_readwrite!(
    tlkm_ioctl_create,
    TLKM_IOC_MAGIC,
    TLKM_IOCTL_CREATE_DEVICE,
    tlkm_ioctl_device_cmd
);

ioctl_readwrite!(
    tlkm_ioctl_destroy,
    TLKM_IOC_MAGIC,
    TLKM_IOCTL_DESTROY_DEVICE,
    tlkm_ioctl_device_cmd
);

pub struct TLKM {
    file: Arc<File>,
}

impl Drop for TLKM {
    fn drop(&mut self) {
        match self.finish() {
            Ok(_) => (),
            Err(e) => panic!("{}", e),
        }
    }
}

#[derive(Debug, Copy, Clone, CopyGetters)]
#[repr(C)]
pub struct DeviceInfo {
    id: DeviceId,
    vendor: u32,
    product: u32,
    #[get_copy = "pub"]
    name: *const c_char,
}

impl TLKM {
    pub fn new() -> Result<TLKM> {
        let path = PathBuf::from(r"/dev/tlkm");
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/tlkm")
            .context(DriverOpen { filename: path })?;

        Ok(TLKM {
            file: Arc::new(file),
        })
    }

    fn finish(&mut self) -> Result<()> {
        trace!("TLKM object destroyed.");
        Ok(())
    }

    pub fn version(&self) -> Result<String> {
        let mut version: tlkm_ioctl_version_cmd = Default::default();
        unsafe {
            tlkm_ioctl_version(self.file.as_raw_fd(), &mut version).context(IOCTLVersion)?;
        };

        let s = String::from_utf8_lossy(&version.version)
            .trim_matches(char::from(0))
            .to_string();
        trace!("Retrieved TLKM version as {}", s);
        Ok(s.to_string())
    }

    pub fn device_enum_len(&self) -> Result<usize> {
        trace!("Fetching available devices from driver.");
        let mut devices: tlkm_ioctl_enum_devices_cmd = Default::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnum)?;
        };

        trace!("There are {} devices.", devices.num_devs);

        Ok(devices.num_devs)
    }

    pub fn device_enum_info(&self) -> Result<Vec<DeviceInfo>> {
        trace!("Fetching available devices from driver.");
        let mut devices: tlkm_ioctl_enum_devices_cmd = Default::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnum)?;
        };

        trace!("There are {} devices.", devices.num_devs);

        let mut v = Vec::new();

        for x in 0..devices.num_devs {
            if devices.devs[x].dev_id != x as u32 {
                warn!("Got device ID mismatch. Falling back to own counting, assuming old TLKM: TLKM: {} vs Counting: {}", 
                    devices.devs[x].dev_id, x);
                devices.devs[x].dev_id = x as u32;
            }
            v.push(DeviceInfo {
                id: devices.devs[x].dev_id,
                vendor: devices.devs[x].vendor_id,
                product: devices.devs[x].product_id,
                name: CString::new(
                    String::from_utf8_lossy(&devices.devs[x].name)
                        .trim_matches(char::from(0))
                        .to_string(),
                )
                .context(FFINulError)?
                .into_raw(),
            });
        }

        Ok(v)
    }

    pub fn device_alloc(&self, id: DeviceId) -> Result<Device> {
        trace!("Fetching available devices from driver.");
        let mut devices: tlkm_ioctl_enum_devices_cmd = Default::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnum)?;
        };

        trace!("There are {} devices.", devices.num_devs);

        for x in 0..devices.num_devs {
            if devices.devs[x].dev_id != x as u32 {
                warn!("Got device ID mismatch. Falling back to own counting, assuming old TLKM: TLKM: {} vs Counting: {}", 
                    devices.devs[x].dev_id, x);
                devices.devs[x].dev_id = x as u32;
            }
            if devices.devs[x].dev_id == id {
                return Ok(Device::new(
                    self.file.clone(),
                    devices.devs[x].dev_id,
                    devices.devs[x].vendor_id,
                    devices.devs[x].product_id,
                    String::from_utf8_lossy(&devices.devs[x].name)
                        .trim_matches(char::from(0))
                        .to_string(),
                )
                .context(DeviceError)?);
            }
        }
        Err(Error::DeviceNotFound { id: id })
    }

    pub fn device_enum(&self) -> Result<Vec<Device>> {
        trace!("Fetching available devices from driver.");
        let mut devices: tlkm_ioctl_enum_devices_cmd = Default::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnum)?;
        };

        let mut v = Vec::new();

        trace!("There are {} devices.", devices.num_devs);

        for x in 0..devices.num_devs {
            if devices.devs[x].dev_id != x as u32 {
                warn!("Got device ID mismatch. Falling back to own counting, assuming old TLKM: TLKM: {} vs Counting: {}", 
                    devices.devs[x].dev_id, x);
                devices.devs[x].dev_id = x as u32;
            }
            v.push(
                Device::new(
                    self.file.clone(),
                    devices.devs[x].dev_id,
                    devices.devs[x].vendor_id,
                    devices.devs[x].product_id,
                    String::from_utf8_lossy(&devices.devs[x].name)
                        .trim_matches(char::from(0))
                        .to_string(),
                )
                .context(DeviceError)?,
            );
        }

        trace!("Devices are {:?}.", v);

        Ok(v)
    }
}
