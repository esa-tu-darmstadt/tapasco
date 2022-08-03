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
 * along with this program. If not, see <http:///www.gnu.org/licenses/>.
 */

use crate::debug::DebugGenerator;
use crate::device::Error as DevError;
use crate::device::{Device, DeviceAddress};
use config::Config;
use libc::c_char;
use snafu::ResultExt;
use std::collections::HashMap;
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

    #[snafu(display("Could not parse configuration {}", source))]
    ConfigError { source: config::ConfigError },

    #[snafu(display("Could not transform string for device name {}", source))]
    StringError { source: core::array::TryFromSliceError }
}

type Result<T, E = Error> = std::result::Result<T, E>;

// IOCTLs taken from TLKM
//
// These are mappings from the C version of the IOCTLs
// to the rust version using the ioctl wrapper. Please refer to the
// corresponding TLKM documentation in `tapasco/runtime/kernel` for more information.

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

const TLKM_DEVICE_IOCTL_REGISTER_INTERRUPT: u8 = 0x14;

#[repr(C)]
pub struct tlkm_register_interrupt {
    pub pe_id: i32,
    pub fd: i32,
}

ioctl_readwrite!(
    tlkm_ioctl_reg_interrupt,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_DEVICE_IOCTL_REGISTER_INTERRUPT,
    tlkm_register_interrupt
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

// User space DMA
#[repr(C)]
#[derive(Debug, PartialEq)]
pub struct tlkm_dma_buffer_allocate {
    pub size: usize,
    pub from_device: bool,
    pub buffer_id: usize,
    pub addr: u64,
}

#[repr(C)]
#[derive(Debug, PartialEq)]
pub struct tlkm_dma_buffer_op {
    pub buffer_id: usize,
}

const TLKM_IOCTL_DMA_BUFFER_ALLOCATE: u8 = 0x40;
const TLKM_IOCTL_DMA_BUFFER_FREE: u8 = 0x41;
const TLKM_IOCTL_DMA_BUFFER_TO_DEV: u8 = 0x42;
const TLKM_IOCTL_DMA_BUFFER_FROM_DEV: u8 = 0x43;

ioctl_readwrite!(
    tlkm_ioctl_dma_buffer_allocate,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_DMA_BUFFER_ALLOCATE,
    tlkm_dma_buffer_allocate
);

ioctl_readwrite!(
    tlkm_ioctl_dma_buffer_free,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_DMA_BUFFER_FREE,
    tlkm_dma_buffer_op
);

ioctl_readwrite!(
    tlkm_ioctl_dma_buffer_to_dev,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_DMA_BUFFER_TO_DEV,
    tlkm_dma_buffer_op
);

ioctl_readwrite!(
    tlkm_ioctl_dma_buffer_from_dev,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_DMA_BUFFER_FROM_DEV,
    tlkm_dma_buffer_op
);

// SVM
#[repr(C)]
#[derive(Debug, PartialEq)]
pub struct tlkm_svm_init_cmd {
    pub result: i32,
}

#[repr(C)]
#[derive(Debug, PartialEq)]
pub struct tlkm_svm_migrate_cmd {
    pub vaddr: u64,
    pub size: u64,
}

const TLKM_IOCTL_SVM_LAUNCH: u8 = 0x50;
const TLKM_IOCTL_SVM_MIGRATE_TO_DEV: u8 = 0x52;
const TLKM_IOCTL_SVM_MIGRATE_TO_RAM: u8 = 0x53;

ioctl_readwrite!(tlkm_ioctl_svm_launch,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_SVM_LAUNCH,
    tlkm_svm_init_cmd
);

ioctl_readwrite!(tlkm_ioctl_svm_migrate_to_dev,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_SVM_MIGRATE_TO_DEV,
    tlkm_svm_migrate_cmd
);

ioctl_readwrite!(tlkm_ioctl_svm_migrate_to_ram,
    TLKM_DEVICE_IOC_MAGIC,
    TLKM_IOCTL_SVM_MIGRATE_TO_RAM,
    tlkm_svm_migrate_cmd
);

// End of IOCTL definitions.

/// TLKM IOCTL convenience access
///
/// This struct combines all basic interactions with TLKM
/// and makes them accessible to the outside world. During
/// initialization the driver is opened once and the file
/// handle is stored for future accesses.

pub struct TLKM {
    file: Arc<File>,
    settings: Arc<Config>,
}

/// Helper structure for device information
///
/// Retrieved from TLKM and used to create a device structure
/// for use in the driver. Only used to provide information.
#[derive(Debug, Copy, Clone, CopyGetters)]
#[repr(C)]
pub struct DeviceInfo {
    id: DeviceId,
    vendor: u32,
    product: u32,
    #[get_copy = "pub"]
    name: *const c_char,
}

impl Drop for TLKM {
    fn drop(&mut self) {
        trace!("Dropping TLKM driver.");
    }
}

impl TLKM {
    /// Open the driver chardev.
    pub fn new() -> Result<Self> {
        let default_config = include_str!("../config/default.toml");
        let settings = Config::builder()
            .add_source(config::File::from_str(
                default_config,
                config::FileFormat::Toml,
            ))
            .add_source(config::File::with_name("/etc/tapasco/TapascoConfig").required(false))
            .add_source(config::File::with_name("TapascoConfig").required(false))
            .add_source(config::Environment::with_prefix("tapasco").separator("__"))
            .build()
            .context(ConfigSnafu)?;

        trace!("Using config: {:?}", settings);

        let path = PathBuf::from(
            settings
                .get_string("tlkm.main_driver_file")
                .context(ConfigSnafu)?,
        );
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .open(&path)
            .context(DriverOpenSnafu { filename: path })?;

        Ok(Self {
            file: Arc::new(file),
            settings: Arc::new(settings),
        })
    }

    /// Retrieve version information from TLKM
    ///
    /// The version is provided as an undocumented string.
    /// Unstable and not intended for parsing by downstream code.
    pub fn version(&self) -> Result<String> {
        let mut version = tlkm_ioctl_version_cmd::default();
        unsafe {
            tlkm_ioctl_version(self.file.as_raw_fd(), &mut version).context(IOCTLVersionSnafu)?;
        };

        let s = String::from_utf8_lossy(&version.version)
            .trim_matches(char::from(0))
            .to_string();
        trace!("Retrieved TLKM version as {}", s);
        Ok(s)
    }

    /// Retrieve length of device enumeration structure.
    ///
    /// Normally used in conjunction with [`device_enum_info`].
    /// Can also be used to check that devices available for enumeration.
    ///
    /// [`device_enum_info`]: #method.device_enum_info
    pub fn device_enum_len(&self) -> Result<usize> {
        trace!("Fetching available devices from driver.");
        let mut devices = tlkm_ioctl_enum_devices_cmd::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnumSnafu)?;
        };

        // self.device_info_add_sim_device(&mut devices);

        trace!("There are {} devices.", devices.num_devs);

        Ok(devices.num_devs)
    }

    fn device_info_add_sim_device(&self, devices: &mut tlkm_ioctl_enum_devices_cmd) {
        let mut name: [u8; 30] = [0; 30];
        for (i, val) in String::from("TapascoSim").as_bytes().iter().enumerate() {
            if i >= 30 {
                break;
            }

            name[i] = *val;
        }

        let sim_dev = tlkm_device_info {
            dev_id: devices.num_devs as DeviceId,
            vendor_id: 0,
            product_id: 0,
            name
        };

        devices.devs[devices.num_devs] = sim_dev;
        devices.num_devs += 1;
    }

    /// Retrieve device info from the driver.
    ///
    /// Returns a vector of [`DeviceInfo`] structures for informational purposes.
    ///
    /// [`DeviceInfo`]: struct.DeviceInfo.html
    pub fn device_enum_info(&self) -> Result<Vec<DeviceInfo>> {
        trace!("Fetching available devices from driver.");
        let mut devices = tlkm_ioctl_enum_devices_cmd::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnumSnafu)?;
        };

        // self.device_info_add_sim_device(&mut devices);

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
                .context(FFINulSnafu)?
                .into_raw(),
            });
        }

        Ok(v)
    }

    /// Allocates a single device from TLKM.
    ///
    /// The resulting device can be used for all further interaction with
    /// the TaPaSCo device.
    ///
    /// # Arguments
    ///  * Device IDs retrieved from [`device_enum_info`].
    ///
    /// Returns [`Device`] with provided id.
    ///
    /// [`Device`]: ../device/struct.Device.html
    /// [`device_enum_info`]: #method.device_enum_info
    pub fn device_alloc(
        &self,
        id: DeviceId,
        debug_impls: &HashMap<String, Box<dyn DebugGenerator + Sync + Send>>,
    ) -> Result<Device> {
        trace!("Fetching available devices from driver.");
        let mut devices = tlkm_ioctl_enum_devices_cmd::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnumSnafu)?;
        };

        // self.device_info_add_sim_device(&mut devices);

        trace!("There are {} devices.", devices.num_devs);

        for x in 0..devices.num_devs {
            if devices.devs[x].dev_id != x as u32 {
                warn!("Got device ID mismatch. Falling back to own counting, assuming old TLKM: TLKM: {} vs Counting: {}",
                    devices.devs[x].dev_id, x);
                devices.devs[x].dev_id = x as u32;
            }
            if devices.devs[x].dev_id == id {
                return Device::new(
                    self.file.clone(),
                    devices.devs[x].dev_id,
                    devices.devs[x].vendor_id,
                    devices.devs[x].product_id,
                    String::from_utf8_lossy(&devices.devs[x].name)
                        .trim_matches(char::from(0))
                        .to_string(),
                    self.settings.clone(),
                    debug_impls,
                )
                .context(DeviceSnafu);
            }
        }
        Err(Error::DeviceNotFound { id })
    }

    /// Allocates all devices available.
    ///
    /// Same functionality as [`device_alloc`] but allocates
    /// all available devices as shown by [`device_enum_info`].
    ///
    /// [`device_alloc`]: #method.device_alloc
    /// [`device_enum_info`]: #method.device_enum_info
    pub async fn device_enum(
        &self,
        debug_impls: &HashMap<String, Box<dyn DebugGenerator + Sync + Send>>,
    ) -> Result<Vec<Device>> {
        trace!("Fetching available devices from driver.");
        let mut devices = tlkm_ioctl_enum_devices_cmd::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnumSnafu)?;
        };

        let mut v = Vec::new();

        // self.device_info_add_sim_device(&mut devices);

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
                    self.settings.clone(),
                    debug_impls,
                )
                .context(DeviceSnafu)?,
            );
        }

        trace!("Devices are {:?}.", v);

        Ok(v)
    }
}
