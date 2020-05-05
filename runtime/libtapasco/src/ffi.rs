extern crate env_logger;

use crate::device::Device;
use crate::tlkm::DeviceId;
use crate::tlkm::DeviceInfo;
use crate::tlkm::TLKM;
use core::cell::RefCell;
use libc::c_char;
use libc::c_int;
use snafu::ResultExt;
use std::ptr;
use std::slice;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Error during TLKM operation: {}", source))]
    TLKMError { source: crate::tlkm::Error },

    #[snafu(display("Got Null pointer as TLKM argument."))]
    NullPointerTLKM {},

    #[snafu(display("Version string to short, need {} bytes.", len))]
    VersionStringToShort { len: usize },

    #[snafu(display("Not enough space for device infor, need {} entries.", len))]
    DeviceInfoToShort { len: usize },
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

#[no_mangle]
pub extern "C" fn tapasco_init_logging() {
    env_logger::init();
}

//////////////
// START TLKM
//////////////

#[no_mangle]
pub extern "C" fn tapasco_tlkm_new() -> *mut TLKM {
    match TLKM::new().context(TLKMError) {
        Ok(x) => std::boxed::Box::<TLKM>::into_raw(Box::new(x)),
        Err(e) => {
            update_last_error(e);
            ptr::null_mut()
        }
    }
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_destroy(t: *mut TLKM) {
    unsafe {
        let _b: Box<TLKM> = Box::from_raw(t);
    }
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_version(t: *const TLKM, vers: *mut c_char, len: usize) -> i32 {
    if t.is_null() {
        warn!("Null pointer passed into last_error_message() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = unsafe { &*t };
    match tl.version().context(TLKMError) {
        Ok(x) => {
            let is = unsafe { slice::from_raw_parts_mut(vers as *mut u8, len) };
            if len < x.len() {
                update_last_error(Error::VersionStringToShort { len: x.len() });
                return -1;
            }
            is[..x.len()].copy_from_slice(x.as_bytes());
            is[len - 1] = 0;
            return 0;
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_device_len(t: *const TLKM) -> isize {
    if t.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_device_len() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = unsafe { &*t };
    match tl.device_enum_len().context(TLKMError) {
        Ok(x) => {
            return x as isize;
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_devices(t: *const TLKM, di: *mut DeviceInfo, len: usize) -> isize {
    if t.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_devices() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }

    let tl = unsafe { &*t };
    match tl.device_enum_info().context(TLKMError) {
        Ok(x) => {
            if len < x.len() {
                update_last_error(Error::DeviceInfoToShort { len: len });
                return -1;
            }
            let is = unsafe { slice::from_raw_parts_mut(di, len) };
            is[..x.len()].copy_from_slice(&x);

            return 0;
        }
        Err(e) => {
            update_last_error(e);
            -1
        }
    }
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_devices_destroy(di: *mut DeviceInfo, len: usize) -> isize {
    if di.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_devices_destroy() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return -1;
    }
    let is = unsafe { slice::from_raw_parts_mut(di, len) };
    for i in is.into_iter() {
        let p = i.name();
        let _s = unsafe { std::ffi::CString::from_raw(p as *mut c_char) };
    }
    return 0;
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_device_alloc(t: *const TLKM, id: DeviceId) -> *mut Device {
    if t.is_null() {
        warn!("Null pointer passed into tapasco_tlkm_devices() as the buffer");
        update_last_error(Error::NullPointerTLKM {});
        return ptr::null_mut();
    }

    let tl = unsafe { &*t };
    match tl.device_alloc(id).context(TLKMError) {
        Ok(x) => std::boxed::Box::<Device>::into_raw(Box::new(x)),
        Err(e) => {
            update_last_error(e);
            return ptr::null_mut();
        }
    }
}

#[no_mangle]
pub extern "C" fn tapasco_tlkm_device_destroy(t: *mut Device) {
    unsafe {
        let _b: Box<Device> = Box::from_raw(t);
    }
}

//////////////
// END TLKM
//////////////
