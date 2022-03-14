use std::{
    collections::HashMap,
};

use tapasco::{
    tlkm::*,
    device::status::Interrupt,
    pe::PE, 
    device::PEParameter,
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


// TODO: Right now I'm just handling the first FPGA device because I assume most will have
// only one FPGA but switching devices should be possible e.g. by passing the device as cli
// argument or with an extra key binding?
// TODO: It would be nice to see when/how many interrupts were triggered.


pub struct App<'a> {
    bitstream_info: String,
    platform_info: String,
    pub title: &'a str,
    pub tabs: TabsState<'a>,
    pub pe_infos: StatefulList<String>,
    pub pes: Vec<(usize, PE)>, // Plural of Processing Element (PEs)
}

impl<'a> App<'a> {
    pub fn new() -> Result<App<'a>> {
        // Get Tapasco Loadable Linux Kernel Module
        let tlkm = TLKM::new().context(TLKMInit {})?;
        //let tlkm_device = tlkm.device_enum(&HashMap::new()).context(TLKMInit {})?;
        // Allocate the first device with ID 0 (because most devices will only have one FPGA)
        let mut tlkm_device = tlkm.device_alloc(0, &HashMap::new()).context(TLKMInit {})?;
        // Change device access to excluse to be able to acquire PEs
        tlkm_device.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive).context(DeviceInit {})?;

        let tlkm_version = tlkm.version().context(TLKMInit {})?;
        let platform_base = tlkm_device.status().platform_base.clone().expect("Could not get platform_base!");
        let arch_base = tlkm_device.status().arch_base.clone().expect("Could not get arch_base!");

        // Now d is shorthand for tlkm_device
        let d = &tlkm_device;

        // Parse info about PEs from the status core
        let mut pe_infos = Vec::new();
        // Preallocate this vector to set the acquired PE at the right position later
        let mut pes: Vec<(usize, PE)> = Vec::with_capacity(d.status().pe.len());

        for (index, pe) in d.status().pe.iter().enumerate() {
            // Calculate the "real" address using arch base address plus PE offset
            let address = &arch_base.base + pe.offset;
            pe_infos.push(
                // TODO: How wide is this address? 32 or 64 (48) bits?
                format!("Slot {}: {} (ID: {})    Address: 0x{:012x} ({}), Size: 0x{:x} ({} Bytes)",
                        index, pe.name, pe.id, address, address, pe.size, pe.size));

            // Acquire the PE to be able to show its registers etc.
            // Warning: casting to usize can panic! On a <32-bit system..
            let pe = d.acquire_pe_without_job(pe.id as usize).context(DeviceInit {})?;
            // TODO: There is no way to check that you really got the PE that you wanted
            // so I have to use this workaround to set it at the ID of the PE struct which
            // confusingly is NOT the pe.id from above which is stored at type_id inside the PE.
            let pe_real_id = *pe.id();
            //pes[pe_real_id] = pe;
            pes.push((pe_real_id, pe));
        }

        // Preselect the first element if the device's bitstream contains at least one PE
        let pe_infos = if pe_infos.len() > 0 {
            StatefulList::with_items_selected(pe_infos, 0)
        } else {
            StatefulList::with_items(pe_infos)
        };

        // Parse bitstream info from the Status core
        let mut bitstream_info = String::new();
        // TODO: decode vendor and product IDs
        bitstream_info += &format!(" Device ID: {} ({}),\n Vendor: {}, Product: {},\n\n",
                                   d.id(), d.name(), d.vendor(), d.product());

        // Warning: casting to i64 can panic! If the timestamp is bigger than 63 bit..
        bitstream_info += &format!(" Bitstream generated at:\n {} ({})\n\n",
                                   Utc.timestamp(d.status().timestamp as i64, 0),
                                   d.status().timestamp);

        for v in &d.status().versions {
            bitstream_info += &format!(" {} Version: {}.{}{}\n",
                                       v.software, v.year, v.release, v.extra_version);
        }
        bitstream_info += &format!(" TLKM Version: {}\n\n", tlkm_version);

        for c in &d.status().clocks {
            bitstream_info += &format!(" {} Clock Frequency: {} MHz\n",
                                       c.name, c.frequency_mhz);
        }

        // Parse platform info from the Status core
        let mut platform_info = String::new();

        platform_info += &format!(" Platform Base: 0x{:012x} (Size: 0x{:x} ({} Bytes))\n\n",
                                  platform_base.base, platform_base.size, platform_base.size); 

        for p in &d.status().platform {
            // TODO: is this correct? PEs use arch_base, platform components use platform_base?
            let address = &platform_base.base + p.offset;
            platform_info +=
                &format!(" {}:\n   Address: 0x{:012x} ({}), Size: 0x{:x} ({} Bytes)\n   Interrupts: {}\n\n",
                         p.name.trim_start_matches("PLATFORM_COMPONENT_"), address, address,
                         p.size, p.size, parse_interrupts(&p.interrupts));
        }


        Ok(App {
            bitstream_info,
            platform_info,
            title: "TaPaSCo Debugger",
            tabs: TabsState::new(vec!["Peek & Poke", "DMAEngine Statistics"]),
            pe_infos,
            pes,
        })
    }

    pub fn next_tab(&mut self) {
        self.tabs.next();
    }

    pub fn previous_tab(&mut self) {
        self.tabs.previous();
    }

    pub fn on_up(&mut self) {
        self.pe_infos.previous();
    }

    pub fn on_down(&mut self) {
        self.pe_infos.next();
    }

    pub fn on_escape(&mut self) {
        self.pe_infos.unselect();
    }

    pub fn on_return(&mut self) {
        match self.pe_infos.state.selected() {
            // TODO: Implement changing the focused widget
            Some(_n) => {},
            _ => {},
        }
    }

    pub fn get_bitstream_info(&mut self) -> &str {
        &self.bitstream_info
    }

    pub fn get_platform_info(&mut self) -> &str {
        &self.platform_info
    }

    pub fn read_pe_registers(&mut self, pe_slot: Option<usize>) -> String {
        let pe_slot = match pe_slot {
            Some(n) => n,
            _ => return "\n No PE selected.".to_string(),
        };

        // Get the PE with the real ID of the given Slot
        let (_, pe) = self.pes.iter()
            .filter(|(id, _)| *id == pe_slot)
            .take(1)
            .collect::<Vec<&(usize, PE)>>()
            .get(0)
            .expect("There should be a PE with the selected ID. This is a bug.");

        let (global_interrupt, local_interrupt) = pe.interrupt_status().expect("Expected to get PE interrupt status.");
        let return_value = pe.return_value();
        let argument_registers = (0..16)
            .map(|i| match pe.read_arg(i, 8).expect("Expected to be able to read PE registers!") {
                PEParameter::Single64(u) => u,
                _ => 0
            })
            .collect::<Vec<u64>>();

        // TODO: From where can I get those?
        let is_running = false;
        let interrupt_pending = false;

        let mut result = String::new();
        result += &format!(concat!(" PE is running: {}\n Local  Interrupt Enabled: {}\n",
                                   " Global Interrupt Enabled: {}\n Interrupt pending: {}\n\n",
                                   " Return Value: 0x{:16x}\n\n"),
                           is_running, local_interrupt, global_interrupt, interrupt_pending,
                           return_value);
        for (i, a) in argument_registers.iter().enumerate() {
            result += &format!(" A#{:02}: 0x{:16x} ({})\n", i, a, a);
        }

        result
    }
}

fn parse_interrupts(interrupts: &Vec<Interrupt>) -> String {
    let mut result = String::new();

    if interrupts.len() == 0 {
        result += "None";
    }
    else {
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
        TabsState {
            titles,
            index: 0,
        }
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
    pub fn new() -> StatefulList<T> {
        StatefulList {
            state: ListState::default(),
            items: Vec::new(),
        }
    }

    pub fn with_items(items: Vec<T>) -> StatefulList<T> {
        StatefulList {
            state: ListState::default(),
            items,
        }
    }

    pub fn with_items_selected(items: Vec<T>, selected: usize) -> StatefulList<T> {
        let mut list = StatefulList {
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
            },
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
            },
            None => self.items.len() - 1,
        };

        self.state.select(Some(n));
    }

    pub fn unselect(&mut self) {
        self.state.select(None);
    }
}
