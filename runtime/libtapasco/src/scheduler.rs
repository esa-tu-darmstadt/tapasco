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

use crate::debug::UnsupportedDebugGenerator;
use crate::debug::{DebugGenerator, NonDebugGenerator};
use crate::device::OffchipMemory;
use crate::pe::PEId;
use crate::pe::PE;
use crossbeam::deque::{Injector, Steal};
use lockfree::map::Map;
use memmap::MmapMut;
use snafu::ResultExt;
use std::collections::HashMap;
use std::collections::VecDeque;
use std::fs::File;
use std::sync::Arc;
use std::thread;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("PE Type {} unavailable.", id))]
    PEUnavailable { id: PEId },

    #[snafu(display("PE Type {} is unknown.", id))]
    NoSuchPE { id: PEId },

    #[snafu(display(
        "PE with name {} is unknown. Possible values are {:?}.",
        name,
        possible
    ))]
    PENotFound { name: String, possible: Vec<String> },

    #[snafu(display("PE {} is still active. Can't release it.", pe.id()))]
    PEStillActive { pe: PE },

    #[snafu(display("PE Error: {}", source))]
    PEError { source: crate::pe::Error },

    #[snafu(display("Debug Error: {}", source))]
    DebugError { source: crate::debug::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;

/// Main method to retrieve a PE for execution
///
/// Uses an unblocking Injector primitive usually used for job stealing.
/// Retrieves PEs based on a first-come-first-serve basis.
#[derive(Debug)]
pub struct Scheduler {
    pes: Map<PEId, Injector<PE>>,
    pes_overview: HashMap<PEId, usize>,
    pes_name: HashMap<PEId, String>,
}

impl Scheduler {
    pub fn new(
        pes: &[crate::device::status::Pe],
        mmap: &Arc<MmapMut>,
        mut local_memories: VecDeque<Arc<OffchipMemory>>,
        completion: &File,
        debug_impls: &HashMap<String, Box<dyn DebugGenerator + Sync + Send>>,
        is_pcie: bool,
        svm_in_use: bool,
    ) -> Result<Self> {
        let pe_hashed: Map<PEId, Injector<PE>> = Map::new();
        let mut pes_overview: HashMap<PEId, usize> = HashMap::new();
        let mut pes_name: HashMap<PEId, String> = HashMap::new();

        let mut interrupt_id = if is_pcie { 4 } else { 0 };

        for (i, pe) in pes.iter().enumerate() {
            let debug = match &pe.debug {
                Some(x) => match debug_impls.get(&x.name) {
                    Some(y) => y
                        .new(mmap, x.name.clone(), x.offset, x.size)
                        .context(DebugError)?,
                    None => {
                        let d = UnsupportedDebugGenerator {};
                        d.new(mmap, x.name.clone(), 0, 0).context(DebugError)?
                    }
                },
                None => {
                    let d = NonDebugGenerator {};
                    d.new(mmap, "Unused".to_string(), 0, 0)
                        .context(DebugError)?
                }
            };

            if !pe.interrupts.is_empty() {
                interrupt_id = pe.interrupts[0].mapping as usize;
                trace!(
                    "Using status core mapped interrupt ID for PE {} -> {}.",
                    i,
                    interrupt_id
                );
            } else {
                trace!(
                    "Using legacy guessed interrupt ID for PE {} -> {}.",
                    i,
                    interrupt_id
                );
            }

            let mut the_pe = PE::new(
                i,
                pe.id as PEId,
                pe.offset,
                mmap.clone(),
                completion,
                interrupt_id,
                debug,
                svm_in_use,
            )
            .context(PEError)?;

            interrupt_id += 1;

            if pe.local_memory.is_some() {
                let l = local_memories.pop_front();
                the_pe.set_local_memory(l);
                interrupt_id += 1;
            }

            match pe_hashed.get(&(pe.id as PEId)) {
                Some(l) => l.val().push(the_pe),
                None => {
                    trace!("New PE type found: {} ({}).", pe.name, pe.id);
                    let v = Injector::new();
                    v.push(the_pe);
                    pe_hashed.insert(pe.id as PEId, v);
                    pes_name.insert(pe.id as PEId, pe.name.clone());
                }
            }

            match pes_overview.get_mut(&(pe.id as PEId)) {
                Some(l) => *l += 1,
                None => {
                    pes_overview.insert(pe.id as PEId, 1);
                }
            };
        }

        Ok(Self {
            pes: pe_hashed,
            pes_overview,
            pes_name,
        })
    }

    pub fn acquire_pe(&self, id: PEId) -> Result<PE> {
        match self.pes.get(&id) {
            Some(l) => loop {
                match l.val().steal() {
                    Steal::Success(pe) => return Ok(pe),
                    Steal::Empty => (),
                    Steal::Retry => (),
                }
                thread::yield_now();
            },
            None => Err(Error::NoSuchPE { id }),
        }
    }

    pub fn release_pe(&self, pe: PE) -> Result<()> {
        ensure!(!pe.active(), PEStillActive { pe });

        match self.pes.get(pe.type_id()) {
            Some(l) => l.val().push(pe),
            None => return Err(Error::NoSuchPE { id: *pe.type_id() }),
        }
        Ok(())
    }

    pub fn reset_interrupts(&self) -> Result<()> {
        for v in self.pes.iter() {
            let mut remove_pes = Vec::new();
            let mut maybe_pe = v.val().steal();

            while let Steal::Success(pe) = maybe_pe {
                pe.enable_interrupt().context(PEError)?;
                if pe.interrupt_set().context(PEError)? {
                    pe.reset_interrupt(true).context(PEError)?;
                }
                remove_pes.push(pe);
                maybe_pe = v.val().steal();
            }

            for pe in remove_pes {
                v.val().push(pe);
            }
        }

        Ok(())
    }

    pub fn num_pes(&self, id: PEId) -> usize {
        match self.pes_overview.get(&id) {
            Some(l) => *l,
            None => 0,
        }
    }

    pub fn get_pe_id(&self, name: &str) -> Result<PEId> {
        for (id, pe_name) in &self.pes_name {
            if name == pe_name {
                return Ok(*id);
            }
        }
        Err(Error::PENotFound {
            name: name.to_string(),
            possible: self.pes_name.values().cloned().collect(),
        })
    }
}
