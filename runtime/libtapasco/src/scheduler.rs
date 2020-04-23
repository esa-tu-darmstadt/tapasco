use crate::pe::PEId;
use crate::pe::PE;
use lockfree::set::Set;
use memmap::MmapMut;
use snafu::ResultExt;
use std::collections::HashMap;
use std::fs::File;
use std::sync::{Arc, Mutex};

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("PE Type {} unavailable.", id))]
    PEUnavailable { id: PEId },

    #[snafu(display("PE Type {} is unknown.", id))]
    NoSuchPE { id: PEId },

    #[snafu(display("PE {} is still active. Can't release it.", pe.id()))]
    PEStillActive { pe: PE },

    #[snafu(display("PE Error: {}", source))]
    PEError { source: crate::pe::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug)]
pub struct Scheduler {
    pes: HashMap<PEId, Vec<PE>>,
}

impl Scheduler {
    pub fn new(
        pes: &Vec<crate::device::status::Pe>,
        mmap: &Arc<MmapMut>,
        completion: File,
    ) -> Result<Scheduler> {
        let active_pes = Arc::new((Mutex::new(completion), Set::new()));

        let mut pe_hashed: HashMap<PEId, Vec<PE>> = HashMap::new();
        for (i, pe) in pes.iter().enumerate() {
            let the_pe = PE::new(
                i,
                pe.id as PEId,
                pe.offset,
                pe.size,
                pe.name.to_string(),
                mmap.clone(),
                active_pes.clone(),
            );
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
        ensure!(!pe.active(), PEStillActive { pe: pe });

        match self.pes.get_mut(&pe.type_id()) {
            Some(l) => l.push(pe),
            None => return Err(Error::NoSuchPE { id: *pe.type_id() }),
        }
        Ok(())
    }

    pub fn reset_interrupts(&mut self) -> Result<()> {
        for (_, v) in self.pes.iter_mut() {
            for pe in v.iter_mut() {
                pe.enable_interrupt().context(PEError)?;
                let iar_status = pe.interrupt_set().context(PEError)?;
                pe.reset_interrupt(iar_status).context(PEError)?;
            }
        }

        Ok(())
    }
}
