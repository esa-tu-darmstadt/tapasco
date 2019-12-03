use crate::tlkm::tlkm_access;
use crate::tlkm::tlkm_ioctl_create;
use crate::tlkm::tlkm_ioctl_destroy;
use crate::tlkm::tlkm_ioctl_device_cmd;
use crate::tlkm::DeviceId;
use memmap::MmapOptions;
use prost::Message;
use snafu::ResultExt;
use std::fs::File;
use std::fs::OpenOptions;
use std::os::unix::io::AsRawFd;

pub mod status {
    include!(concat!(env!("OUT_DIR"), "/tapasco.status.rs"));
}

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Device {} unavailable: {}", id, source))]
    DeviceUnavailable {
        source: std::io::Error,
        id: DeviceId,
    },

    #[snafu(display("Decoding the status core failed: {}", source))]
    StatusCoreDecoding { source: prost::DecodeError },

    #[snafu(display(
        "Could not acquire desired mode {:?} for device {}: {}",
        access,
        id,
        source
    ))]
    IOCTLCreate {
        source: nix::Error,
        id: DeviceId,
        access: tlkm_access,
    },

    #[snafu(display("Could not destroy device {}: {}", id, source))]
    IOCTLDestroy { source: nix::Error, id: DeviceId },
}
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug, Getters, PartialEq)]
pub struct Device {
    #[get = "pub"]
    status: status::Status,
    #[get = "pub"]
    id: DeviceId,
    #[get = "pub"]
    vendor: u32,
    #[get = "pub"]
    product: u32,
    #[get = "pub"]
    name: String,
    access: tlkm_access,
}

impl Drop for TLKM {
    fn drop(&mut self) {
        match self.finish() {
            Ok(_) => (),
            Err(e) => panic!("{}", e),
        }
    }
}

impl Device {
    pub fn new(
        tlkm_file: &File,
        id: DeviceId,
        vendor: u32,
        product: u32,
        name: String,
    ) -> Result<Device> {
        let file = OpenOptions::new()
            .read(true)
            .open(format!("/dev/tlkm_{:02}", id))
            .context(DeviceUnavailable { id: id })?;

        let mmap = unsafe {
            MmapOptions::new()
                .len(8192)
                .offset(0)
                .map(&file)
                .context(DeviceUnavailable { id: id })?
        };

        let s = status::Status::decode_length_delimited(&mmap[..]).context(StatusCoreDecoding)?;

        let mut device = Device {
            id: id,
            vendor: vendor,
            product: product,
            access: tlkm_access::TlkmAccessTypes,
            name: name,
            status: s,
        };

        device.create(&tlkm_file, tlkm_access::TlkmAccessMonitor)?;

        Ok(device)
    }

    fn finish(&mut self) -> Result<()> {
        Ok(())
    }

    pub fn create(&mut self, tlkm_file: &File, access: tlkm_access) -> Result<()> {
        if self.access == access {
            trace!(
                "Device {} is already in access mode {:?}.",
                self.id,
                self.access
            );
            return Ok(());
        }

        self.destroy(tlkm_file)?;

        let mut request = tlkm_ioctl_device_cmd {
            dev_id: self.id,
            access: access,
        };

        trace!("Device {}: Trying to change mode to {:?}", self.id, access,);

        unsafe {
            tlkm_ioctl_create(tlkm_file.as_raw_fd(), &mut request).context(IOCTLCreate {
                access: access,
                id: self.id,
            })?;
        };

        self.access = access;

        trace!("Successfully acquired access.");
        Ok(())
    }

    pub fn destroy(&mut self, tlkm_file: &File) -> Result<()> {
        if self.access != tlkm_access::TlkmAccessTypes {
            trace!("Device {}: Removing access mode {:?}", self.id, self.access,);
            let mut request = tlkm_ioctl_device_cmd {
                dev_id: self.id,
                access: self.access,
            };
            unsafe {
                tlkm_ioctl_destroy(tlkm_file.as_raw_fd(), &mut request)
                    .context(IOCTLDestroy { id: self.id })?;
            }
            self.access = tlkm_access::TlkmAccessTypes;
        }

        Ok(())
    }
}
