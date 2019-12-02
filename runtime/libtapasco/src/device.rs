use crate::snafu::ResultExt;
use crate::tlkm::DeviceId;
use memmap::MmapOptions;
use prost::Message;
use std::fs::OpenOptions;

pub mod status {
    include!(concat!(env!("OUT_DIR"), "/tapasco.status.rs"));
}

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Device {} unavailable: {}", dev_id, source))]
    DeviceUnavailable {
        source: std::io::Error,
        dev_id: DeviceId,
    },

    #[snafu(display("Decoding the status core failed: {}", source))]
    StatusCoreDecoding { source: prost::DecodeError },
}
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug, Getters, PartialEq)]
pub struct Device {
    dev_id: DeviceId,
    #[get = "pub"]
    status: status::Status,
}

impl Device {
    pub fn new(id: DeviceId) -> Result<Device> {
        let file = OpenOptions::new()
            .read(true)
            .open(format!("/dev/tlkm_{:02}", id))
            .context(DeviceUnavailable { dev_id: id })?;

        let mmap = unsafe {
            MmapOptions::new()
                .len(8192)
                .offset(0)
                .map(&file)
                .context(DeviceUnavailable { dev_id: id })?
        };

        let s = status::Status::decode_length_delimited(&mmap[..]).context(StatusCoreDecoding)?;

        Ok(Device {
            dev_id: id,
            status: s,
        })
    }
}
