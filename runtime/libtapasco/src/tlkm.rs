use crate::device::Device;
use crate::device::Error as DevError;
use snafu::ResultExt;
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

    #[snafu(display("Could not create device: {}", source))]
    DeviceError { source: DevError },
}

type Result<T, E = Error> = std::result::Result<T, E>;

pub type DeviceId = u32;

const TLKM_IOC_MAGIC: u8 = b't';
const TLKM_IOCTL_VERSION: u8 = 1;

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

#[derive(Getters)]
pub struct TLKM {
    #[get = "pub"]
    file: File,
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

        Ok(TLKM { file: file })
    }

    fn finish(&mut self) -> Result<()> {
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

    pub fn device_enum(&mut self) -> Result<Vec<Device>> {
        trace!("Fetching available devices from driver.");
        let mut devices: tlkm_ioctl_enum_devices_cmd = Default::default();
        unsafe {
            tlkm_ioctl_enum(self.file.as_raw_fd(), &mut devices).context(IOCTLEnum)?;
        };

        let mut v = Vec::new();

        trace!("There are {} devices.", devices.num_devs);

        for x in 0..devices.num_devs {
            v.push(
                Device::new(
                    &self.file,
                    devices.devs[x].dev_id,
                    devices.devs[x].vendor_id,
                    devices.devs[x].product_id,
                    String::from_utf8_lossy(&devices.devs[x].name).to_string(),
                )
                .context(DeviceError)?,
            );
        }

        trace!("Devices are {:?}.", v);

        Ok(v)
    }
}
