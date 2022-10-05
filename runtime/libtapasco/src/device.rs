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

use std::borrow::Borrow;
use crate::allocator::{Allocator, DriverAllocator, DummyAllocator, GenericAllocator, VfioAllocator};
use crate::debug::{DebugGenerator, NonDebugGenerator};
use crate::dma::{DMAControl, DirectDMA, DriverDMA, VfioDMA, SVMDMA, SimDMA};
use crate::dma_user_space::UserSpaceDMA;
use crate::job::Job;
use crate::pe::PEId;
use crate::pe::PE;
use crate::scheduler::Scheduler;
use crate::tlkm::{tlkm_access, tlkm_ioctl_svm_launch, tlkm_svm_init_cmd};
use crate::tlkm::tlkm_ioctl_create;
use crate::tlkm::tlkm_ioctl_destroy;
use crate::tlkm::tlkm_ioctl_device_cmd;
use crate::tlkm::DeviceId;
use crate::vfio::*;
use config::Config;
use memmap::MmapOptions;
use snafu::ResultExt;
use std::collections::HashMap;
use std::collections::VecDeque;
use std::fs::File;
use std::fs::OpenOptions;
use std::os::unix::io::AsRawFd;
use std::sync::Arc;
use std::sync::Mutex;
use crate::mmap_mut::MemoryType;
use crate::sim_client::SimClient;
use crate::protos::status;


#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Device {} unavailable: {}", id, source))]
    DeviceUnavailable {
        source: std::io::Error,
        id: DeviceId,
    },

    #[snafu(display("Memory area {} not found in bitstream.", area))]
    AreaMissing { area: String },

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

    #[snafu(display("PE acquisition requires Exclusive Access mode."))]
    ExclusiveRequired {},

    #[snafu(display("Could not find any DMA engines."))]
    DMAEngineMissing {},

    #[snafu(display("Could not destroy device {}: {}", id, source))]
    IOCTLDestroy { source: nix::Error, id: DeviceId },

    #[snafu(display("Scheduler Error: {}", source))]
    SchedulerError { source: crate::scheduler::Error },

    #[snafu(display("DMA Error: {}", source))]
    DMAError { source: crate::dma::Error },

    #[snafu(display("Allocator Error: {}", source))]
    AllocatorError { source: crate::allocator::Error },

    #[snafu(display("Mutex has been poisoned"))]
    MutexError {},

    #[snafu(display("Unknown device type {}.", name))]
    DeviceType { name: String },

    #[snafu(display("Could not parse configuration {}", source))]
    ConfigError { source: config::ConfigError },

    #[snafu(display("Could not initialize VFIO subsystem: {}", source))]
    VfioInitError { source: crate::vfio::Error },

    #[snafu(display("Could not launch SVM support in the TLKM"))]
    SVMInitError { source: nix::Error },

    #[snafu(display("Could not find component {}.", name))]
    ComponentNotFound { name: String },

    #[snafu(display(
        "Component {} has no associated interrupt. Cannot be used as PE.",
        name
    ))]
    MissingInterrupt { name: String },

    #[snafu(display("PE Error: {}", source))]
    PEError { source: crate::pe::Error },

    #[snafu(display("Debug Error: {}", source))]
    DebugError { source: crate::debug::Error },

    #[snafu(display("{}", source))]
    SimClientError { source: crate::sim_client::Error },

    #[snafu(display("Violation of memory access type"))]
    MemoryAccessType {},
}

type Result<T, E = Error> = std::result::Result<T, E>;

impl<T> From<std::sync::PoisonError<T>> for Error {
    fn from(_error: std::sync::PoisonError<T>) -> Self {
        Self::MutexError {}
    }
}

/// Generic type for an address on the device.
pub type DeviceAddress = u64;
/// Generic type to specify the size of a memory segment on the device.
pub type DeviceSize = u64;

/// Structure to describe memory on the device.
///
/// Access to the memory is provided through the allocator to manage memory allocations
/// and the DMA which can be used to transfer data to and from the memory.
#[derive(Debug, Getters)]
pub struct OffchipMemory {
    #[get = "pub"]
    allocator: Mutex<Box<dyn Allocator + Sync + Send>>,
    #[get = "pub"]
    dma: Box<dyn DMAControl + Sync + Send>,
}

// Types to describe PE parameters.

/// Describes a transfer to local memory. The specific memory to use is determined after
/// the PE has been selected.
#[derive(Debug)]
pub struct DataTransferLocal {
    /// Slice that points to the memory used for this transfer.
    pub data: Box<[u8]>,
    /// Should the buffer be transferred back after job execution?
    pub from_device: bool,
    /// Should the buffer be transferred to the device before job execution?
    pub to_device: bool,
    /// Should the buffer on the device be released after job execution?
    pub free: bool,
    /// Does the allocation on the device have to be on a certain offset?
    pub fixed: Option<DeviceAddress>,
}

/// Data transfer parameter which requires allocation on the device.
#[derive(Debug)]
pub struct DataTransferAlloc {
    /// Slice that points to the memory used for this transfer.
    pub data: Box<[u8]>,
    /// Should the buffer be transferred back after job execution?
    pub from_device: bool,
    /// Should the buffer be transferred to the device before job execution?
    pub to_device: bool,
    /// Should the buffer on the device be released after job execution?
    pub free: bool,
    /// Which memory to target?
    pub memory: Arc<OffchipMemory>,
    /// Does the allocation on the device have to be on a certain offset?
    pub fixed: Option<DeviceAddress>,
}

/// Data transfer parameter with preallocated memory on the device.
#[derive(Debug)]
pub struct DataTransferPrealloc {
    /// Slice that points to the memory used for this transfer.
    pub data: Box<[u8]>,
    /// Allocation on the device to use.
    pub device_address: DeviceAddress,
    /// Should the buffer be transferred back after job execution?
    pub from_device: bool,
    /// Should the buffer be transferred to the device before job execution?
    pub to_device: bool,
    /// Should the buffer on the device be released after job execution?
    pub free: bool,
    /// Which memory to target?
    pub memory: Arc<OffchipMemory>,
}

/// All parameters supported by a TaPaSCo PE.
#[derive(Debug)]
pub enum PEParameter {
    /// Single 32 bit parameter.
    Single32(u32),
    /// Single 64 bit parameter.
    Single64(u64),
    /// Single address transferred as a 64 bit parameter.
    DeviceAddress(DeviceAddress),
    /// Transfer using local memory.
    DataTransferLocal(DataTransferLocal),
    /// Transfer using any memory.
    DataTransferAlloc(DataTransferAlloc),
    /// Transfer using any memory with preallocated space.
    DataTransferPrealloc(DataTransferPrealloc),
    /// Virtual address parameter used for SVM.
    VirtualAddress(*const u8),
}

// End of PE parameters.

/// Description of a TaPaSCo device. Contains all relevant information and the operations
/// to interact with the device.
///
/// Generated by [`TLKM.device_alloc`].
///
/// [`TLKM.device_alloc`]: ../tlkm/struct.TLKM.html#method.device_alloc
#[derive(Debug, Getters)]
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
    scheduler: Arc<Scheduler>,
    platform: Arc<MemoryType>,
    offchip_memory: Vec<Arc<OffchipMemory>>,
    tlkm_file: Arc<File>,
    tlkm_device_file: Arc<File>,
}

impl Device {
    /// Set up all the components of a TaPaSCo device such as the PE scheduler,
    /// the memory allocators, the DMA engines etc.
    ///
    /// This function is typically not called directly but the Device is
    /// automatically generated by [`TLKM.device_alloc`].
    ///
    /// [`TLKM.device_alloc`]: ../tlkm/struct.TLKM.html#method.device_alloc
    pub fn new(
        tlkm_file: Arc<File>,
        id: DeviceId,
        vendor: u32,
        product: u32,
        name: String,
        settings: Arc<Config>,
        _: &HashMap<String, Box<dyn DebugGenerator + Sync + Send>>,
    ) -> Result<Self> {
        trace!("Open driver device file.");

        let tlkm_dma_file = Arc::new(
            OpenOptions::new()
                .read(true)
                .write(true)
                .open(format!(
                    "{}{:02}",
                    settings
                        .get_string("tlkm.device_driver_file")
                        .context(ConfigSnafu)?,
                    id
                ))
                .context(DeviceUnavailableSnafu { id })?,
        );

        let client: Arc<SimClient>;
        
        trace!("Mapping status core.");
        let s = {
            if name == "sim" {
                let client = Arc::new(SimClient::new().context(SimClientSnafu)?);
                client.get_status().context(SimClientSnafu)?
            } else {
                let mmap = unsafe {
                    MmapOptions::new()
                        .len(8192)
                        .offset(0)
                        .map(&tlkm_dma_file)
                        .context(DeviceUnavailableSnafu { id })?
                };
                println!("Mapped status core: {}", mmap[0]);
            
                // copy the status core byte by byte from the device to avoid
                // alignment errors that occur on certain devices e.g. ZynqMP.
                // In a perfect world this loop can be replaced by e.g.
                // mmap_cpy.clone_from_slice(&mmap[..]);
                let mut mmap_cpy = [0; 8192];
                for i in 0..8192 {
                    mmap_cpy[i] = mmap[i];
                }
            
                status::Status::decode_length_delimited(&mmap_cpy[..]).context(StatusCoreDecodingSnafu)?
            }
        };

        trace!("Status core decoded: {:?}", s);

        trace!("Mapping the platform and architecture memory regions.");

        let platform_size = match &s.platform_base {
            Some(base) => Ok(base.size),
            None => Err(Error::AreaMissing {
                area: "Platform".to_string(),
            }),
        }?;

        let platform_mmap = Arc::new(unsafe {
            MmapOptions::new()
                .len(platform_size as usize)
                .offset(0)
                .map_mut(&tlkm_dma_file)
                .context(DeviceUnavailableSnafu { id })?
        });

        let mut platform = MemoryType::Mmap(platform_mmap.clone());

        let arch_size = match &s.arch_base {
            Some(base) => Ok(base.size),
            None => Err(Error::AreaMissing {
                area: "Platform".to_string(),
            }),
        }?;

        let arch_mmap = Arc::new(unsafe {
            MmapOptions::new()
                .len(arch_size as usize)
                .offset(0) //todo correct offset
                .map_mut(&tlkm_dma_file)
                .context(DeviceUnavailableSnafu { id })?
        });

        let mut arch = MemoryType::Mmap(arch_mmap.clone());

        // Initialize the global memories.
        // Currently falls back to PCIe and Zynq allocation using the default 4GB at 0x0.
        // This will be replaced with proper dynamic initialization after the status core
        // has been updated to contain the required information.
        info!("Using static memory allocation due to lack of dynamic data in the status core.");
        let mut allocator = Vec::new();
        let zynqmp_vfio_mode = true;
        let mut is_pcie = false;
        let mut svm_in_use = false;
        if name == "pcie" {

            // check whether SVM is in use
            for comp in &s.platform {
                if comp.name == "PLATFORM_COMPONENT_MMU" {
                    svm_in_use = true;
                }
            }

            if !svm_in_use {
                info!("Allocating the default of 4GB at 0x0 for a PCIe platform");
                let mut dma_offset = 0;
                let mut dma_interrupt_read = 0;
                let mut dma_interrupt_write = 1;
                for comp in &s.platform {
                    if comp.name == "PLATFORM_COMPONENT_DMA0" {
                        dma_offset = comp.offset;
                        for v in &comp.interrupts {
                            if v.name == "READ" {
                                dma_interrupt_read = v.mapping as usize;
                            } else if v.name == "WRITE" {
                                dma_interrupt_write = v.mapping as usize;
                            } else {
                                println!("Unknown DMA interrupt: {}.", v.name);
                            }
                        }
                    }
                }
                if dma_offset == 0 {
                    println!("Could not find DMA engine.");
                    return Err(Error::DMAEngineMissing {});
                }

                is_pcie = true;

                allocator.push(Arc::new(OffchipMemory {
                    allocator: Mutex::new(Box::new(
                        GenericAllocator::new(0, 4 * 1024 * 1024 * 1024, 64).context(AllocatorSnafu)?,
                    )),
                    dma: Box::new(
                        UserSpaceDMA::new(
                            &tlkm_dma_file,
                            dma_offset as usize,
                            dma_interrupt_read,
                            dma_interrupt_write,
                            &platform_mmap,
                            settings
                                .get::<usize>("dma.read_buffer_size")
                                .context(ConfigSnafu)?,
                            settings
                                .get::<usize>("dma.read_buffers")
                                .context(ConfigSnafu)?,
                            settings
                                .get::<usize>("dma.write_buffer_size")
                                .context(ConfigSnafu)?,
                            settings
                                .get::<usize>("dma.write_buffers")
                                .context(ConfigSnafu)?,
                        )
                            .context(DMASnafu)?,
                    ),
                }));
            } else {
                println!("Using SVM...");
                let mut init_cmd = tlkm_svm_init_cmd {
                    result: 0,
                };
                unsafe {
                    tlkm_ioctl_svm_launch(
                        tlkm_dma_file.as_raw_fd(),
                        &mut init_cmd,
                    ).context(SVMInitSnafu)?;
                }
                allocator.push(Arc::new(OffchipMemory {
                    allocator: Mutex::new(Box::new(DummyAllocator::new())),
                    dma: Box::new(SVMDMA::new(&tlkm_dma_file)),
                }));
            }
        } else if name == "zynq" || (name == "zynqmp" && !zynqmp_vfio_mode) {
            info!("Using driver allocation for Zynq/ZynqMP based platform.");
            allocator.push(Arc::new(OffchipMemory {
                allocator: Mutex::new(Box::new(
                    DriverAllocator::new(&tlkm_dma_file).context(AllocatorSnafu)?,
                )),
                dma: Box::new(DriverDMA::new(&tlkm_dma_file)),
            }));
        } else if name == "zynqmp" {
            info!("Using VFIO mode for ZynqMP based platform.");
            let vfio_dev = Arc::new(init_vfio(settings)
                .context(VfioInitSnafu)?
            );
            allocator.push(Arc::new(OffchipMemory {
                allocator: Mutex::new(Box::new(
                    VfioAllocator::new(&vfio_dev).context(AllocatorSnafu)?,
                )),
                dma: Box::new(VfioDMA::new(&vfio_dev)),
            }));
        } else if name == "sim" {
            info!("SIM DEVICE FOUND!");
            allocator.push(Arc::new(OffchipMemory{
                allocator: Mutex::new(Box::new(
                    GenericAllocator::new(0, 2_u64.pow(30), 1).context(AllocatorSnafu)?,
                )),
                dma: Box::new(SimDMA::new(0, 2_u64.pow(30), false).context(DMASnafu)?),
            }));
            platform = MemoryType::Sim(client.clone());
            arch = MemoryType::Sim(client.clone());
        } else {
            return Err(Error::DeviceType { name });
        }

        let mut pe_local_memories = VecDeque::new();
        if !svm_in_use {
            trace!("Initialize PE local memories.");
            for pe in &s.pe {
                match &pe.local_memory {
                    Some(l) => {
                        pe_local_memories.push_back(Arc::new(OffchipMemory {
                            allocator: Mutex::new(Box::new(
                                GenericAllocator::new(0, l.size, 1).context(AllocatorSnafu)?,
                            )),
                            dma: if name == "sim" { Box::new(SimDMA::new(l.base, l.size, true).context(DMASnafu)?) } else { Box::new(DirectDMA::new(l.base, l.size, arch_mmap.clone())) },
                        }));
                    },
                    None => (),
                }
            }
        } else {
            warn!("PE local memories not compatible with SVM currently");
        }

        trace!("Initialize PE scheduler.");
        let scheduler = Arc::new(
            Scheduler::new(
                &s.pe,
                Arc::new(arch),
                pe_local_memories,
                &tlkm_dma_file,
                // debug_impls,
                is_pcie,
                svm_in_use,
            )
                .context(SchedulerSnafu)?,
        );

        trace!("Device creation completed.");
        let mut device = Self {
            id,
            vendor,
            product,
            access: tlkm_access::TlkmAccessTypes,
            name,
            status: s,
            scheduler,
            platform: Arc::new(platform),
            offchip_memory: allocator,
            tlkm_file,
            tlkm_device_file: tlkm_dma_file,
        };

        device.change_access(tlkm_access::TlkmAccessMonitor)?;

        Ok(device)
    }

    /// Request a PE from the device.
    ///
    /// # Arguments
    ///   * id: The ID of the desired PE.
    ///
    /// Returns a [`Job`] with the given PE that can be used to start execution on the scheduled PE.
    ///
    /// [`Job`]: ../job/struct.Job.html
    pub fn acquire_pe(&self, id: PEId) -> Result<Job> {
        self.check_exclusive_access()?;
        trace!("Trying to acquire PE of type {}.", id);
        let pe = self.scheduler.acquire_pe(id).context(SchedulerSnafu)?;
        trace!("Successfully acquired PE of type {}.", id);
        Ok(Job::new(pe, &self.scheduler))
    }

    /// Request a PE from the device but don't create a Job for it. Usually [`acquire_pe`] is used
    /// if you don't want to do things manually.
    ///
    /// # Arguments
    ///   * id: The ID of the desired PE.
    ///
    pub fn acquire_pe_without_job(&self, id: PEId) -> Result<PE> {
        trace!(
            "Trying to acquire PE of type {} without exclusive access.",
            id
        );
        let pe = self.scheduler.acquire_pe(id).context(SchedulerSnafu)?;
        trace!(
            "Successfully acquired PE of type {} without exclusive access.",
            id
        );
        Ok(pe)
    }

    fn check_exclusive_access(&self) -> Result<()> {
        if self.access == tlkm_access::TlkmAccessExclusive {
            Ok(())
        } else {
            Err(Error::ExclusiveRequired {})
        }
    }

    /// Changes the device access permissions in the driver.
    ///
    /// Without exclusive access PEs can not be scheduled etc.
    pub fn change_access(&mut self, access: tlkm_access) -> Result<()> {
        if self.access == access {
            trace!(
                "Device {} is already in access mode {:?}.",
                self.id,
                self.access
            );
            return Ok(());
        }

        self.destroy()?;

        let mut request = tlkm_ioctl_device_cmd {
            dev_id: self.id,
            access,
        };

        trace!("Device {}: Trying to change mode to {:?}", self.id, access,);

        unsafe {
            tlkm_ioctl_create(self.tlkm_file.as_raw_fd(), &mut request).context(IOCTLCreateSnafu {
                access,
                id: self.id,
            })?;
        };

        self.access = access;

        if access == tlkm_access::TlkmAccessExclusive {
            trace!("Access changed to exclusive, resetting all interrupts.");
            self.scheduler.reset_interrupts().context(SchedulerSnafu)?;
        }

        trace!("Successfully acquired access.");
        Ok(())
    }

    /// Remove access mode in the driver. Is used before setting a new mode.
    fn destroy(&mut self) -> Result<()> {
        if self.access != tlkm_access::TlkmAccessTypes {
            trace!("Device {}: Removing access mode {:?}", self.id, self.access,);
            let mut request = tlkm_ioctl_device_cmd {
                dev_id: self.id,
                access: self.access,
            };
            unsafe {
                tlkm_ioctl_destroy(self.tlkm_file.as_raw_fd(), &mut request)
                    .context(IOCTLDestroySnafu { id: self.id })?;
            }
            self.access = tlkm_access::TlkmAccessTypes;
        }

        Ok(())
    }

    /// Return frequency in MHz used by the design as indicated by the status core.
    pub fn design_frequency_mhz(&self) -> Result<f32> {
        let freq = self
            .status
            .clocks
            .iter()
            .find(|&x| x.name == "Design")
            .unwrap_or(&status::Clock {
                name: "".to_string(),
                frequency_mhz: 0,
            })
            .frequency_mhz;
        Ok(freq as f32)
    }

    /// Return frequency in MHz used by the memory as indicated by the status core.
    pub fn memory_frequency_mhz(&self) -> Result<f32> {
        let freq = self
            .status
            .clocks
            .iter()
            .find(|&x| x.name == "Memory")
            .unwrap_or(&status::Clock {
                name: "".to_string(),
                frequency_mhz: 0,
            })
            .frequency_mhz;
        Ok(freq as f32)
    }

    /// Return frequency in MHz used by the host as indicated by the status core.
    pub fn host_frequency_mhz(&self) -> Result<f32> {
        let freq = self
            .status
            .clocks
            .iter()
            .find(|&x| x.name == "Host")
            .unwrap_or(&status::Clock {
                name: "".to_string(),
                frequency_mhz: 0,
            })
            .frequency_mhz;
        Ok(freq as f32)
    }

    /// Return the main memory as indicated by the status core.
    /// Might be used to preallocate memory and transfer data independent of
    /// a job.
    pub fn default_memory(&self) -> Result<Arc<OffchipMemory>> {
        Ok(self.offchip_memory[0].clone())
    }

    /// Return the number of PEs of a given ID in the bitstream.
    pub fn num_pes(&self, pe: PEId) -> usize {
        self.scheduler.num_pes(pe)
    }

    /// Return the PEId of the PE with the given name
    pub fn get_pe_id(&self, name: &str) -> Result<PEId> {
        self.scheduler.get_pe_id(name).context(SchedulerSnafu)
    }

    /// Get a list of platform components names available on this device
    pub fn get_available_platform_components(&self) -> Vec<String> {
        let mut platform_components = Vec::new();

        for p in &self.status.platform {
            trace!("Found platform component {}.", p.name);
            platform_components.push(p.name.clone());
        }

        platform_components
    }

    /// Get memory of a platform component
    ///
    /// # Safety
    ///
    /// Treated unsafe as a user can change anything about the memory without any checks
    /// and might try using the memory after the device has been released.
    pub unsafe fn get_platform_component_memory(&self, name: &str) -> Result<&mut [u8]> {
        match self.platform.borrow() {
            MemoryType::Mmap(platform) => {
                for p in &self.status.platform {
                    if p.name == name {
                        trace!(
                        "Found platform component {} at {:X} (Size {}).",
                        p.name,
                        p.offset,
                        p.size
                    );

                        let ptr = platform.as_ptr().offset(p.offset as isize) as *mut u8;
                        let s = std::slice::from_raw_parts_mut(ptr, p.size as usize);
                        return Ok(s);
                    }
                }
                Err(Error::ComponentNotFound {
                        name: name.to_string(),
                })
            },
            _ => Err(Error::MemoryAccessType {})
        }
    }

    /// Returns a PE interface to the platform component
    /// Can be used like any other PE but is not integrated
    /// into the scheduling and job mechanisms
    pub fn get_platform_component_as_pe(&self, name: &str) -> Result<PE> {
        for p in &self.status.platform {
            if p.name == name {
                trace!(
                    "Found platform component {} at {:X} (Size {}).",
                    p.name,
                    p.offset,
                    p.size
                );

                // let d = NonDebugGenerator {};
                // let debug = d
                //     .new(&self.platform, "Unused".to_string(), 0, 0)
                //     .context(DebugSnafu)?;

                if !p.interrupts.is_empty() {
                    return PE::new(
                        // TODO: Should the ID of this PE really be 42? If it's necessarily a magic
                        // value, why not just 0?
                        42,
                        42,
                        p.offset,
                        self.platform.clone(),
                        &self.tlkm_device_file,
                        p.interrupts[0].mapping as usize,
                        // debug,
                        false,  // TODO: Is this correct?
                    )
                    .context(PESnafu);
                } else {
                    return Err(Error::MissingInterrupt {
                        name: name.to_string(),
                    });
                }
            }
        }
        Err(Error::ComponentNotFound {
            name: name.to_string(),
        })
    }
}
