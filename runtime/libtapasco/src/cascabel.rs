use packed_struct::prelude::*;
use crate::pe::{PEId,PE,PEInteraction};
use crate::debug::NonDebug;
use crate::device::DeviceAddress;
use crate::device::PEParameter;
use crate::device::status;
use crate::interrupt::Interrupt;
use crate::scheduler::*;
use snafu::ResultExt;
use std::fs::File;
use crossbeam::deque::{Injector, Steal};
use std::collections::HashMap;
use volatile::Volatile;
use memmap::MmapMut;
use std::sync::Arc;
use std::thread;

#[derive(Debug, Snafu)]
pub enum CascabelError {
    #[snafu(display("PE Type {} is unknown.", id))]
    NoSuchPE { id: PEId },

    #[snafu(display("Error during interrupt handling: {}", source))]
    ErrorInterrupt { source: crate::interrupt::Error },

    #[snafu(display("Error creating interrupt eventfd: {}", source))]
    ErrorEventFD { source: nix::Error },

    #[snafu(display("Error reading interrupt eventfd: {}", source))]
    ErrorEventFDRead { source: nix::Error },

    #[snafu(display("Could not register eventfd with driver: {}", source))]
    ErrorEventFDRegister { source: nix::Error },
}

type Result<T, E = CascabelError> = std::result::Result<T, E>;
type SchedulerResult<T, E = Error> = std::result::Result<T, E>;
type PeResult<T, E = crate::pe::Error> = std::result::Result<T, E>;

#[derive(Debug, Clone)]
#[repr(C)]
struct CascabelCtrl {
    count: Volatile<u32>,
    magic: Volatile<u32>,
    read_ptr: Volatile<u64>,
    write_ptr: Volatile<u64>, // 0x10
    align00: i64,
    filllevel: Volatile<u64>, // 0x20
    align0: [i64; 3],
    atomic_read_ptr: Volatile<u64>, // 0x40
    align1: [i64; 7],
    atomic_write_ptr: Volatile<u64>, // 0x80
}

#[derive(PackedStruct, Debug, Copy, Clone)]
#[packed_struct(endian="msb", bit_numbering="lsb0", size_bytes="64")]
pub struct QueueElement {
    #[packed_field(bits="0")]
    valid: bool,
    #[packed_field(bits="8:1")]
    irq_number: u8,
    #[packed_field(bits="9")]
    signal_host: bool,
    #[packed_field(bits="265:10",elem_size_bits="64")]
    params: [u64; 4],
    #[packed_field(bits="268:266")]
    param_count: Integer<u8, packed_bits::Bits3>,
    #[packed_field(bits="300:269")]
    job_id: u32,
    #[packed_field(bits="308:301")]
    kernel_id: u8,
    #[packed_field(bits="309")]
    kerneltype: bool,
    #[packed_field(bits="310")]
    valid2: bool,
}

impl QueueElement {
    pub fn new (
        kernel_id: PEId,
        interrupt_id: usize,
    ) -> Result<QueueElement> {
        Ok(QueueElement {
            signal_host: true,
            irq_number: interrupt_id as u8,
            params: [0x11,0x22,0x33,0x44],
            param_count: 0.into(),
            job_id: 0,
            kernel_id: kernel_id as u8,
            kerneltype: false,
            valid: true,
            valid2: true,
        })
    }

    pub fn set_arg(&mut self, i: usize, val: PEParameter) {
        assert!(i < 4);
        match val {
            PEParameter::Single32(x) => {
                self.params[i] = x as u64;
            }
            PEParameter::Single64(x) => {
                self.params[i] = x;
            }
            _ => {
                assert!(false);
            }
        }
        if (i+1) > (self.param_count.to_primitive().into()) {
            trace!("new maximum param count of {}", (i+1));
            self.param_count = ((i+1) as u8).into();
        }
    }

    /// Read out parameters from cascabel queue
    /// These are not the actual values at the PE
    pub fn read_arg(&self, i: usize, bytes: usize) -> PeResult<PEParameter> {
        assert!(i < 4);
        let r = match bytes {
            4 => Ok(PEParameter::Single32(
                self.params[i] as u32
            )),
            8 => Ok(PEParameter::Single64(
                self.params[i] as u64
            )),
            _ => Err(crate::pe::Error::UnsupportedRegisterSize { param: bytes }),
        };
        trace!(
            "Reading argument: ({} x {}B) -> {:?}",
            i,
            bytes,
            r
        );
        r
    }
}

#[derive(Debug)]
pub struct CascabelScheduler {
    ctrl_offset: isize,
    platform: Arc<MmapMut>,
    queue_offset: u64,
    pes: HashMap<PEId, usize>,
    interrupts: Injector<(u8, Interrupt)>,
}

impl CascabelScheduler {
    pub fn new(
        pes: &Vec<status::Pe>,
        status: status::Status,
        platform: Arc<MmapMut>,
        completion: &File,
        is_pcie: bool,
    ) -> Result<CascabelScheduler> {
        // get overview of all available pes
        let mut pes_hashed: HashMap<PEId, usize> = HashMap::new();
        let interrupts = Injector::new();
        for (i, pe) in pes.iter().enumerate() {
            match pes_hashed.get_mut(&(pe.id as PEId)) {
                Some(l) => *l += 1,
                None => {
                    pes_hashed.insert(pe.id as PEId, 1);
                }
            };
            //let interrupt_id = pe.interrupts[0].mapping as usize;
            let interrupt_id = i;

            let mut interrupt_offset = 0;
            if is_pcie {
                interrupt_offset = 4;
            }
            let interrupt = Interrupt::new(completion, interrupt_id + interrupt_offset, false).context(ErrorInterrupt)?;
            trace!("Registering interrupt {}, {:?}", interrupt_id, interrupt);
            interrupts.push((interrupt_id as u8, interrupt));
        }
        // read out cascabel ctrl from status core:
        let cascabel0 = &status.platform.iter().find(|&x| x.name == "PLATFORM_COMPONENT_CASCABEL0").unwrap();
        let cascabel1 = &status.platform.iter().find(|&x| x.name == "PLATFORM_COMPONENT_CASCABEL1").unwrap();
        let ctrl = unsafe {
            &mut *(platform.as_ptr().offset(cascabel0.offset as isize) as *mut CascabelCtrl)
        };
        assert_eq!(ctrl.magic.read(), 0xca3cabe1);
        assert_eq!(ctrl.count.read(), 128); // hard code size
        trace!("Ctrl read {:x?} write {:x?}", ctrl.read_ptr.read(), ctrl.write_ptr.read());
        Ok(CascabelScheduler {
            ctrl_offset: cascabel0.offset as isize,
            platform: platform,
            queue_offset: cascabel1.offset,
            pes: pes_hashed,
            interrupts: interrupts,
        })
    }
}

impl Scheduler for CascabelScheduler {
    fn acquire_pe(&self, id: PEId) -> SchedulerResult<PE> {
        // TODO check if valid PEId

        let ctrl = unsafe {
            &mut *(self.platform.as_ptr().offset(self.ctrl_offset) as *mut CascabelCtrl)
        };
        let write_queue_ptr = ctrl.atomic_write_ptr.read();
        trace!("compare {} to {}", write_queue_ptr, ctrl.read_ptr.read());
        while write_queue_ptr - ctrl.read_ptr.read() > 100 {
            std::thread::yield_now();
        }

        let offset = write_queue_ptr % 128;

        let interrupt = loop {
            match self.interrupts.steal() {
                Steal::Success(interrupt) => break interrupt,
                Steal::Empty => (),
                Steal::Retry => (),
            }
            thread::yield_now();
        };
        trace!("Take interrupt #{}, {:?}", interrupt.0, interrupt.1);

        let the_pe = PE::new(
            0, //id
            id,
            self.queue_offset + offset*64,
            None, //size
            "Some(CascabelPE)".to_string(),
            None, //memory
            Some(self.platform.clone()),
            None, //&File
            interrupt.0 as usize, // interrupt_id
            Some(interrupt.1),
            Box::new(NonDebug {}),
        )
        .context(PEError)?;
        Ok(the_pe)
    }

    fn release_pe(&self, pe: PE) -> SchedulerResult<()> {
        ensure!(!pe.active(), PEStillActive { pe: pe });

        // enqueue interrupt into steal queue (including interrupt_id)
        self.interrupts.push((pe.interrupt_id as u8, pe.interrupt));

        Ok(())
    }

    fn reset_interrupts(&self) -> SchedulerResult<()> {
        // Do nothing
        Ok(())
    }

    fn num_pes(&self, id: PEId) -> usize {
        // TODO
        0
    }

    fn get_pe_id(&self, name: &str) -> SchedulerResult<PEId> {
        // TODO
        Err(Error::NoSuchPE { id: 0 })
    }
}

pub struct CascabelPE {
    offset: DeviceAddress, // queue element offset in cascabel queue
    cascabel: Arc<MmapMut>, // cascabel queue
    element: QueueElement,
}

impl CascabelPE {
    pub fn new(
        offset: DeviceAddress,
        cascabel: Arc<MmapMut>,
        interrupt_id: usize,
        type_id: PEId,
    ) -> Result<CascabelPE> {
        Ok(CascabelPE {
            offset: offset,
            cascabel: cascabel,
            element: QueueElement::new(type_id, interrupt_id)?,
        })
    }
}

impl PEInteraction for CascabelPE {
    fn start(&mut self) -> PeResult<()> {
        // TODO currently only one start per PE allowd, need a new queue element position for next launch
        let mut e_pack : [u8; 64] = self.element.pack().context(crate::pe::PackingError)?;
        e_pack.reverse(); // reverse to avoid little endian bug in packed_structs crate
        unsafe {
            let ptr = self.cascabel.as_ptr().offset(self.offset as isize) as *mut Volatile<[u8; 64]>;
            (*ptr).write(e_pack);
        }
        trace!("Starting PE with interrupt #{}", self.element.irq_number);
        Ok(())
    }

    fn interrupt_set(&self) -> PeResult<bool> {
        // Interrupts are handled in hardware
        Ok(true)
    }

    fn reset_interrupt(&self, v: bool) -> PeResult<()> {
        Ok(())
    }

    fn interrupt_status(&self) -> PeResult<(bool, bool)> {
        Ok((true, true))
    }

    fn enable_interrupt(&self) -> PeResult<()> {
        Ok(())
    }

    fn set_arg(&mut self, argn: usize, arg: PEParameter) -> PeResult<()> {
        self.element.set_arg(argn, arg);
        Ok(())
    }

    fn read_arg(&self, argn: usize, bytes: usize) -> PeResult<PEParameter> {
        self.element.read_arg(argn, bytes)
    }

    fn return_value(&self) -> u64 {
        // TODO read out return value
        0
    }
}
