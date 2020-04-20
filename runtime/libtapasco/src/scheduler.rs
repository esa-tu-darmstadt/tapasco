use crate::device::{DeviceAddress, DeviceSize, PEParameter};
use memmap::Mmap;
use memmap::MmapMut;
use std::collections::HashMap;
use volatile::Volatile;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("PE Type {} unavailable.", id))]
    PEUnavailable { id: PEId },

    #[snafu(display("PE Type {} is unknown.", id))]
    NoSuchPE { id: PEId },

    #[snafu(display("PE {} is already running.", id))]
    PEAlreadyActive { id: usize },

    #[snafu(display("PE {} is still active. Can't release it.", pe.id))]
    PEStillActive { pe: PE },

    #[snafu(display(
        "Param {:?} is unsupported. Only 32 and 64 Bit value can interact with device registers.",
        param
    ))]
    UnsupportedParameter { param: PEParameter },

    #[snafu(display(
        "Transfer width {} Bit is unsupported. Only 32 and 64 Bit value can interact with device registers.",
        param * 8
    ))]
    UnsupportedRegisterSize { param: usize },
}

type Result<T, E = Error> = std::result::Result<T, E>;

pub type PEId = usize;

#[derive(Debug, PartialEq, Getters, Setters)]
pub struct PE {
    #[get = "pub"]
    id: usize,
    type_id: PEId,
    offset: DeviceAddress,
    size: DeviceSize,
    name: String,
    #[set = "pub"]
    #[get = "pub"]
    active: bool,
}

impl PE {
    pub fn start(&mut self, mem: &mut MmapMut) -> Result<()> {
        ensure!(!self.active, PEAlreadyActive { id: self.id });
        let offset = self.offset as isize;
        unsafe {
            let ptr = mem.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        self.active = true;
        Ok(())
    }

    pub fn reset_interrupt(&mut self, mem: &mut MmapMut) -> Result<()> {
        ensure!(!self.active, PEAlreadyActive { id: self.id });
        let offset = (self.offset as usize + 0x0c) as isize;
        unsafe {
            let ptr = mem.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        Ok(())
    }

    pub fn enable_interrupt(&mut self, mem: &mut MmapMut) -> Result<()> {
        ensure!(!self.active, PEAlreadyActive { id: self.id });
        let mut offset = (self.offset as usize + 0x04) as isize;
        unsafe {
            let ptr = mem.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        offset = (self.offset as usize + 0x08) as isize;
        unsafe {
            let ptr = mem.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u32>;
            (*volatile_ptr).write(1);
        }
        Ok(())
    }

    pub fn set_arg(&self, mem: &mut MmapMut, argn: usize, arg: PEParameter) -> Result<()> {
        let offset = (self.offset as usize + 0x20 + argn * 0x10) as isize;
        unsafe {
            let ptr = mem.as_ptr().offset(offset);
            match arg {
                PEParameter::Single32(x) => (*(ptr as *mut Volatile<u32>)).write(x),
                PEParameter::Single64(x) => (*(ptr as *mut Volatile<u64>)).write(x),
                _ => return Err(Error::UnsupportedParameter { param: arg }),
            };
        }
        Ok(())
    }

    pub fn read_arg(&self, mem: &Mmap, argn: usize, bytes: usize) -> Result<PEParameter> {
        let offset = (self.offset as usize + 0x20 + argn * 0x10) as isize;
        unsafe {
            let ptr = mem.as_ptr().offset(offset);
            match bytes {
                4 => Ok(PEParameter::Single32(
                    (*(ptr as *const Volatile<u32>)).read(),
                )),
                8 => Ok(PEParameter::Single64(
                    (*(ptr as *const Volatile<u64>)).read(),
                )),
                _ => Err(Error::UnsupportedRegisterSize { param: bytes }),
            }
        }
    }
}

#[derive(Debug, PartialEq)]
pub struct Scheduler {
    pes: HashMap<PEId, Vec<PE>>,
}

impl Scheduler {
    pub fn new(pes: &Vec<crate::device::status::Pe>) -> Result<Scheduler> {
        let mut pe_hashed: HashMap<PEId, Vec<PE>> = HashMap::new();
        for (i, pe) in pes.iter().enumerate() {
            let the_pe = PE {
                active: false,
                id: i,
                offset: pe.offset,
                size: pe.size,
                name: pe.name.to_string(),
                type_id: pe.id as PEId,
            };
            match pe_hashed.get_mut(&(pe.id as PEId)) {
                Some(l) => l.push(the_pe),
                None => {
                    trace!("New PE type found: {}.", pe.id);
                    let mut v = Vec::new();
                    v.push(the_pe);
                    pe_hashed.insert(pe.id as PEId, v);
                }
            }
        }

        Ok(Scheduler { pes: pe_hashed })
    }

    pub fn acquire_pe(&mut self, id: PEId) -> Result<PE> {
        match self.pes.get_mut(&id) {
            Some(l) => match l.pop() {
                Some(pe) => return Ok(pe),
                None => Err(Error::PEUnavailable { id }),
            },
            None => return Err(Error::NoSuchPE { id }),
        }
    }

    pub fn release_pe(&mut self, pe: PE) -> Result<()> {
        ensure!(!pe.active, PEStillActive { pe: pe });

        match self.pes.get_mut(&pe.type_id) {
            Some(l) => l.push(pe),
            None => return Err(Error::NoSuchPE { id: pe.type_id }),
        }
        Ok(())
    }

    pub fn reset_interrupts(&mut self, mem: &mut MmapMut) -> Result<()> {
        for (_, v) in self.pes.iter_mut() {
            for pe in v.iter_mut() {
                pe.enable_interrupt(mem)?;
                pe.reset_interrupt(mem)?;
            }
        }

        Ok(())
    }
}
