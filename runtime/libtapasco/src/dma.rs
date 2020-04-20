use crate::device::DeviceAddress;
use crate::tlkm::TLKM;

#[derive(Debug, Snafu, PartialEq)]
pub enum Error {}
type Result<T, E = Error> = std::result::Result<T, E>;

pub trait DMAControl {
    fn copy_to(&self, tlkm: &mut TLKM, data: &[u8], ptr: DeviceAddress) -> Result<()>;
    fn copy_from(&self, tlkm: &mut TLKM, ptr: DeviceAddress, data: &mut [u8]) -> Result<()>;
}

impl std::fmt::Debug for dyn DMAControl {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

#[derive(Debug, Getters)]
pub struct DriverDMA {}

impl DMAControl for DriverDMA {
    fn copy_to(&self, tlkm: &mut TLKM, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        Ok(())
    }

    fn copy_from(&self, tlkm: &mut TLKM, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        Ok(())
    }
}
