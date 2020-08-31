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

use crate::device::DataTransferAlloc;
use crate::device::DataTransferPrealloc;
use crate::device::PEParameter;
use crate::pe::CopyBack;
use crate::pe::PE;
use crate::scheduler::Scheduler;
use snafu::ResultExt;
use std::sync::Arc;

impl<T> From<std::sync::PoisonError<T>> for Error {
    fn from(_error: std::sync::PoisonError<T>) -> Self {
        Error::MutexError {}
    }
}

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Allocator Error: {}", source))]
    AllocatorError { source: crate::allocator::Error },

    #[snafu(display("DMA Error: {}", source))]
    DMAError { source: crate::dma::Error },

    #[snafu(display("Mutex has been poisoned"))]
    MutexError {},

    #[snafu(display("PE Error: {}", source))]
    PEError { source: crate::pe::Error },

    #[snafu(display(
        "Unsupported parameter during register write stage. Unconverted data transfer alloc?: {:?}",
        arg
    ))]
    UnsupportedRegisterParameter { arg: PEParameter },

    #[snafu(display(
        "Unsupported parameter during during transfer to. Unconverted data transfer alloc?: {:?}",
        arg
    ))]
    UnsupportedTransferParameter { arg: PEParameter },

    #[snafu(display("Scheduler Error: {}", source))]
    SchedulerError { source: crate::scheduler::Error },

    #[snafu(display("Local memory requested on PE without local memory"))]
    NoLocalMemory {},

    #[snafu(display("This Job does not contain a PE which could be released."))]
    NoPEtoRelease {},
}

type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug)]
pub struct Job {
    pe: Option<PE>,
    scheduler: Arc<Scheduler>,
}

impl Drop for Job {
    fn drop(&mut self) {
        match self.release(true, false) {
            Ok(_) => (),
            Err(e) => panic!("{}", e),
        }
    }
}

impl Job {
    pub fn new(pe: PE, scheduler: &Arc<Scheduler>) -> Job {
        Job {
            pe: Some(pe),
            scheduler: scheduler.clone(),
        }
    }

    pub fn handle_local_memories(&self, args: Vec<PEParameter>) -> Result<Vec<PEParameter>> {
        trace!("Handling local memory parameters.");
        let new_params = args
            .into_iter()
            .map(|arg| match arg {
                PEParameter::DataTransferLocal(x) => {
                    let m = match self.pe.as_ref().unwrap().local_memory() {
                        Some(m) => m,
                        None => return Err(Error::NoLocalMemory {}),
                    };
                    Ok(PEParameter::DataTransferAlloc(DataTransferAlloc {
                        data: x.data,
                        from_device: x.from_device,
                        to_device: x.to_device,
                        memory: m.clone(),
                        free: x.free,
                        fixed: x.fixed,
                    }))
                }
                _ => Ok(arg),
            })
            .collect();
        trace!("All local memory parameters handled.");
        new_params
    }

    //TODO: Check performance as this does not happen inplace but creates a new Vec
    pub fn handle_allocates(&self, args: Vec<PEParameter>) -> Result<Vec<PEParameter>> {
        trace!("Handling allocate parameters.");
        let new_params = args
            .into_iter()
            .map(|arg| match arg {
                PEParameter::DataTransferAlloc(x) => {
                    let a = match x.fixed {
                        Some(offset) => x
                            .memory
                            .allocator()
                            .lock()?
                            .allocate_fixed(x.data.len() as u64, offset)
                            .context(AllocatorError)?,
                        None => x
                            .memory
                            .allocator()
                            .lock()?
                            .allocate(x.data.len() as u64)
                            .context(AllocatorError)?,
                    };

                    Ok(PEParameter::DataTransferPrealloc(DataTransferPrealloc {
                        data: x.data,
                        device_address: a,
                        from_device: x.from_device,
                        to_device: x.to_device,
                        memory: x.memory,
                        free: x.free,
                    }))
                }
                _ => Ok(arg),
            })
            .collect();

        trace!("All allocate parameters handled.");
        new_params
    }

    pub fn handle_transfers_to_device(
        &mut self,
        args: Vec<PEParameter>,
    ) -> Result<(Vec<PEParameter>, Vec<Box<[u8]>>)> {
        trace!("Handling allocate parameters.");
        let mut unused_mem = Vec::new();
        let new_params = args
            .into_iter()
            .try_fold(Vec::new(), |mut xs, arg| match arg {
                PEParameter::DataTransferPrealloc(x) => {
                    if x.to_device {
                        x.memory
                            .dma()
                            .copy_to(&x.data[..], x.device_address)
                            .context(DMAError)?;
                    }

                    xs.push(PEParameter::DeviceAddress(x.device_address));
                    if x.from_device {
                        self.pe
                            .as_mut()
                            .unwrap()
                            .add_copyback(CopyBack::Transfer(x));
                    } else {
                        if x.free {
                            self.pe
                                .as_mut()
                                .unwrap()
                                .add_copyback(CopyBack::Free(x.device_address, x.memory.clone()));
                        }
                        unused_mem.push(x.data);
                    }

                    Ok(xs)
                }
                _ => {
                    xs.push(arg);
                    Ok(xs)
                }
            });
        trace!("All transfer to parameters handled.");
        match new_params {
            Ok(x) => Ok((x, unused_mem)),
            Err(e) => Err(e),
        }
    }

    pub fn start(&mut self, args: Vec<PEParameter>) -> Result<Vec<Box<[u8]>>> {
        trace!(
            "Starting execution of {:?} with Arguments {:?}.",
            self.pe,
            args
        );
        let alloc_args = self.handle_local_memories(args)?;
        let local_args = self.handle_allocates(alloc_args)?;
        trace!("Handled allocates => {:?}.", local_args);
        let (trans_args, unused_mem) = self.handle_transfers_to_device(local_args)?;
        trace!("Handled transfers => {:?}.", trans_args);
        trace!("Setting arguments.");
        for (i, arg) in trans_args.into_iter().enumerate() {
            trace!("Setting argument {} => {:?}.", i, arg);
            match arg {
                PEParameter::Single32(_) => {
                    self.pe.as_ref().unwrap().set_arg(i, arg).context(PEError)?
                }
                PEParameter::Single64(_) => {
                    self.pe.as_ref().unwrap().set_arg(i, arg).context(PEError)?
                }
                PEParameter::DeviceAddress(x) => self
                    .pe
                    .as_ref()
                    .unwrap()
                    .set_arg(i, PEParameter::Single64(x))
                    .context(PEError)?,
                _ => return Err(Error::UnsupportedRegisterParameter { arg: arg }),
            };
        }
        trace!("Arguments set.");
        trace!("Starting PE {} execution.", self.pe.as_ref().unwrap().id());
        self.pe.as_mut().unwrap().start().context(PEError)?;
        trace!("PE {} started.", self.pe.as_ref().unwrap().id());
        Ok(unused_mem)
    }

    pub fn release(
        &mut self,
        release_pe: bool,
        return_value: bool,
    ) -> Result<(u64, Vec<Box<[u8]>>)> {
        if self.pe.is_some() {
            trace!("Trying to release PE {:?}.", self.pe.as_ref().unwrap().id());
            let (return_value, copyback) = self
                .pe
                .as_mut()
                .unwrap()
                .release(return_value)
                .context(PEError)?;
            trace!("PE is idle.");

            if release_pe {
                self.scheduler
                    .release_pe(self.pe.take().unwrap())
                    .context(SchedulerError)?;
            }
            trace!("Release successful.");
            match copyback {
                Some(copybacks) => {
                    let mut res = Vec::new();

                    for param in copybacks {
                        match param {
                            CopyBack::Transfer(mut transfer) => {
                                transfer
                                    .memory
                                    .dma()
                                    .copy_from(transfer.device_address, &mut transfer.data[..])
                                    .context(DMAError)?;
                                if transfer.free {
                                    transfer
                                        .memory
                                        .allocator()
                                        .lock()?
                                        .free(transfer.device_address)
                                        .context(AllocatorError)?;
                                }
                                res.push(transfer.data);
                            }
                            CopyBack::Free(addr, mem) => {
                                mem.allocator().lock()?.free(addr).context(AllocatorError)?;
                            }
                        }
                    }

                    Ok((return_value, res))
                }
                None => Ok((return_value, Vec::new())),
            }
        } else {
            Err(Error::NoPEtoRelease {})
        }
    }
}
