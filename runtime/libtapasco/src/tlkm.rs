use crate::snafu::ResultExt;
use std::fs::File;
use std::fs::OpenOptions;
use std::os::unix::prelude::*;
use std::path::PathBuf;

#[derive(Debug, Snafu)]
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

    #[snafu(display(
        "Could not acquire desired mode {:?} for device {}: {}",
        access,
        dev_id,
        source
    ))]
    IOCTLCreate {
        source: nix::Error,
        dev_id: u32,
        access: tlkm_access,
    },

    #[snafu(display("Could not destroy device {}: {}", dev_id, source))]
    IOCTLDestroy { source: nix::Error, dev_id: u32 },

    #[snafu(display("Device {} is unknown. Can't set access.", dev_id))]
    UnknownDeviceAccess { dev_id: u32 },

    #[snafu(display("Device {} is unknown. Can't destroy it.", dev_id))]
    UnknownDeviceDestroy { dev_id: u32 },
}

type Result<T, E = Error> = std::result::Result<T, E>;

pub type DeviceId = u32;

const TLKM_IOC_MAGIC: u8 = b't';
const TLKM_IOCTL_VERSION: u8 = 1;

const TLKM_IOCTL_DESTROY_DEVICE: u8 = 4;

const TLKM_VERSION_SZ: usize = 30;
const TLKM_DEVNAME_SZ: usize = 30;
const TLKM_DEVS_SZ: usize = 10;

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
    TlkmAccessTypes, /* length and sentinel */
}

#[repr(C)]
#[derive(Debug, Getters, Setters, PartialEq)]
pub struct tlkm_ioctl_device_cmd {
    #[get = "pub"]
    dev_id: DeviceId,

    #[get = "pub"]
    #[set = "pub"]
    access: tlkm_access,
}

const TLKM_IOCTL_CREATE_DEVICE: u8 = 3;

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

#[derive(Debug, Getters, PartialEq)]
pub struct TLKMDevice {
    #[get = "pub"]
    id: DeviceId,
    #[get = "pub"]
    vendor: u32,
    #[get = "pub"]
    product: u32,
    #[get = "pub"]
    name: String,
}

#[derive(Getters)]
pub struct TLKM {
    file: File,
    #[get = "pub"]
    devices: Vec<TLKMDevice>,
    allocated: Vec<tlkm_ioctl_device_cmd>,
}

impl Drop for TLKM {
    fn drop(&mut self) {
        match self.finish() {
            Ok(_) => (),
            Err(e) => panic!("{}", e),
        }
    }
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
            file: file,
            devices: Vec::new(),
            allocated: Vec::new(),
        })
    }

    fn finish(&mut self) -> Result<()> {
        for device in self.allocated.iter() {
            match self.devices.iter().find(|&x| *x.id() == *device.dev_id()) {
                Some(d) => {
                    let mut tmp = tlkm_ioctl_device_cmd {
                        dev_id: *device.dev_id(),
                        access: *device.access(),
                    };
                    unsafe {
                        tlkm_ioctl_destroy(self.file.as_raw_fd(), &mut tmp)
                            .context(IOCTLDestroy { dev_id: *d.id() })?;
                    };
                }
                _ => {}
            }
        }
        Ok(())
    }

    pub fn version(&self) -> Result<String> {
        let mut version: tlkm_ioctl_version_cmd = Default::default();
        unsafe {
            tlkm_ioctl_version(self.file.as_raw_fd(), &mut version).context(IOCTLVersion)?;
        };

        let s = String::from_utf8_lossy(&version.version);
        trace!("Retrieved TLKM version as {}", s);
        Ok(s.to_string())
    }

    pub fn device_enum(&mut self) -> Result<&Vec<TLKMDevice>> {
        if self.devices.len() == 0 {
            trace!("Fetching available devices from driver.");
            let mut devices: tlkm_ioctl_enum_devices_cmd = Default::default();
            unsafe {
                tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnum)?;
            };

            let mut v = Vec::new();

            trace!("There are {} devices.", devices.num_devs);

            for x in 0..devices.num_devs {
                v.push(TLKMDevice {
                    id: devices.devs[x].dev_id,
                    vendor: devices.devs[x].vendor_id,
                    product: devices.devs[x].product_id,
                    name: String::from_utf8_lossy(&devices.devs[x].name).to_string(),
                });
            }

            trace!("Devices are {:?}.", v);

            self.devices = v;
        }
        Ok(&self.devices)
    }

    pub fn device_create(&mut self, dev_id: DeviceId, access: tlkm_access) -> Result<()> {
        ensure!(
            self.devices.iter().find(|&x| x.id == dev_id).is_some(),
            UnknownDeviceAccess { dev_id: dev_id }
        );

        match self.allocated.iter().find(|&x| x.dev_id == dev_id) {
            Some(d) => {
                if d.access == access {
                    trace!(
                        "Device {} is already in access mode {:?}.",
                        d.dev_id,
                        d.access
                    );
                    return Ok(());
                } else {
                    self.device_destroy(dev_id)?;
                }
            }
            _ => {}
        }

        let mut request = tlkm_ioctl_device_cmd {
            dev_id: dev_id,
            access: access,
        };

        trace!(
            "Trying to acquire mode {:?} for device {}.",
            request.access,
            request.dev_id
        );

        unsafe {
            tlkm_ioctl_create(self.file.as_raw_fd(), &mut request).context(IOCTLCreate {
                access: request.access,
                dev_id: request.dev_id,
            })?;
        };

        trace!("Successfully acquired access.");
        self.allocated.push(request);

        Ok(())
    }

    pub fn device_destroy(&mut self, dev_id: DeviceId) -> Result<()> {
        match self.allocated.iter().find(|&x| x.dev_id == dev_id) {
            Some(d) => {
                let mut request = tlkm_ioctl_device_cmd {
                    dev_id: *d.dev_id(),
                    access: *d.access(),
                };
                unsafe {
                    tlkm_ioctl_destroy(self.file.as_raw_fd(), &mut request).context(
                        IOCTLDestroy {
                            dev_id: request.dev_id,
                        },
                    )?;
                };
            }
            _ => {
                return Err(Error::UnknownDeviceDestroy { dev_id: dev_id });
            }
        }

        Ok(())
    }
}
