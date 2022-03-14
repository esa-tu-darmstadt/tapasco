use std::{collections::HashMap, sync::Arc};

use log::{error, trace, warn};

use tapasco::{
    device::PEParameter,
    device::{status::Interrupt, Device},
    pe::PE,
    tlkm::TLKM,
};

use chrono::{TimeZone, Utc};

use snafu::{ResultExt, Snafu};

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Failed to initialize TLKM object: {}", source))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display("Failed to decode/acquire TLKM device or one of its PEs: {}", source))]
    DeviceInit { source: tapasco::device::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;

// Import the Subcommand enum from super module as AccessMode to clarify intent
pub use super::Command as AccessMode;

// TODO: It would be nice to see when/how many interrupts were triggered.

#[derive(Debug, PartialEq)]
pub enum InputMode {
    Normal,
    Edit,
}

#[derive(Debug, PartialEq)]
pub enum InputFrame {
    PEList,
    RegisterList,
}

pub struct App<'a> {
    _tlkm_option: Option<TLKM>,
    _device_option: Option<Device>,
    bitstream_info: String,
    platform_info: String,
    platform: Arc<memmap::MmapMut>,
    dmaengine_offset: Option<isize>,
    pub access_mode: AccessMode,
    pub input: String,
    pub input_mode: InputMode,
    pub focus: InputFrame,
    pub title: String,
    pub tabs: TabsState<'a>,
    pub pe_infos: StatefulList<String>,
    pub pes: Vec<(usize, PE)>, // Plural of Processing Element (PEs)
    pub register_list: StatefulList<String>,
    pub local_memory_list: StatefulList<String>,
}

impl<'a> App<'a> {
    pub fn new(device_id: u32, access_mode: AccessMode) -> Result<App<'a>> {
        trace!("Creating new App for Tapasco state");

        // Get Tapasco Loadable Linux Kernel Module
        let tlkm = TLKM::new().context(TLKMInit {})?;
        // Allocate the device with the given ID
        let mut tlkm_device = tlkm
            .device_alloc(device_id, &HashMap::new())
            .context(TLKMInit {})?;

        // For some access modes we need to take some special care to use them
        let access_mode_str = match access_mode {
            AccessMode::Monitor {} => {
                // Monitor Mode: In order to observe other Tapasco Host applications which need exclusive
                // access we implement a monitor mode where registers cannot be modified. For this
                // no special access is necessary. This is a no-op.
                "Monitor"
            }
            AccessMode::Debug {} => {
                // Change device access to exclusive to be able to acquire PEs
                tlkm_device
                    .change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
                    .context(DeviceInit {})?;
                "Debug"
            }
            AccessMode::Unsafe {} => {
                // Change device access to exclusive to be able to acquire PEs
                tlkm_device
                    .change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
                    .context(DeviceInit {})?;
                warn!("Running in Unsafe Mode");
                "Unsafe"
            }
        };
        trace!("Access Mode is: {}", access_mode_str);

        // Empty string where input is stored
        let input = String::new();
        // Initialize App in Normal mode
        let input_mode = InputMode::Normal;
        // Initialize UI with focus on the PE list
        let focus = InputFrame::PEList;

        let tabs = TabsState::new(vec![
            "Peek & Poke PEs",
            "Platform Components",
            "Bitstream & Device Info",
        ]);
        let title = format!("TaPaSCo Debugger - {} Mode", access_mode_str);

        let tlkm_version = tlkm.version().context(TLKMInit {})?;
        let platform_base = tlkm_device
            .status()
            .platform_base
            .clone()
            .expect("Could not get platform_base!");
        let arch_base = tlkm_device
            .status()
            .arch_base
            .clone()
            .expect("Could not get arch_base!");
        let platform = tlkm_device.platform().clone();

        // Hold the TLKM if we are running in Debug mode, so it is not free'd after this method
        let _tlkm_option = if (access_mode == AccessMode::Debug {}) {
            Some(tlkm)
        } else {
            None
        };

        // Parse info about PEs from the status core
        // Preallocate these vectors to set the acquired PE at the right position later
        let mut pe_infos = Vec::with_capacity(tlkm_device.status().pe.len());
        let mut pes: Vec<(usize, PE)> = Vec::with_capacity(tlkm_device.status().pe.len());

        for (index, pe) in tlkm_device.status().pe.iter().enumerate() {
            // Calculate the "real" address using arch base address plus PE offset
            let address = arch_base.base + pe.offset;
            pe_infos.push(
                format!("Slot {}: {} (ID: {})    Address: 0x{:016x} ({}), Size: 0x{:x} ({} Bytes), Interrupts: {}, Debug: {:?}",
                        index, pe.name, pe.id, address, address, pe.size, pe.size, App::parse_interrupts(&pe.interrupts), pe.debug));

            // Acquire the PE to be able to show its registers etc.
            // Warning: casting to usize can panic! On a <32-bit system..
            let pe = tlkm_device
                .acquire_pe_without_job(pe.id as usize)
                .context(DeviceInit {})?;
            // TODO: There is no way to check that you really got the PE that you wanted
            // so I have to use this workaround to set it at the ID of the PE struct which
            // confusingly is NOT the pe.id from above which is stored at type_id inside the PE.
            let pe_real_id = *pe.id();
            //pes[pe_real_id] = pe;
            pes.push((pe_real_id, pe));
        }

        // Preselect the first element if the device's bitstream contains at least one PE
        let pe_infos = if pe_infos.is_empty() {
            StatefulList::with_items(pe_infos)
        } else {
            StatefulList::with_items_selected(pe_infos, 0)
        };

        // There are theoretically endless registers. 100 seems to be a good value.
        let register_list = StatefulList::with_items(vec!["".to_string(); 100]);
        let local_memory_list = StatefulList::new();

        // Parse bitstream info from the Status core
        let mut bitstream_info = String::new();
        // TODO: decode vendor and product IDs
        bitstream_info += &format!(
            "Device ID: {} ({}),\nVendor: {}, Product: {},\n\n",
            tlkm_device.id(),
            tlkm_device.name(),
            tlkm_device.vendor(),
            tlkm_device.product()
        );

        // Warning: casting to i64 can panic! If the timestamp is bigger than 63 bit..
        bitstream_info += &format!(
            "Bitstream generated at: {} ({})\n\n",
            Utc.timestamp(tlkm_device.status().timestamp as i64, 0)
                .format("%Y-%m-%d"),
            tlkm_device.status().timestamp
        );

        for v in &tlkm_device.status().versions {
            bitstream_info += &format!(
                "{} Version: {}.{}{}\n",
                v.software, v.year, v.release, v.extra_version
            );
        }
        bitstream_info += &format!("TLKM Version: {}\n\n", tlkm_version);

        for c in &tlkm_device.status().clocks {
            bitstream_info += &format!("{} Clock Frequency: {} MHz\n", c.name, c.frequency_mhz);
        }

        // Parse platform info from the Status core
        let mut platform_info = String::new();

        let mut dmaengine_offset = None;
        platform_info += &format!(
            "Platform Base: 0x{:012x} (Size: 0x{:x} ({} Bytes))\n\n",
            platform_base.base, platform_base.size, platform_base.size
        );

        for p in &tlkm_device.status().platform {
            let address = platform_base.base + p.offset;
            platform_info += &format!(
                "{}:\n  Address: 0x{:012x} ({}), Size: 0x{:x} ({} Bytes)\n  Interrupts: {}\n\n",
                p.name.trim_start_matches("PLATFORM_COMPONENT_"),
                address,
                address,
                p.size,
                p.size,
                App::parse_interrupts(&p.interrupts)
            );

            if p.name == "PLATFORM_COMPONENT_DMA0" {
                dmaengine_offset = Some(p.offset as isize);
            }
        }

        // Hold the TLKM Device if we are running in Debug mode, so it is not free'd after this method
        let _device_option = if (access_mode == AccessMode::Debug {}) {
            Some(tlkm_device)
        } else {
            None
        };

        trace!("Constructed App");

        Ok(App {
            _tlkm_option,
            _device_option,
            bitstream_info,
            platform_info,
            platform,
            dmaengine_offset,
            access_mode,
            input,
            input_mode,
            focus,
            title,
            tabs,
            pe_infos,
            pes,
            register_list,
            local_memory_list,
        })
    }

    pub fn next_tab(&mut self) {
        self.tabs.next();
    }

    pub fn previous_tab(&mut self) {
        self.tabs.previous();
    }

    pub fn on_up(&mut self) {
        if self.tabs.index == 0 {
            match self.focus {
                InputFrame::PEList => self.pe_infos.previous(),
                InputFrame::RegisterList => self.register_list.previous(),
            };
        };
    }

    pub fn on_down(&mut self) {
        if self.tabs.index == 0 {
            match self.focus {
                InputFrame::PEList => self.pe_infos.next(),
                InputFrame::RegisterList => self.register_list.next(),
            };
        };
    }

    pub fn on_escape(&mut self) {
        if self.tabs.index == 0 {
            match self.input_mode {
                InputMode::Normal => {
                    match self.focus {
                        InputFrame::PEList => self.pe_infos.unselect(),
                        InputFrame::RegisterList => {
                            self.register_list.unselect();
                            self.focus = InputFrame::PEList;
                        }
                    };
                }
                InputMode::Edit => {
                    self.input_mode = InputMode::Normal;
                    self.input.clear();
                }
            };
        };
    }

    pub fn on_enter(&mut self) {
        if self.tabs.index == 0 {
            match self.access_mode {
                AccessMode::Monitor {} => {}
                AccessMode::Debug {} | AccessMode::Unsafe {} => {
                    match self.input_mode {
                        InputMode::Normal => {
                            match self.focus {
                                // Change the focused component to the register list of the selected PE
                                InputFrame::PEList => match self.pe_infos.state.selected() {
                                    Some(_) => {
                                        self.focus = InputFrame::RegisterList;
                                        self.register_list.next();
                                    }
                                    _ => self.pe_infos.next(),
                                },
                                // Enter Edit Mode for a new register value
                                InputFrame::RegisterList => {
                                    self.input_mode = InputMode::Edit;
                                }
                            };
                        }
                        InputMode::Edit => {
                            // If the input cannot be parsed correctly, simply do nothing until
                            // we either hit Escape or enter a valid decimal integer.
                            if let Ok(new_value) = self.input.parse::<i64>() {
                                self.input.clear();

                                // Ignore the error because unless the code changes, there will
                                // be no error returned by this function.
                                if let Err(e) = self.pes
                                    .get_mut(self.pe_infos.state.selected()
                                             .expect("There should have been a selected PE. This is a bug."))
                                    .expect("There should have been a PE for the selection. This is a bug.")
                                    .1 // ignore the index, select the PE from the tuple
                                    .set_arg(self.register_list.state.selected().unwrap(),
                                             PEParameter::Single64(new_value as u64)) {
                                    // but log this error in case the code changes
                                    error!("Error setting argument: {}.
                                            This is probably due to libtapasco having changed something
                                            important. You should fix this app.", e);
                                }

                                self.input_mode = InputMode::Normal;
                            }
                        }
                    };
                }
            };
        };
    }

    pub fn get_bitstream_info(&self) -> &str {
        &self.bitstream_info
    }

    pub fn get_platform_info(&self) -> &str {
        &self.platform_info
    }

    fn get_current_pe(&self) -> Option<&PE> {
        let pe_slot = match self.pe_infos.state.selected() {
            Some(n) => n,
            _ => return None,
        };

        // Get the PE with the real ID of the selected Slot
        let (_, pe) = self
            .pes
            .iter()
            .filter(|(id, _)| *id == pe_slot)
            .take(1)
            .collect::<Vec<&(usize, PE)>>()
            .get(0)
            .expect("There should be a PE with the selected ID. This is a bug.");

        Some(pe)
    }

    //pub fn start_current_pe(&self) {
    //    if (self.access_mode != AccessMode::Debug {}) {
    //        return;
    //    }

    //    if let Some(pe) = self.get_current_pe() {
    //        if let Some(device) = &self._device_option {
    //            // TODO: This might not be the correct PE when there are multiple PEs with the same
    //            // TypeID.
    //            match device.acquire_pe(*pe.type_id()) {
    //                Ok(mut pe) => {
    //                    trace!("Acquired PE: {:?}", pe);
    //                    if let Ok(_) = pe.start(vec![]) {
    //                        trace!("Started PE: {:?}", pe);
    //                        if let Ok(_) = pe.release(true, true) {
    //                            trace!("Starting PE: {:?}", pe);
    //                        }
    //                    }
    //                },
    //                Err(e) => error!("Could not acquire PE: {}", e),
    //            }
    //        }
    //    }
    //}

    pub fn get_status_registers(&mut self) -> String {
        if let Some(pe) = self.get_current_pe() {
            let (global_interrupt, local_interrupt) = pe
                .interrupt_status()
                .expect("Expected to get PE interrupt status.");
            let return_value = pe.return_value();

            // TODO: I have to get these from the runtime because there are no registers for that.
            //let is_running = false;
            //let interrupt_pending = false;

            let mut result = String::new();
            //result += &format!("PE is running: {}", is_running);
            result += &format!("Local  Interrupt Enabled: {}\n", local_interrupt);
            result += &format!("Global Interrupt Enabled: {}\n", global_interrupt);
            //result += &format!("Interrupt pending: {}", interrupt_pending);
            result += &format!(
                "Return: 0x{:16x} (i32: {:10})\n",
                return_value, return_value as i32
            );

            result
        } else {
            "No PE selected.".to_string()
        }
    }

    pub fn get_argument_registers(&mut self) -> Vec<String> {
        if let Some(pe) = self.get_current_pe() {
            let argument_registers = (0..self.register_list.items.len())
                .map(|i| {
                    match pe
                        .read_arg(i, 8)
                        .expect("Expected to be able to read PE registers!")
                    {
                        PEParameter::Single64(u) => u,
                        _ => unreachable!(),
                    }
                })
                .collect::<Vec<u64>>();

            let mut result = Vec::new();
            for (i, a) in argument_registers.iter().enumerate() {
                result.push(format!("Arg#{:02}: 0x{:16x} ({:20})\n", i, a, a));
            }

            result
        } else {
            vec!["No PE selected.".to_string()]
        }
    }

    pub fn dump_current_pe_local_memory(&self) -> Vec<String> {
        if let Some(pe) = self.get_current_pe() {
            let local_memory = match pe.local_memory() {
                Some(m) => m,
                _ => return vec!["No local memory for this PE.".to_string()],
            };

            let mut memory_cells: Box<[u8]> = Box::new([0_u8; 16 * 100]);
            match local_memory.dma().copy_from(0, &mut memory_cells) {
                Ok(_) => {}
                _ => return vec!["Could not read PE Local Memory!".to_string()],
            }

            let mut result: Vec<String> = Vec::new();
            for (i, s) in memory_cells.chunks_exact(16).enumerate() {
                // format bytes like hexdump
                result.push(format!(
                    "{:08x}: {}\n",
                    16 * i,
                    s.iter()
                        .map(|x| format!("{:02x}", x))
                        .collect::<Vec<String>>()
                        .join(" ")
                ));
            }

            result
        } else {
            vec!["No PE selected.".to_string()]
        }
    }

    fn parse_interrupts(interrupts: &[Interrupt]) -> String {
        let mut result = String::new();

        if interrupts.is_empty() {
            result += "None";
        } else {
            result += "[ ";

            for (index, interrupt) in interrupts.iter().enumerate() {
                if index > 0 {
                    result += ", ";
                }

                result += &format!("{}:{}", interrupt.mapping, interrupt.name);
            }

            result += " ]";
        }

        result
    }

    pub fn get_dmaengine_statistics(&self) -> String {
        let dmaengine_offset = match self.dmaengine_offset {
            Some(s) => s,
            _ => return "No DMAEngine found!".to_string(),
        };

        let status_registers: Vec<(&str, isize)> = vec![
            ("Number of Read Requests        ", 48),
            ("Number of Write Requests       ", 56),
            ("Cycles since last Read Request ", 64),
            ("Cycles between Read Requests   ", 72),
            ("Cycles since last Write Request", 88),
            ("Cycles between Write Requests  ", 96),
        ];

        let mut result = String::new();
        for (index, r) in status_registers.iter().enumerate() {
            unsafe {
                // Create a const pointer to the u64 register at the offset in the platform address
                // space of the DMAEngine
                let dmaengine_register_ptr = self
                    .platform
                    .as_ptr()
                    .offset(dmaengine_offset + r.1)
                    .cast::<u64>();
                // Read IO register with volatile, see:
                // https://doc.rust-lang.org/std/ptr/fn.read_volatile.html
                let dmaengine_register = dmaengine_register_ptr.read_volatile();

                if index < 2 {
                    // Calculating ms doesn't make sense for the number of Reads/Writes
                    result += &format!(
                        "{}    {:016x}    ({:20})\n",
                        r.0, dmaengine_register, dmaengine_register
                    );
                } else {
                    // Warning: This assumes the host frequency to be 250MHz which should be the case
                    // everywhere.
                    result += &format!(
                        "{}    {:016x}    ({:20} = {:9} ns)\n",
                        r.0,
                        dmaengine_register,
                        dmaengine_register,
                        dmaengine_register * 4
                    );
                }
            }

            // Add a newline every second line
            if index % 2 == 1 {
                result += "\n";
            }
        }

        result
    }
}

// The following code is taken from libtui-rs demo:
// https://github.com/fdehau/tui-rs/blob/v0.15.0/examples/util/mod.rs
// licensed under MIT License by Florian Dehau, see:
// https://spdx.org/licenses/MIT.html
pub struct TabsState<'a> {
    pub titles: Vec<&'a str>,
    pub index: usize,
}

impl<'a> TabsState<'a> {
    pub fn new(titles: Vec<&'a str>) -> TabsState {
        TabsState { titles, index: 0 }
    }

    pub fn next(&mut self) {
        self.index = (self.index + 1) % self.titles.len();
    }

    pub fn previous(&mut self) {
        self.index = if self.index == 0 {
            self.titles.len() - 1
        } else {
            self.index - 1
        }
    }
}

use tui::widgets::ListState;

pub struct StatefulList<T> {
    pub state: ListState,
    pub items: Vec<T>,
}

impl<T> StatefulList<T> {
    pub fn new() -> Self {
        Self {
            state: ListState::default(),
            items: Vec::new(),
        }
    }

    pub fn with_items(items: Vec<T>) -> Self {
        Self {
            state: ListState::default(),
            items,
        }
    }

    pub fn with_items_selected(items: Vec<T>, selected: usize) -> Self {
        let mut list = Self {
            state: ListState::default(),
            items,
        };
        list.state.select(Some(selected));

        list
    }

    pub fn next(&mut self) {
        let n = match self.state.selected() {
            Some(m) => {
                if m >= self.items.len() - 1 {
                    0
                } else {
                    m + 1
                }
            }
            None => 0,
        };

        self.state.select(Some(n));
    }

    pub fn previous(&mut self) {
        let n = match self.state.selected() {
            Some(m) => {
                if m == 0 {
                    self.items.len() - 1
                } else {
                    m - 1
                }
            }
            None => self.items.len() - 1,
        };

        self.state.select(Some(n));
    }

    pub fn unselect(&mut self) {
        self.state.select(None);
    }
}
