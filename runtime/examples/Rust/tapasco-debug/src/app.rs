use std::collections::HashMap;

use tui::widgets::ListState;

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
    Navigation,
    Edit,
}

#[derive(Debug, PartialEq)]
pub enum InputFrame {
    PEList,
    RegisterList,
}

pub struct App<'a> {
    tlkm_device: Device,
    bitstream_info: String,
    platform_info: String,
    pub access_mode: AccessMode,
    pub input: String,
    pub input_mode: InputMode,
    pub focus: InputFrame,
    pub title: String,
    pub tabs: TabsState<'a>,
    pub pe_infos: StatefulList<String>,
    pub pes: Vec<(usize, PE)>, // Plural of Processing Element (PEs)
    pub register_list: ListState,
    pub local_memory_list: ListState,
    pub messages: Vec<String>,
}

impl<'a> App<'a> {
    pub fn new(device_id: u32, access_mode: AccessMode) -> Result<App<'a>> {
        trace!("Creating new App for Tapasco state");

        // Get Tapasco Loadable Linux Kernel Module
        let tlkm = TLKM::new().context(TLKMInit {})?;
        // Allocate the device with the given ID
        let tlkm_device = tlkm
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
            // TODO: 3. When Issue #296 is fixed, enable debug mode here again, too.
            //AccessMode::Debug {} => {
            //    // Change device access to exclusive to be able to acquire PEs
            //    tlkm_device
            //        .change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            //        .context(DeviceInit {})?;
            //    "Debug"
            //}
            AccessMode::Unsafe {} => {
                // Change device access to exclusive to be able to acquire PEs
                warn!("Running in Unsafe Mode");
                "Unsafe"
            }
        };
        trace!("Access Mode is: {}", access_mode_str);

        // Empty string where input is stored
        let input = String::new();
        // Initialize App in Navigation mode
        let input_mode = InputMode::Navigation;
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

        // There are theoretically endless registers and local memory
        let register_list = ListState::default();
        let local_memory_list = ListState::default();

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

        bitstream_info += &format!(
            "Bitstream generated at: {} ({})\n\n",
            if let Ok(i) = tlkm_device.status().timestamp.try_into() {
                format!("{}", Utc.timestamp(i, 0).format("%Y-%m-%d"))
            } else {
                "the future".to_string()
            },
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
        }

        // Setup a new Vector to store (event) messages. It's kind of like logging but as there
        // already is a real logger and we cannot add another logging implementation, we have to
        // provide something a little bit different and simpler to inform users about things like
        // started PEs.
        let messages: Vec<String> = Vec::new();

        trace!("Constructed App");

        Ok(App {
            tlkm_device,
            bitstream_info,
            platform_info,
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
            messages,
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
                InputMode::Navigation => {
                    match self.focus {
                        InputFrame::PEList => self.pe_infos.unselect(),
                        InputFrame::RegisterList => {
                            self.register_list.unselect();
                            self.focus = InputFrame::PEList;
                        }
                    };
                }
                InputMode::Edit => {
                    self.input_mode = InputMode::Navigation;
                    self.input.clear();
                }
            };
        };
    }

    pub fn on_enter(&mut self) {
        if self.tabs.index == 0 {
            match self.access_mode {
                AccessMode::Monitor {} => {}
                // TODO: 4. Replace the second next line with the next line:
                // AccessMode::Debug {} | AccessMode::Unsafe {} => {
                AccessMode::Unsafe {} => {
                    match self.input_mode {
                        InputMode::Navigation => {
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
                            let new_value: Option<u64> = if let Some(hex_string) = self.input.strip_prefix("0x") {
                                u64::from_str_radix(hex_string, 16).ok()
                            } else if let Ok(new_value) = self.input.parse::<u64>() {
                               Some(new_value)
                            } else if let Ok(new_value) = self.input.parse::<i64>() {
                               Some(new_value as u64)  // explicitly use as casting
                            } else {
                               None
                            };

                            if let Some(new_value) = new_value {
                                self.input.clear();

                                // Ignore the error because unless the code changes, there will
                                // be no error returned by this function.
                                if let Err(e) = self.pes
                                    .get_mut(self.pe_infos.state.selected()
                                             .expect("There should have been a selected PE. This is a bug."))
                                    .expect("There should have been a PE for the selection. This is a bug.")
                                    .1 // ignore the index, select the PE from the tuple
                                    .set_arg(self.register_list.selected().unwrap(),
                                             PEParameter::Single64(new_value)) {
                                    // but log this error in case the code changes
                                    error!("Error setting argument: {}.
                                            This is probably due to libtapasco having changed something
                                            important. You should fix this app.", e);
                                }

                                self.messages.push(format!("In slot {} set argument register {} to new value: {}.",
                                                           self.pe_infos.state.selected().unwrap(),
                                                           self.register_list.selected().unwrap(),
                                                           new_value));

                                self.input_mode = InputMode::Navigation;
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

        // Get the PE with the real ID of the selected slot
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

    pub fn start_current_pe(&self) -> String {
        assert!(self.access_mode == AccessMode::Unsafe {}, "Unsafe access mode necessary to start a PE! This function should not have been callable. This is a bug.");

        if let Some(pe) = self.get_current_pe() {
            // This does not work because `libtapasco` does a really god job of protecting its PEs
            // and access to them with Rust's ownership rules.
            //
            // Besides, this might not be the correct PE when there are multiple PEs with the same
            // TypeID.
            //match self.tlkm_device.acquire_pe(*pe.type_id()) {
            //    Ok(mut pe) => {
            //        trace!("Acquired PE: {:?}", pe);
            //        if let Ok(_) = pe.start(vec![]) {
            //            trace!("Started PE: {:?}", pe);
            //            if let Ok(_) = pe.release(true, true) {
            //                trace!("Starting PE: {:?}", pe);
            //            }
            //        }
            //    },
            //    Err(e) => error!("Could not acquire PE: {}", e),
            //}
            //
            trace!("Starting PE with ID: {}.", pe.id());

            let offset = (*pe.offset()).try_into().expect("Expected to be able to cast the PE offset.");

            unsafe {
                // Access PE memory just like in `libtapasco`:
                //use volatile::Volatile;
                //let ptr = pe.memory().as_ptr().offset(offset);
                //let volatile_ptr: *mut Volatile<u32> = ptr as *mut Volatile<u32>;
                //(*volatile_ptr).write(1);
                //
                // but instead of the `volatile` crate use std::ptr:
                let ptr = pe.memory().as_ptr().offset(offset);
                (ptr as *mut u32).write_volatile(1);
            }

            return format!("Send start signal to PE in slot: {}.", self.pe_infos.state.selected().expect("There needs to be a selected PE. This is a bug."))
        }

        "No PE selected.".to_string()
    }

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
                return_value, return_value as i32  // explicitly use as casting
            );

            return result
        }

        "No PE selected.".to_string()
    }

    pub fn get_argument_registers(&mut self, number_of_lines: usize) -> Vec<String> {
        let number_of_registers = self.register_list.selected().unwrap_or(0) + number_of_lines;

        if let Some(pe) = self.get_current_pe() {
            let argument_registers = (0..number_of_registers)
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

            return result
        }

        vec!["No PE selected.".to_string()]
    }

    pub fn dump_current_pe_local_memory(&self, number_of_lines: usize) -> Vec<String> {
        if let Some(pe) = self.get_current_pe() {
            let local_memory = match pe.local_memory() {
                Some(m) => m,
                _ => return vec!["No local memory for this PE.".to_string()],
            };

            let mut memory_cells: Vec<u8> = vec![0_u8; 16 * number_of_lines];
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
        let dmaengine_memory = unsafe {
            match self
                .tlkm_device
                .get_platform_component_memory("PLATFORM_COMPONENT_DMA0")
            {
                Ok(m) => m,
                Err(_) => return "No DMAEngine found!".to_string(),
            }
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
                let dmaengine_register_ptr = dmaengine_memory.as_ptr().offset(r.1).cast::<u64>();
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

pub struct StatefulList<T> {
    pub state: ListState,
    pub items: Vec<T>,
}

impl<T> Default for StatefulList<T> {
    fn default() -> Self {
        Self {
            state: ListState::default(),
            items: Vec::new(),
        }
    }
}

impl<T> StatefulList<T> {
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
}

// Define a new trait so we can implement methods for ListState
pub trait Select {
    fn next(&mut self);
    fn previous(&mut self);
    fn unselect(&mut self);
}

impl<T> Select for StatefulList<T> {
    fn next(&mut self) {
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

    fn previous(&mut self) {
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

    fn unselect(&mut self) {
        self.state.select(None);
    }
}

impl Select for ListState {
    fn next(&mut self) {
        let n = match self.selected() {
            Some(m) => m + 1,
            None => 0,
        };

        self.select(Some(n));
    }

    fn previous(&mut self) {
        let n = match self.selected() {
            Some(m) => {
                if m == 0 {
                    0
                } else {
                    m - 1
                }
            }
            None => 0,
        };

        self.select(Some(n));
    }

    fn unselect(&mut self) {
        self.select(None);
    }
}
