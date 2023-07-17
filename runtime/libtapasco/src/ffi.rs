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
use crate::device::DataTransferLocal;
use crate::device::DataTransferPrealloc;
use crate::device::Device;
use crate::device::DeviceAddress;
use crate::device::OffchipMemory;
use crate::device::PEParameter;
use crate::job::Job;
use crate::pe::PEId;
use crate::tlkm::tlkm_access;
use crate::tlkm::DeviceId;
use crate::tlkm::DeviceInfo;
use crate::tlkm::TLKM;
use core::cell::RefCell;
use libc::c_char;
use libc::c_int;
use snafu::ResultExt;
use std::collections::HashMap;
use std::ffi::CStr;
use std::ptr;
use std::slice;
use std::sync::Arc;
use std::u64;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Error during TLKM operation: {}", source))]
    TLKMError { source: crate::tlkm::Error },

    #[snafu(display("Error during Device operation: {}", source))]
    DeviceError { source: crate::device::Error },

    #[snafu(display("Error during DMA operation: {}", source))]
    DMAError { source: crate::dma::Error },

    #[snafu(display("Error during Allocator operation: {}", source))]
    AllocatorError { source: crate::allocator::Error },

    #[snafu(display("Error during Job operation: {}", source))]
    JobError { source: crate::job::Error },

    #[snafu(display("Got Null pointer as TLKM argument."))]
    NullPointerTLKM {},

    #[snafu(display("Version string to short, need {} bytes.", len))]
    VersionStringToShort { len: usize },

    #[snafu(display("Not enough space for device infor, need {} entries.", len))]
    DeviceInfoToShort { len: usize },

    #[snafu(display("Failed to retrieve default memory: {}", source))]
    RetrieveDefaultMemory { source: crate::device::Error },
}

//////////////////////
// Taken from https://michael-f-bryan.github.io/rust-ffi-guide/errors/return_types.html
thread_local! {
    static LAST_ERROR: RefCell<Option<Box<Error>>> = RefCell::new(None);
}

pub fn take_last_error() -> Option<Box<Error>> {
    LAST_ERROR.with(|prev| prev.borrow_mut().take())
}

/// Update the most recent error, clearing whatever may have been there before.
pub fn update_last_error(err: Error) {
    error!("Setting LAST_ERROR: {}", err);

    LAST_ERROR.with(|prev| {
        *prev.borrow_mut() = Some(Box::new(err));
    });
}

/// Calculate the number of bytes in the last error's error message **not**
/// including any trailing `null` characters.
#[no_mangle]
pub extern "C" fn tapasco_last_error_length() -> c_int {
    LAST_ERROR.with(|prev| match *prev.borrow() {
        Some(ref err) => err.to_string().len() as c_int + 1,
        None => 0,
    })
}

/// Write the most recent error message into a caller-provided buffer as a UTF-8
/// string, returning the number of bytes written.
///
/// # Note
///
/// This writes a **UTF-8** string into the buffer. Windows users may need to
/// convert it to a UTF-16 "unicode" afterwards.
///
/// If there are no recent errors then this returns `0` (because we wrote 0
/// bytes). `-1` is returned if there are any errors, for example when passed a
/// null pointer or a buffer of insufficient size.
///
/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_last_error_message(buffer: *mut c_char, length: c_int) -> c_int {
    if buffer.is_null() {
        warn!("Null pointer passed into last_error_message() as the buffer");
        return -1;
    }

    let last_error = match take_last_error() {
        Some(err) => err,
        None => return 0,
    };

    let error_message = last_error.to_string();

    let buffer = slice::from_raw_parts_mut(buffer as *mut u8, length as usize);

    if error_message.len() >= buffer.len() {
        warn!("Buffer provided for writing the last error message is too small.");
        warn!(
            "Expected at least {} bytes but got {}",
            error_message.len() + 1,
            buffer.len()
        );
        return -1;
    }

    ptr::copy_nonoverlapping(
        error_message.as_ptr(),
        buffer.as_mut_ptr(),
        error_message.len(),
    );

    // Add a trailing null so people using the string as a `char *` don't
    // accidentally read into garbage.
    buffer[error_message.len()] = 0;

    error_message.len() as c_int
}

//////////////////////

// Initializes the logging system so it responds to the RUST_LOG environment variable
#[no_mangle]
pub extern "C" fn tapasco_init_logging() {
    match env_logger::try_init() {
        Ok(_) => trace!("Logger initialized."),
        Err(_) => trace!("Logger already initialized."),
    }
}

//////////////
// START TLKM
//////////////

// Generates a new driver access which can be used to query verison information and devices
#[no_mangle]
pub extern "C" fn tapasco_tlkm_new() -> *mut TLKM {
    match TLKM::new().context(TLKMSnafu) {
        Ok(x) => std::boxed::Box::<TLKM>::into_raw(Box::new(x)),
        Err(e) => {
            update_last_error(e);
            ptr::null_mut()
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_destroy(t: *mut TLKM) {
    let _b: Box<TLKM> = Box::from_raw(t);
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_version(t: *const TLKM, vers: *mut c_char, len: usize) -> i32 {
    if t.is_null() {
        warn!("Null pointer passed into last_error_message() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &*t;
    match tl.version().context(TLKMSnafu) {
        Ok(x) => {
            let is = slice::from_raw_parts_mut(vers as *mut u8, len);
            if len < x.len() {
                update_last_error(Error::VersionStringToShort { len: x.len() });
                return -1;
            }
            is[..x.len()].copy_from_slice(x.as_bytes());
            is[len - 1] = 0;
            0
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_device_len(t: *const TLKM) -> isize {
    if t.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_device_len() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &*t;
    match tl.device_enum_len().context(TLKMSnafu) {
        Ok(x) => {
            x as isize
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_devices(t: *const TLKM, di: *mut DeviceInfo, len: usize) -> isize {
    if t.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_devices() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &*t;
    match tl.device_enum_info().context(TLKMSnafu) {
        Ok(x) => {
            if len < x.len() {
                update_last_error(Error::DeviceInfoToShort { len });
                return -1;
            }
            let is = slice::from_raw_parts_mut(di, len);
            is[..x.len()].copy_from_slice(&x);

            0
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_devices_destroy(di: *mut DeviceInfo, len: usize) -> isize {
    if di.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_devices_destroy() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }
    let is = slice::from_raw_parts_mut(di, len);
    for i in is.iter_mut() {
        let p = i.name();
        let _s = std::ffi::CString::from_raw(p as *mut c_char);
    }
    0
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_device_alloc(t: *const TLKM, id: DeviceId) -> *mut Device {
    if t.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_devices() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &*t;
    match tl.device_alloc(id, &HashMap::new()).context(TLKMSnafu) {
        Ok(x) => std::boxed::Box::<Device>::into_raw(Box::new(x)),
        Err(e) => {
            update_last_error(e);
            ptr::null_mut()
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_tlkm_device_destroy(t: *mut Device) {
    let _b: Box<Device> = Box::from_raw(t);
}

//////////////
// END TLKM
//////////////

/////////////////
// Job Creation
/////////////////

type JobList = Vec<PEParameter>;

#[no_mangle]
pub extern "C" fn tapasco_job_param_new() -> *mut JobList {
    Box::into_raw(Box::new(Vec::new()))
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_destroy(t: *mut JobList) {
    let _b: Box<JobList> = Box::from_raw(t);
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_single32(param: u32, list: *mut JobList) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_single32() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &mut *list;
    tl.push(PEParameter::Single32(param));
    list
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_single64(param: u64, list: *mut JobList) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_single32() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &mut *list;
    tl.push(PEParameter::Single64(param));
    list
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_deviceaddress(
    param: DeviceAddress,
    list: *mut JobList,
) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_single32() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &mut *list;
    tl.push(PEParameter::DeviceAddress(param));
    list
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_alloc(
    dev: *mut Device,
    ptr: *mut u8,
    bytes: usize,
    to_device: bool,
    from_device: bool,
    free: bool,
    uses_fixed: bool,
    fixed: u64,
    list: *mut JobList,
) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_alloc() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    if dev.is_null() {
        warn!("Null pointer passed into tapasco_job_param_alloc() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let d = &mut *dev;

    let mem = match d.default_memory().context(RetrieveDefaultMemorySnafu) {
        Ok(x) => x,
        Err(e) => {
            warn!("Failed to retrieve default memory from device.");
            update_last_error(e);
            return ptr::null_mut();
        }
    };

    let v = Box::from_raw(slice::from_raw_parts_mut(ptr, bytes));

    let f = if uses_fixed { Some(fixed) } else { None };

    let tl = &mut *list;
    tl.push(PEParameter::DataTransferAlloc(DataTransferAlloc {
        data: v,
        from_device,
        to_device,
        free,
        memory: mem,
        fixed: f,
    }));
    list
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_local(
    ptr: *mut u8,
    bytes: usize,
    to_device: bool,
    from_device: bool,
    free: bool,
    uses_fixed: bool,
    fixed: u64,
    list: *mut JobList,
) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_alloc() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let v = Box::from_raw(slice::from_raw_parts_mut(ptr, bytes));

    let f = if uses_fixed { Some(fixed) } else { None };

    let tl = &mut *list;
    tl.push(PEParameter::DataTransferLocal(DataTransferLocal {
        data: v,
        from_device,
        to_device,
        free,
        fixed: f,
    }));
    list
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_prealloc(
    dev: *mut Device,
    ptr: *mut u8,
    addr: DeviceAddress,
    bytes: usize,
    to_device: bool,
    from_device: bool,
    free: bool,
    list: *mut JobList,
) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_alloc() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    if dev.is_null() {
        warn!("Null pointer passed into tapasco_job_param_alloc() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let d = &mut *dev;

    let mem = match d.default_memory().context(RetrieveDefaultMemorySnafu) {
        Ok(x) => x,
        Err(e) => {
            warn!("Failed to retrieve default memory from device.");
            update_last_error(e);
            return ptr::null_mut();
        }
    };

    let v = Box::from_raw(slice::from_raw_parts_mut(ptr, bytes));

    let tl = &mut *list;
    tl.push(PEParameter::DataTransferPrealloc(DataTransferPrealloc {
        data: v,
        device_address: addr,
        from_device,
        to_device,
        free,
        memory: mem,
    }));
    list
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_param_virtualaddress(addr: *const u8, list: *mut JobList) -> *mut JobList {
    if list.is_null() {
        warn!("Null pointer passed into tapasco_job_param_single32() as the list");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &mut *list;
    tl.push(PEParameter::VirtualAddress(addr));
    list
}

/////////////////
// Handle Device Access
/////////////////

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_device_access(dev: *mut Device, access: tlkm_access) -> isize {
    if dev.is_null() {
        warn!("Null pointer passed into tapasco_device_access() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &mut *dev;
    match tl.change_access(access).context(DeviceSnafu) {
        Ok(_) => 0,
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_device_num_pes(dev: *mut Device, id: PEId) -> isize {
    if dev.is_null() {
        warn!("Null pointer passed into tapasco_device_num_pes() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &mut *dev;
    tl.num_pes(id) as isize
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_device_get_pe_id(dev: *mut Device, name: *const c_char) -> PEId {
    if dev.is_null() {
        warn!("Null pointer passed into tapasco_device_get_pe_id() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return PEId::MAX;
    }

    if name.is_null() {
        warn!("Null pointer passed into tapasco_device_get_pe_id() as the name");
        update_last_error(Error::NullPointerTLKM {});
        return PEId::MAX;
    }

    let s = CStr::from_ptr(name);
    let name_r = s.to_str().unwrap();

    let tl = &mut *dev;

    match tl.get_pe_id(name_r).context(DeviceSnafu) {
        Ok(x) => x,
        Err(e) => {
            update_last_error(e);
            PEId::MAX
        }
    }
}

/////////////////
// Job Starting
/////////////////

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_device_acquire_pe(dev: *mut Device, id: PEId) -> *mut Job {
    if dev.is_null() {
        warn!("Null pointer passed into tapasco_device_acquire_pe() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &mut *dev;
    match tl.acquire_pe(id).context(DeviceSnafu) {
        Ok(x) => std::boxed::Box::<Job>::into_raw(Box::new(x)),
        Err(e) => {
            update_last_error(e);
            ptr::null_mut()
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_start(job: *mut Job, params: *mut *mut JobList) -> isize {
    if job.is_null() {
        warn!("Null pointer passed into tapasco_job_start() as the job");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    if params.is_null() {
        warn!("Null pointer passed into tapasco_job_start() as the parameters");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let jl_ptr: *mut JobList = *params;

    if jl_ptr.is_null() {
        warn!("Null pointer passed into tapasco_job_start() as the parameters");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let jl = Box::from_raw(jl_ptr);
    *params = ptr::null_mut();

    // Move out of Box
    let jl = *jl;

    let tl = &mut *job;
    match tl.start(jl).context(JobSnafu) {
        Ok(x) => {
            for d in x {
                // Make sure Rust doesn't release the memory received from C
                let _p = std::boxed::Box::<[u8]>::into_raw(d);
            }
            0
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
// The rust verison of this function returns an array of vectors that contain the returned vectors
// The C and C++ side, however, supply "unsafe" pointers and expect the data to appear there after
// the job has been released.
// Hence, the function currently does not return the result list but makes sure that the data is at the
// correct location.
#[no_mangle]
pub unsafe extern "C" fn tapasco_job_release(
    job: *mut Job,
    return_value: *mut u64,
    release: bool,
) -> isize {
    if job.is_null() {
        warn!("Null pointer passed into tapasco_job_release() as the job");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &mut *job;
    match tl
        .release(release, !return_value.is_null())
        .context(JobSnafu)
    {
        Ok(x) => {
            for d in x.1 {
                // Make sure Rust doesn't release the memory received from C
                let _p = std::boxed::Box::<[u8]>::into_raw(d);
            }
            if !return_value.is_null() {
                *return_value = x.0;
            }
            0
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

///////////////////
// Memory handling
///////////////////

type TapascoOffchipMemory = Arc<OffchipMemory>;

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_get_default_memory(dev: *mut Device) -> *mut TapascoOffchipMemory {
    if dev.is_null() {
        warn!("Null pointer passed into tapasco_get_default_memory() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = &mut *dev;
    match tl.default_memory().context(DeviceSnafu) {
        Ok(x) => Box::into_raw(Box::new(x)),
        Err(e) => {
            update_last_error(e);
            ptr::null_mut()
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_memory_destroy(t: *mut TapascoOffchipMemory) {
    let _b: Box<TapascoOffchipMemory> = Box::from_raw(t);
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_memory_copy_to(
    mem: *mut TapascoOffchipMemory,
    data: *const u8,
    addr: DeviceAddress,
    len: usize,
) -> isize {
    if mem.is_null() {
        warn!("Null pointer passed into tapasco_memory_copy_to() as the memory");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let s = slice::from_raw_parts(data, len);

    let tl = &mut *mem;
    match tl.dma().copy_to(s, addr).context(DMASnafu) {
        Ok(_x) => 0,
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_memory_copy_from(
    mem: *mut TapascoOffchipMemory,
    addr: DeviceAddress,
    data: *mut u8,
    len: usize,
) -> isize {
    if mem.is_null() {
        warn!("Null pointer passed into tapasco_memory_copy_to() as the memory");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let s = slice::from_raw_parts_mut(data, len);

    let tl = &mut *mem;
    match tl.dma().copy_from(addr, s).context(DMASnafu) {
        Ok(_x) => 0,
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_nvMulator(
    mem: *mut TapascoOffchipMemory,
    read_delay: usize,
    write_delay: usize,
    mode: usize,
) -> isize {

    let tl = &mut *mem;
    tl.dma().nvMulator(read_delay.try_into().unwrap(), write_delay.try_into().unwrap(), mode.try_into().unwrap()).context(DMASnafu);

    return 10;
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_memory_allocate(
    mem: *mut TapascoOffchipMemory,
    len: usize,
) -> DeviceAddress {
    if mem.is_null() {
        warn!("Null pointer passed into tapasco_memory_copy_to() as the memory");
        update_last_error(Error::NullPointerTLKM {});
        return DeviceAddress::MAX;
    }

    let tl = &mut *mem;
    match tl
        .allocator()
        .lock()
        .unwrap()
        .allocate(len as u64, None)
        .context(AllocatorSnafu)
    {
        Ok(x) => x,
        Err(e) => {
            update_last_error(e);
            DeviceAddress::MAX
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_memory_allocate_fixed(
    mem: *mut TapascoOffchipMemory,
    len: usize,
    offset: usize,
) -> DeviceAddress {
    if mem.is_null() {
        warn!("Null pointer passed into tapasco_memory_copy_to() as the memory");
        update_last_error(Error::NullPointerTLKM {});
        return DeviceAddress::MAX;
    }

    let tl = &mut *mem;
    match tl
        .allocator()
        .lock()
        .unwrap()
        .allocate_fixed(len as u64, offset as u64)
        .context(AllocatorSnafu)
    {
        Ok(x) => x,
        Err(e) => {
            update_last_error(e);
            DeviceAddress::MAX
        }
    }
}

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_memory_free(
    mem: *mut TapascoOffchipMemory,
    addr: DeviceAddress,
) -> isize {
    if mem.is_null() {
        warn!("Null pointer passed into tapasco_memory_copy_to() as the memory");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = &mut *mem;
    match tl
        .allocator()
        .lock()
        .unwrap()
        .free(addr)
        .context(AllocatorSnafu)
    {
        Ok(_x) => 0,
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

///////////////////////////////////
// Status Information
///////////////////////////////////

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_device_design_frequency(dev: *mut Device) -> f32 {
    if dev.is_null() {
        warn!("Null pointer passed into tapasco_device_design_frequency() as the device");
        update_last_error(Error::NullPointerTLKM {});
        return -1.0;
    }

    let tl = &mut *dev;
    match tl.design_frequency_mhz().context(DeviceSnafu) {
        Ok(x) => x,
        Err(e) => {
            update_last_error(e);
            -1.0
        }
    }
}

const VERSION: &str = env!("CARGO_PKG_VERSION");

/// # Safety
/// TODO
#[no_mangle]
pub unsafe extern "C" fn tapasco_version(buffer: *mut c_char, length: usize) -> usize {
    let buffer = slice::from_raw_parts_mut(buffer as *mut u8, length);

    if VERSION.len() >= buffer.len() {
        warn!("Buffer provided for writing the version is too small.");
        warn!(
            "Expected at least {} bytes but got {}",
            VERSION.len() + 1,
            buffer.len()
        );
        return 0;
    }

    println!("Version: {}", VERSION);

    ptr::copy_nonoverlapping(VERSION.as_ptr(), buffer.as_mut_ptr(), VERSION.len());

    buffer[VERSION.len()] = 0;

    VERSION.len()
}

#[no_mangle]
// TODO: either remove extern C or wait for const extern fn to be stabilized:
//pub const fn tapasco_version_len() -> usize {
//pub const extern "C" fn tapasco_version_len() -> usize {
pub extern "C" fn tapasco_version_len() -> usize {
    VERSION.len() + 1
}
