use crate::allocator::{Allocator, DriverAllocator, GenericAllocator};
use crate::dma::{DMAControl, DriverDMA};
use crate::scheduler::{PEId, Scheduler, PE};
use crate::tlkm::tlkm_access;
use crate::tlkm::tlkm_ioctl_create;
use crate::tlkm::tlkm_ioctl_destroy;
use crate::tlkm::tlkm_ioctl_device_cmd;
use crate::tlkm::DeviceId;
use bytes::Buf;
use memmap::MmapMut;
use memmap::MmapOptions;
use prost::Message;
use snafu::ResultExt;
use std::collections::HashMap;
use std::fs::File;
use std::fs::OpenOptions;
use std::io::Cursor;
use std::io::Read;
use std::os::unix::io::AsRawFd;
use uom::si::f32::*;
use uom::si::frequency::megahertz;

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

    #[snafu(display("Memory {} not found on device.", id))]
    UnknownMemory { id: MemoryID },

    #[snafu(display("Could not destroy device {}: {}", id, source))]
    IOCTLDestroy { source: nix::Error, id: DeviceId },

    #[snafu(display("Scheduler Error: {}", source))]
    SchedulerError { source: crate::scheduler::Error },

    #[snafu(display("Allocator Error: {}", source))]
    AllocatorError { source: crate::allocator::Error },

    #[snafu(display("DMA Error: {}", source))]
    DMAError { source: crate::dma::Error },

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
}
type Result<T, E = Error> = std::result::Result<T, E>;

pub type DeviceAddress = u64;
pub type DeviceSize = u64;

pub type MemoryID = usize;

#[derive(Debug, Getters)]
pub struct OffchipMemory {
    id: MemoryID,
    allocator: Box<dyn Allocator>,
    dma: Box<dyn DMAControl>,
}

#[derive(Debug, PartialEq)]
pub struct DataTransferAlloc {
    pub data: Vec<u8>,
    pub from_device: bool,
    pub to_device: bool,
    pub memory: MemoryID,
}

#[derive(Debug, PartialEq)]
pub struct DataTransferPrealloc {
    pub data: Vec<u8>,
    pub device_address: DeviceAddress,
    pub from_device: bool,
    pub to_device: bool,
    pub memory: MemoryID,
}

#[derive(Debug, PartialEq)]
pub enum PEParameter {
    Single32(u32),
    Single64(u64),
    DeviceAddress(DeviceAddress),
    DataTransferAlloc(DataTransferAlloc),
    DataTransferPrealloc(DataTransferPrealloc),
}

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
    scheduler: Scheduler,
    platform: MmapMut,
    arch: MmapMut,
    completion: File,
    active_pes: HashMap<usize, bool>,
    offchip_memory: Vec<OffchipMemory>,
}

impl Drop for Device {
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
        trace!("Mapping status core.");
        let s = {
            let mmap = unsafe {
                MmapOptions::new()
                    .len(8192)
                    .offset(0)
                    .map(
                        &OpenOptions::new()
                            .read(true)
                            .open(format!("/dev/tlkm_{:02}", id))
                            .context(DeviceUnavailable { id: id })?,
                    )
                    .context(DeviceUnavailable { id: id })?
            };
            trace!("Mapped status core: {}", mmap[0]);

            // copy from device to avoid alignment errors that occur on certain devices
            // e.g. ZynqMP
            let mut mmap_cpy = [0; 8192];
            mmap_cpy.copy_from_slice(&mmap[..]);

            status::Status::decode_length_delimited(&mmap_cpy[..]).context(StatusCoreDecoding)?
        };

        trace!("Status core decoded: {:?}", s);

        let platform_size = match &s.platform_base {
            Some(base) => Ok(base.size),
            None => Err(Error::AreaMissing {
                area: "Platform".to_string(),
            }),
        }?;

        // This falls back to PCIe and Zynq allocation using the default 4GB at 0x0
        info!("Using static memory allocation due to lack of dynamic data in the status core.");
        let mut allocator = Vec::new();
        if name == "pcie" {
            info!("Allocating the default of 4GB at 0x0 for a PCIe platform");
            allocator.push(OffchipMemory {
                id: 0,
                allocator: Box::new(
                    GenericAllocator::new(0, 4 * 1024 * 1024 * 1024, 64).context(AllocatorError)?,
                ),
                dma: Box::new(DriverDMA {}),
            });
        } else if name == "zynq" {
            info!("Using driver allocation for zynq based platform.");
            allocator.push(OffchipMemory {
                id: 0,
                allocator: Box::new(DriverAllocator::new().context(AllocatorError)?),
                dma: Box::new(DriverDMA {}),
            });
        }

        let platform = unsafe {
            MmapOptions::new()
                .len(platform_size as usize)
                .offset(8192)
                .map_mut(
                    &OpenOptions::new()
                        .read(true)
                        .write(true)
                        .open(format!("/dev/tlkm_{:02}", id))
                        .context(DeviceUnavailable { id: id })?,
                )
                .context(DeviceUnavailable { id: id })?
        };

        let arch_size = match &s.arch_base {
            Some(base) => Ok(base.size),
            None => Err(Error::AreaMissing {
                area: "Platform".to_string(),
            }),
        }?;

        let arch = unsafe {
            MmapOptions::new()
                .len(arch_size as usize)
                .offset(4096)
                .map_mut(
                    &OpenOptions::new()
                        .read(true)
                        .write(true)
                        .open(format!("/dev/tlkm_{:02}", id))
                        .context(DeviceUnavailable { id: id })?,
                )
                .context(DeviceUnavailable { id: id })?
        };

        let scheduler = Scheduler::new(&s.pe).context(SchedulerError)?;

        let mut device = Device {
            id: id,
            vendor: vendor,
            product: product,
            access: tlkm_access::TlkmAccessTypes,
            name: name,
            status: s,
            scheduler: scheduler,
            platform: platform,
            arch: arch,
            completion: OpenOptions::new()
                .read(true)
                .open(format!("/dev/tlkm_{:02}", id))
                .context(DeviceUnavailable { id: id })?,
            active_pes: HashMap::new(),
            offchip_memory: allocator,
        };

        device.create(&tlkm_file, tlkm_access::TlkmAccessMonitor)?;

        Ok(device)
    }

    fn finish(&mut self) -> Result<()> {
        Ok(())
    }

    fn wait_for_completion_loop(&mut self, pe_id: &usize) -> Result<()> {
        let mut active = true;
        while active {
            let mut buffer = [u8::max_value(); 128 * 4];
            self.completion
                .read(&mut buffer)
                .context(DeviceUnavailable { id: self.id })?;
            trace!("Fetched completion notices from driver.");
            let mut buf = Cursor::new(&buffer[..]);
            while buf.remaining() >= 4 {
                let id = buf.get_u32_le();
                if id != u32::max_value() {
                    if id as usize == *pe_id {
                        trace!("PE {} is finished.", id);
                        active = false;
                    } else {
                        match self.active_pes.get_mut(&(id as usize)) {
                            Some(pe_done) => *pe_done = true,
                            None => trace!("PE is not waiting right now."),
                        }
                    }
                }
            }
        }
        Ok(())
    }

    pub fn wait_for_completion(&mut self, pe: &mut PE) -> Result<()> {
        if *pe.active() {
            match self.active_pes.get(&pe.id()) {
                Some(pe_done) => {
                    if *pe_done {
                        trace!("PE {} has already indicated completion.", pe.id());
                    } else {
                        trace!("Waiting for completion of {:?}.", pe);
                        self.wait_for_completion_loop(&pe.id())?;
                        trace!("Waiting for PE completed.");
                    }
                    pe.set_active(false);
                    pe.reset_interrupt(&mut self.arch).context(SchedulerError)?;
                }
                None => trace!("PE is not waiting right now."),
            }
            self.active_pes.remove(pe.id());
        } else {
            trace!("Wait requested but {:?} is already idle.", pe);
        }
        Ok(())
    }

    //TODO: Check performance as this does not happen inplace but creates a new Vec
    pub fn handle_allocates(&mut self, args: Vec<PEParameter>) -> Result<Vec<PEParameter>> {
        trace!("Handling allocate parameters.");
        let new_params = args
            .into_iter()
            .map(|arg| match arg {
                PEParameter::DataTransferAlloc(x) => {
                    match self.offchip_memory.iter_mut().find(|y| y.id == x.memory) {
                        Some(mem) => {
                            let a = mem
                                .allocator
                                .allocate(x.data.len() as u64)
                                .context(AllocatorError)?;
                            Ok(PEParameter::DataTransferPrealloc(DataTransferPrealloc {
                                data: x.data,
                                device_address: a,
                                from_device: x.from_device,
                                to_device: x.to_device,
                                memory: x.memory,
                            }))
                        }
                        None => Err(Error::UnknownMemory { id: x.memory }),
                    }
                }
                _ => Ok(arg),
            })
            .collect();
        trace!("All allocate parameters handled.");
        new_params
    }

    pub fn handle_transfers_to_device(
        &mut self,
        pe: &mut PE,
        args: Vec<PEParameter>,
    ) -> Result<Vec<PEParameter>> {
        trace!("Handling allocate parameters.");
        let new_params = args
            .into_iter()
            .try_fold(Vec::new(), |mut xs, arg| match arg {
                PEParameter::DataTransferPrealloc(x) => {
                    if x.to_device {
                        match self.offchip_memory.iter_mut().find(|y| y.id == x.memory) {
                            Some(mem) => {
                                mem.dma
                                    .copy_to(&self.completion, &x.data[..], x.device_address)
                                    .context(DMAError)?;
                                xs.push(PEParameter::DeviceAddress(x.device_address));
                            }
                            None => return Err(Error::UnknownMemory { id: x.memory }),
                        }
                    }
                    if x.from_device {
                        pe.add_copyback(x);
                    }
                    Ok(xs)
                }
                _ => {
                    xs.push(arg);
                    Ok(xs)
                }
            });
        trace!("All transfer to parameters handled.");
        new_params
    }

    pub fn acquire_pe(&mut self, id: PEId) -> Result<PE> {
        self.check_exclusive_access()?;
        trace!("Trying to acquire PE of type {}.", id);
        let pe = self.scheduler.acquire_pe(id).context(SchedulerError)?;
        trace!("Successfully acquired PE of type {}.", id);
        Ok(pe)
    }

    pub fn start_pe(&mut self, pe: &mut PE, args: Vec<PEParameter>) -> Result<()> {
        self.check_exclusive_access()?;
        trace!("Starting execution of {:?} with Arguments {:?}.", pe, args);
        let local_args = self.handle_allocates(args)?;
        trace!("Handled allocates => {:?}.", local_args);
        let trans_args = self.handle_transfers_to_device(pe, local_args)?;
        trace!("Handled transfers => {:?}.", trans_args);
        trace!("Setting arguments.");
        for (i, arg) in trans_args.into_iter().enumerate() {
            trace!("Setting argument {} => {:?}.", i, arg);
            match arg {
                PEParameter::Single32(_) => {
                    pe.set_arg(&mut self.arch, i, arg).context(SchedulerError)?
                }
                PEParameter::Single64(_) => {
                    pe.set_arg(&mut self.arch, i, arg).context(SchedulerError)?
                }
                PEParameter::DeviceAddress(x) => pe
                    .set_arg(&mut self.arch, i, PEParameter::Single64(x))
                    .context(SchedulerError)?,
                _ => return Err(Error::UnsupportedRegisterParameter { arg: arg }),
            };
        }
        trace!("Arguments set.");
        trace!("Starting PE execution.");
        pe.start(&mut self.arch).context(SchedulerError)?;
        self.active_pes.insert(*pe.id(), false);
        trace!("PE started.");
        Ok(())
    }

    pub fn release_pe(&mut self, mut pe: PE) -> Result<Option<Vec<Vec<u8>>>> {
        self.check_exclusive_access()?;
        trace!("Trying to release {:?}.", pe);
        if *pe.active() {
            self.wait_for_completion(&mut pe)?;
        }
        trace!("PE is idle.");
        let copyback = pe.get_copyback();
        self.scheduler.release_pe(pe).context(SchedulerError)?;
        trace!("Release successful.");
        match copyback {
            Some(x) => {
                let res = x
                    .into_iter()
                    .map(|mut param| {
                        match self
                            .offchip_memory
                            .iter_mut()
                            .find(|y| y.id == param.memory)
                        {
                            Some(mem) => {
                                mem.dma
                                    .copy_from(
                                        &self.completion,
                                        param.device_address,
                                        &mut param.data[..],
                                    )
                                    .context(DMAError)?;
                                Ok(param.data)
                            }
                            None => Err(Error::UnknownMemory { id: param.memory }),
                        }
                    })
                    .collect();
                match res {
                    Ok(x) => Ok(Some(x)),
                    Err(x) => Err(x),
                }
            }
            None => Ok(None),
        }
    }

    fn check_exclusive_access(&self) -> Result<()> {
        if self.access != tlkm_access::TlkmAccessExclusive {
            Err(Error::ExclusiveRequired {})
        } else {
            Ok(())
        }
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

        if access == tlkm_access::TlkmAccessExclusive {
            trace!("Access changed to exclusive, resetting all interrupts.");
            self.scheduler
                .reset_interrupts(&mut self.arch)
                .context(SchedulerError)?;
        }

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

    pub fn design_frequency(&self) -> Result<Frequency> {
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
        Ok(Frequency::new::<megahertz>(freq as f32))
    }
}
