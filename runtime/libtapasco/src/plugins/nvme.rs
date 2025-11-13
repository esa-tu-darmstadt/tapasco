/*
 * Copyright (c) 2014-2025 Embedded Systems and Applications, TU Darmstadt.
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

use std::any::Any;
use std::fs::File;
use std::os::fd::AsRawFd;
use std::ptr::{read_volatile, write_volatile};
use std::sync::{Arc, Mutex};
use memmap::MmapMut;
use snafu::ResultExt;
use crate::plugins::plugin::{Plugin};
use crate::{declare_plugin};
use crate::device::Device;
use crate::ffi::update_last_error;
use crate::plugins::nvme::Error::NVMeNotAvailableError;
use crate::tlkm::{tlkm_bar_addr_cmd, tlkm_gp_buffer_allocate_cmd, tlkm_gp_buffer_map_cmd};
use crate::tlkm::{tlkm_ioctl_bar_addr, tlkm_ioctl_kernel_buffer_allocate, tlkm_ioctl_kernel_buffer_map};

#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum Error {
    #[snafu(display("Mutex has been poisoned"))]
    MutexError {},

    #[snafu(display("NVMe plugin not available"))]
    NVMeNotAvailableError {},

    #[snafu(display("IOCTL call returned error: {}", source))]
    IOCTLError { source: nix::Error},

    #[snafu(display("Could not retrieve off-chip memory: {}", source))]
    NoOffChipMemory { source: crate::device::Error },

    #[snafu(display("Failed to allocate buffer in off-chip memory: {}", source))]
    OffChipAllocationError { source: crate::allocator::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;
type PluginResult<T, E = crate::plugins::plugin::Error> = std::result::Result<T, E>;

impl<T> From<std::sync::PoisonError<T>> for Error {
    fn from(_error: std::sync::PoisonError<T>) -> Self {
        Self::MutexError {}
    }
}

impl From<Error> for crate::plugins::plugin::Error {
    fn from(error: Error) -> Self {
        Self::PluginInitializationError { source: Box::new(error) }
    }
}

#[derive(Debug)]
pub struct NvmePlugin {
    available: bool,
    enabled: bool,
    nvme_offset: usize,
    queue_base_addr: u64,
    memory: Mutex<Arc<MmapMut>>,
    _buffer_ids: Vec<usize>,
}

#[repr(C)]
struct NvmeStreamerIP {
    nvme_sq_tail_db: u64,
    nvme_cq_head_db: u64,
    bram_addr: u64,
    nsid: u64,
    prp_addr: u64,
    enabled: u64,
    id: u64,
    rsvd0: u64,

    pcie_read_base: u64,
    pcie_write_base: u64,
    ddr_read_base: u64,
    ddr_write_base: u64,
    rsvd1: [u64; 4], // reserved fields

    pcie_read_base_host: [u64; 16], // fixed-size array
    pcie_write_base_host: [u64; 16], // fixed-size array
}

const URAM_STREAMER_ID: u64 = 0xa4d210bb;
const LOCAL_DDR_STREAMER_ID: u64 = 0x72bedb1a;
const HOST_STREAMER_ID: u64 = 0xfb235ea7;

impl Plugin for NvmePlugin {
    /// Check whether NVMe plugin is available in loaded bitstream
    /// and initialize runtime plugin
    ///
    /// Depending on ID of Streamer IP PCIe BAR addresses are retrieved,
    /// memory is allocated in on-FPGA DRAM or DMA buffers are allocated
    /// and mapped in host DRAM. IP's CSR registers are set if possible.
    ///
    /// Plugin is initialized during device creation in [`Device.new`]
    ///
    /// [`Device.new`]: ../../device/struct.Device.html#method.new
    fn init(device: &Device,
            memory: &Arc<MmapMut>,
            tlkm_file: &Arc<File>
    ) -> PluginResult<Box<dyn Plugin>> {
        trace!("Initializing NVMe plugin");

        trace!("Search for NVMe platform components");
        let mut nvme_offset = 0;
        let mut queue_offset = 0;
        let mut data_offset = 0;
        let mut available = false;
        let mut buffer_ids = Vec::new();
        for comp in &device.status().platform {
            if comp.name == "PLATFORM_COMPONENT_NVME_CTRL" {
                trace!("NVMe component found");
                nvme_offset = comp.offset;
                available = true;
            } else if comp.name == "PLATFORM_COMPONENT_NVME_QUEUES" {
                queue_offset = comp.offset;
            } else if comp.name == "PLATFORM_COMPONENT_NVME_DATA" {
                data_offset = comp.offset;
            }
        }

        // retrieve ID of NVMe Streamer IP
        let nvme_memory = Mutex::new(memory.clone());
        let id = if available {
            let csr_memory = nvme_memory.lock()
                .map_err(|e| Error::from(e))?;
            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(nvme_offset as isize) as _;
                read_volatile(&(*ptr).id)
            }
        } else { 0 };

        // retrieve PCIe address of FPGA's BARs for computing the queues' addresses
        let mut bar_addr_cmd = tlkm_bar_addr_cmd {
            bar_idx: 0,
            bar_addr: 0,
        };
        unsafe {
            tlkm_ioctl_bar_addr(tlkm_file.as_raw_fd(), &mut bar_addr_cmd)
                .context(IOCTLSnafu {})?;
        }
        let bar0 = bar_addr_cmd.bar_addr;
        let bar2 = if id ==  LOCAL_DDR_STREAMER_ID {
            bar_addr_cmd.bar_idx = 2;
            bar_addr_cmd.bar_addr = 0;
            unsafe {
                tlkm_ioctl_bar_addr(tlkm_file.as_raw_fd(), &mut bar_addr_cmd)
                    .context(IOCTLSnafu {})?;
            }
            bar_addr_cmd.bar_addr
        } else { 0 };
        let queue_base_addr = if available {
            bar0 + queue_offset
        } else { 0 };

        if id == LOCAL_DDR_STREAMER_ID {
            trace!("NVMe streamer IP uses FPGA-local DDR memory");
            let csr_memory = nvme_memory.lock()
                .map_err(|e| Error::from(e))?;

            // set PCIe PRP list address
            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(nvme_offset as isize) as _;
                write_volatile(&mut (*ptr).prp_addr, bar0 + nvme_offset + (256u64 << 10));
            }

            // allocate memory in FPGA on-board DRAM and write BAR2 address
            let addr = device
                .default_memory()
                .context(NoOffChipMemorySnafu {})?
                .allocator()
                .lock()
                .map_err(|e| Error::from(e))?
                .allocate(128u64 << 20, None).context(OffChipAllocationSnafu {})?;

            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(nvme_offset as isize) as _;
                write_volatile(&mut (*ptr).pcie_read_base, bar2 + addr);
                write_volatile(&mut (*ptr).pcie_write_base, bar2 + addr + (64u64 << 20));
                write_volatile(&mut (*ptr).ddr_read_base, addr);
                write_volatile(&mut (*ptr).ddr_write_base, addr + (64u64 << 20));
            }
        } else if id == HOST_STREAMER_ID {
            trace!("NVMe streamer IP uses host memory");
            // allocate buffer in host DRAM and write address to config regs
            let csr_memory = nvme_memory.lock()
                .map_err(|e| Error::from(e))?;

            // set PCIe PRP list address
            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(nvme_offset as isize) as _;
                write_volatile(&mut (*ptr).prp_addr, bar0 + nvme_offset + (256u64 << 10));
            }

            // allocate DMA buffers in host DDR and write CSRs with PCIe addresses
            for i in 0..16 {
                let mut alloc_cmd = tlkm_gp_buffer_allocate_cmd {
                    size: 4 << 20,
                    buffer_id: 0,
                };
                unsafe {
                    tlkm_ioctl_kernel_buffer_allocate(tlkm_file.as_raw_fd(), &mut alloc_cmd)
                        .context(IOCTLSnafu {})?;
                }
                buffer_ids.push(alloc_cmd.buffer_id);
                let mut map_cmd = tlkm_gp_buffer_map_cmd {
                    buffer_id: alloc_cmd.buffer_id,
                    dev_addr: 0,
                };
                unsafe {
                    tlkm_ioctl_kernel_buffer_map(tlkm_file.as_raw_fd(), &mut map_cmd)
                        .context(IOCTLSnafu {})?;
                }
                unsafe {
                    let ptr: *mut NvmeStreamerIP = csr_memory
                        .as_ptr()
                        .offset(nvme_offset as isize) as _;
                    write_volatile(&mut (*ptr).pcie_read_base_host[i], map_cmd.dev_addr);
                }
                trace!("Allocated buffer with device address 0x{:x} and ID {}",
                    map_cmd.dev_addr, alloc_cmd.buffer_id);
            }
            for i in 0..16 {
                let mut alloc_cmd = tlkm_gp_buffer_allocate_cmd {
                    size: 4 << 20,
                    buffer_id: 0,
                };
                unsafe {
                    tlkm_ioctl_kernel_buffer_allocate(tlkm_file.as_raw_fd(), &mut alloc_cmd)
                        .context(IOCTLSnafu {})?;
                }
                buffer_ids.push(alloc_cmd.buffer_id);
                let mut map_cmd = tlkm_gp_buffer_map_cmd {
                    buffer_id: alloc_cmd.buffer_id,
                    dev_addr: 0,
                };
                unsafe {
                    tlkm_ioctl_kernel_buffer_map(tlkm_file.as_raw_fd(), &mut map_cmd)
                        .context(IOCTLSnafu {})?;
                }
                unsafe {
                    let ptr: *mut NvmeStreamerIP = csr_memory
                        .as_ptr()
                        .offset(nvme_offset as isize) as _;
                    write_volatile(&mut (*ptr).pcie_write_base_host[i], map_cmd.dev_addr);
                }
                trace!("Allocated buffer with device address 0x{:x} and ID {}",
                    map_cmd.dev_addr, alloc_cmd.buffer_id);
            }
        } else if id == URAM_STREAMER_ID {
            trace!("NVMe streamer IP uses URAM");
            let csr_memory = nvme_memory.lock()
                .map_err(|e| Error::from(e))?;
            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(nvme_offset as isize) as _;
                write_volatile(&mut (*ptr).bram_addr, bar0 + data_offset);
            }
        }

        let new = Self {
            available,
            enabled: false,
            nvme_offset: nvme_offset as usize,
            queue_base_addr,
            memory: nvme_memory,
            _buffer_ids: buffer_ids,
        };

        // set default namespace ID
        if available {
            new.set_nvme_namespace_id(1)?;
            info!("NVMe plugin available and initialized for current device");
        } else {
            trace!("NVMe plugin not available for current device");
        }
        Ok(Box::new(new))
    }

    /// Check whether NVMe plugin is available in loaded bitstream
    fn is_available(&self) -> bool {
        self.available
    }

    fn as_any(&self) -> &dyn Any {
        self
    }
    fn as_any_mut(&mut self) -> &mut dyn Any { self }
}

impl NvmePlugin {
    /// Set PCIe address of NVMe controller
    pub fn set_nvme_pcie_addr(&self, addr: u64) -> Result<()> {
        if self.available {
            // set PCIe addresses of doorbell registers
            let csr_memory = self.memory.lock()?;
            let sq_tail_db = addr + 0x1008;
            let cq_head_db = addr + 0x100c;
            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(self.nvme_offset as isize) as _;
                write_volatile(&mut (*ptr).nvme_sq_tail_db, sq_tail_db);
                write_volatile(&mut (*ptr).nvme_cq_head_db, cq_head_db);
            }
            Ok(())
        } else { Err(NVMeNotAvailableError {}) }
    }

    /// Returns tuple with PCIe addresses of submission queue (first element)
    /// and completion queue (second element)
    pub fn get_queue_base_addr(&self) -> Result<(u64, u64)> {
        if self.available {
            let sq_base = self.queue_base_addr;
            let cq_base = self.queue_base_addr + 0x1000;
            Ok((sq_base, cq_base))
        } else { Err(NVMeNotAvailableError {}) }
    }

    /// Set namespace ID to be used for data transfers
    pub fn set_nvme_namespace_id(&self, namespace_id: u64) -> Result<()> {
        if self.available {
            let csr_memory = self.memory.lock()?;
            unsafe {
                let ptr: *mut NvmeStreamerIP = csr_memory
                    .as_ptr()
                    .offset(self.nvme_offset as isize) as _;
                write_volatile(&mut (*ptr).nsid, namespace_id);
            }
            Ok(())
        } else { Err(NVMeNotAvailableError {}) }
    }

    /// (un)set enable flag of NVMe Streamer IP
    fn set_enable(&mut self, enable: bool) -> Result<()> {
        if self.available {
            if !self.enabled && enable || self.enabled && !enable {
                let en_u64 = if enable { 1 } else { 0 };
                let csr_memory = self.memory.lock()?;
                unsafe {
                    let ptr: *mut NvmeStreamerIP = csr_memory
                        .as_ptr()
                        .offset(self.nvme_offset as isize) as _;
                    write_volatile(&mut (*ptr).enabled, en_u64);
                }
                self.enabled = enable;
            }
            Ok(())
        } else { Err(NVMeNotAvailableError {}) }
    }

    /// enable NVMe Streamer IP and plugin
    pub fn enable(&mut self) -> Result<()> {
        trace!("Enabling NVMe plugin");
        self.set_enable(true)
    }

    /// disable NVMe Streamer IP and plugin
    pub fn disable(&mut self) -> Result<()> {
        trace!("Disabling NVMe plugin");
        self.set_enable(false)
    }

    /// Returns whether NVMe Streamer IP and plugin is enabled
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }
}

declare_plugin!(NvmePlugin);

#[no_mangle]
/// Returns pointer to the NVMe plugin on the current device
///
/// CAUTION: Pointer may become invalid if corresponding device
/// is out-of-scope and/or is destroyed
pub unsafe extern "C" fn tapasco_get_nvme_plugin(dev: *mut Device) -> *mut NvmePlugin {
    if dev.is_null() {
        warn!("Null pointer passed to tapasco_get_nvme_plugin() as device");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return std::ptr::null_mut();
    }
    let dev = &mut *dev;
    match dev.get_plugin_mut::<NvmePlugin>() {
        Ok(plugin) => plugin as *mut NvmePlugin,
        Err(e) => {
            warn!("Nvme plugin not found");
            update_last_error(crate::ffi::Error::DeviceError { source: e});
            std::ptr::null_mut()
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_is_available(
    plugin: *mut NvmePlugin,
    available: *mut bool
) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_is_available() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    if available.is_null() {
        warn!("Null pointer passed to tapasco_nvme_is_available() as available flag");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &*plugin;
    *available = plugin_ptr.is_available();
    0
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_set_nvme_pcie_addr(
    plugin: *mut NvmePlugin,
    addr: u64
) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_set_nvme_pcie_addr() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &mut *plugin;
    if let Err(e) = plugin_ptr.set_nvme_pcie_addr(addr) {
        warn!("Failed to set NVMe PCIe address");
        update_last_error( crate::ffi::Error::FFIPluginError {
            source: crate::plugins::plugin::Error::from(e)
        });
        return -1;
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_set_namespace_id(
    plugin: *mut NvmePlugin,
    namespace_id: u64
) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_set_namespace_id() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &mut *plugin;
    if let Err(e) = plugin_ptr.set_nvme_namespace_id(namespace_id) {
        warn!("Failed to set namespace ID");
        update_last_error( crate::ffi::Error::FFIPluginError {
            source: crate::plugins::plugin::Error::from(e)
        });
        return -1;
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_get_queue_base_addr(
    plugin: *mut NvmePlugin,
    sq_addr: *mut u64,
    cq_addr: *mut u64,
) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_get_queue_base_addr() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    if sq_addr.is_null() || cq_addr.is_null() {
        warn!("Null pointer passed to tapasco_get_queue_base_addr() as address");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &*plugin;
    match plugin_ptr.get_queue_base_addr() {
        Ok((sq, cq)) => {
            *sq_addr = sq;
            *cq_addr = cq;
            0
        },
        Err(e) => {
            warn!("Failed to set NVMe PCIe address");
            update_last_error(crate::ffi::Error::FFIPluginError {
                source: crate::plugins::plugin::Error::from(e)
            });
            -1
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_is_enabled(
    plugin: *mut NvmePlugin,
    enabled: *mut bool
) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_is_enabeld() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    if enabled.is_null() {
        warn!("Null pointer passed to tapasco_nvme_is_enabled() as enabled flag");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &*plugin;
    *enabled = plugin_ptr.is_enabled();
    0
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_enable(plugin: *mut NvmePlugin) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_is_available() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &mut *plugin;
    if let Err(e) = plugin_ptr.enable() {
        warn!("Failed to enable NVMe plugin");
        update_last_error(crate::ffi::Error::FFIPluginError {
            source: crate::plugins::plugin::Error::from(e)
        });
        return -1;
    }
    0
}

#[no_mangle]
pub unsafe extern "C" fn tapasco_nvme_disable(plugin: *mut NvmePlugin) -> i32 {
    if plugin.is_null() {
        warn!("Null pointer passed to tapasco_nvme_is_available() as plugin");
        update_last_error(crate::ffi::Error::NullPointerTLKM {});
        return -1;
    }
    let plugin_ptr = &mut *plugin;
    if let Err(e) = plugin_ptr.disable() {
        warn!("Failed to disable NVMe plugin");
        update_last_error(crate::ffi::Error::FFIPluginError {
            source: crate::plugins::plugin::Error::from(e)
        });
        return -1;
    }
    0
}