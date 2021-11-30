extern crate snafu;
extern crate tapasco;
#[macro_use]
extern crate log;

use snafu::{ErrorCompat, ResultExt, Snafu};
use std::collections::HashMap;
use std::sync::{Arc};
use tapasco::device::{DataTransferAlloc, Device, PEParameter};
use tapasco::pe::PEId;
use tapasco::tlkm::*;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Failed to initialize TLKM object: {}", source))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display("Failed to decode TLKM device: {}", source))]
    DeviceInit { source: tapasco::device::Error },

    #[snafu(display("Error while executing Job: {}", source))]
    JobError { source: tapasco::job::Error },
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

const RUNS: i32 = 25;
const ARRAY_SIZE: usize = 256;
const ARRAY_SIZE_BYTES: usize = 256 * 4;
const ARRAY_SUM_RESULT: u64 = (ARRAY_SIZE as u64 - 1) * (ARRAY_SIZE as u64) / 2;

fn run_arrayinit(device: Arc<Device>, arrayinit_id: PEId) -> Result<()> {
    info!("Run arrayinit using On-Demand Page Migrations (ODPMs)");
    let mut failed_runs = 0;
    for run in 0..RUNS {
        // we create an vector with uninitialized memory to avoid copies to device memory
        // (has only an effect for larger arrays over multiple pages)
        let mut v = Vec::<u8>::with_capacity(ARRAY_SIZE_BYTES);
        unsafe { v.set_len(ARRAY_SIZE_BYTES); }
        let v_boxed = v.into_boxed_slice();

        // When using ODPMs we just pass the array base address
        // -> the migration will be triggered automatically by device page faults
        // -> wrapping the pointer in the VirtualAddress argument type provides a
        //    check whether the loaded bitstream actually supports SVM
        let arg_vec = vec![PEParameter::VirtualAddress(v_boxed.as_ptr())];
        let mut pe = device.acquire_pe(arrayinit_id).context(DeviceInit {})?;
        pe.start(arg_vec).context(JobError {})?;
        info!("PE running");
        let _out_args = pe.release(true, false).context(JobError {})?;

        // check array
        let p = v_boxed.as_ptr() as *mut i32;
        let mut errs = 0;
        for i in 0..ARRAY_SIZE {
            unsafe {
                if *p.offset(i as isize) != i as i32 {
                    errs += 1;
                }
            }
        }
        if errs != 0 {
            failed_runs += 1;
            warn!("RUN {} NOT OK", run);
        } else {
            info!("RUN {} OK", run);
        }
    }

    info!("Run arrayinit using User-Managed Page Migrations (UMPMs)");
    for run in 0..RUNS {
        // we create an vector with uninitialized memory to avoid copies to device memory
        let mut v = Vec::<u8>::with_capacity(ARRAY_SIZE_BYTES);
        unsafe { v.set_len(ARRAY_SIZE_BYTES); }
        let v_boxed = v.into_boxed_slice();

        // To use UMPMs we pass the pointer as DataTransferAlloc parameter
        // -> Note that we also set a migration to device since the array is allocated in
        //    host memory and must be migrated to device memory as well
        let arg_vec = vec![PEParameter::DataTransferAlloc(DataTransferAlloc {
            data: v_boxed,
            from_device: true,
            to_device: true,
            free: true,         // this parameter has no influence when SVM is active
            memory: device.default_memory().context(DeviceInit {})?, // other memories currently not supported
            fixed: None,
        })];
        let mut pe = device.acquire_pe(arrayinit_id).context(DeviceInit {})?;
        pe.start(arg_vec).context(JobError {})?;

        let (_ret, out_vecs) = pe.release(true, false).context(JobError {})?;

        // check array
        let p = out_vecs[0].as_ptr() as *mut i32;
        let mut errs = 0;
        for i in 0..ARRAY_SIZE {
            unsafe {
                if *p.offset(i as isize) != i as i32 {
                    errs += 1;
                }
            }
        }
        if errs != 0 {
            failed_runs += 1;
            warn!("RUN {} NOT OK", run);
        } else {
            info!("RUN {} OK", run);
        }
    }

    if failed_runs != 0 {
        error!("Errors occurred while running arrayinit example");
    }
    Ok(())
}

fn run_arraysum(device: Arc<Device>, arraysum_id: PEId) -> Result<()> {
    info!("Run arraysum using On-Demand Page Migrations (ODPMs)");
    let mut failed_runs = 0;
    for run in 0..RUNS {
        // create and initialize input array
        let v = vec![0u8; ARRAY_SIZE_BYTES];
        let v_boxed = v.into_boxed_slice();
        let p = v_boxed.as_ptr() as *mut i32;
        unsafe {
            for i in 0..ARRAY_SIZE {
                *p.offset(i as isize) = i as i32;
            }
        }

        // When using ODPMs we just pass the array base address as Single64 argument
        // -> the migration will be triggered automatically by device page faults
        // -> wrapping the pointer in the VirtualAddress argument type provides a
        //    check whether the loaded bitstream actually supports SVM
        let arg_vec = vec![PEParameter::VirtualAddress(v_boxed.as_ptr())];
        let mut pe = device.acquire_pe(arraysum_id).context(DeviceInit {})?;
        pe.start(arg_vec).context(JobError {})?;
        let (ret, _out_vecs) = pe.release(true, true).context(JobError {})?;
        // check result
        if ret != ARRAY_SUM_RESULT {
            failed_runs += 1;
            warn!("RUN {} NOT OK", run);
        } else {
            info!("RUN {} OK", run);
        }
    }

    info!("Run arraysum using User-Managed Page Migrations (UMPMs)");
    for run in 0..RUNS {
        // create and initialize input array
        let v = vec![0u8; ARRAY_SIZE_BYTES];
        let v_boxed = v.into_boxed_slice();
        let p = v_boxed.as_ptr() as *mut i32;
        unsafe {
            for i in 0..ARRAY_SIZE {
                *p.offset(i as isize) = i as i32;
            }
        }

        // To use UMPMs we pass the pointer as DataTransferAlloc parameter
        // -> Note that we do not set a migration from device since the array can be freed
        //    directly in device memory
        let arg_vec = vec![PEParameter::DataTransferAlloc(DataTransferAlloc {
            data: v_boxed,
            from_device: false,
            to_device: true,
            free: true,         // this parameter has no influence when SVM is active
            memory: device.default_memory().context(DeviceInit {})?, // other memories currently not supported
            fixed: None,
        })];
        let mut pe = device.acquire_pe(arraysum_id).context(DeviceInit {})?;
        pe.start(arg_vec).context(JobError {})?;

        let (ret, _out_vecs) = pe.release(true, true).context(JobError {})?;

        // check result
        if ret != ARRAY_SUM_RESULT {
            failed_runs += 1;
            warn!("RUN {} NOT OK", run);
        } else {
            info!("RUN {} OK", run);
        }
    }

    if failed_runs != 0 {
        error!("Errors occurred while running arraysum example");
    }
    Ok(())
}

fn run_arrayupdate(device: Arc<Device>, arrayupdate_id: PEId) -> Result<()> {
    info!("Run arrayupdate using On-Demand Page Migrations (ODPMs)");
    let mut failed_runs = 0;
    for run in 0..RUNS {
        // create and initialize input array
        let v = vec![0u8; ARRAY_SIZE_BYTES];
        let v_boxed = v.into_boxed_slice();
        let p = v_boxed.as_ptr() as *mut i32;
        unsafe {
            for i in 0..ARRAY_SIZE {
                *p.offset(i as isize) = i as i32;
            }
        }

        // When using ODPMs we just pass the array base address
        // -> the migration will be triggered automatically by device page faults
        // -> wrapping the pointer in the VirtualAddress argument type provides a
        //    check whether the loaded bitstream actually supports SVM
        let arg_vec = vec![PEParameter::VirtualAddress(v_boxed.as_ptr())];
        let mut pe = device.acquire_pe(arrayupdate_id).context(DeviceInit {})?;
        pe.start(arg_vec).context(JobError {})?;

        let _out_args = pe.release(true, false).context(JobError {})?;

        // check array
        let p = v_boxed.as_ptr() as *mut i32;
        let mut errs = 0;
        for i in 0..ARRAY_SIZE {
            unsafe {
                if *p.offset(i as isize) != i as i32 + 42 {
                    errs += 1;
                }
            }
        }
        if errs != 0 {
            failed_runs += 1;
            warn!("RUN {} NOT OK", run);
        } else {
            info!("RUN {} OK", run);
        }
    }

    info!("Run arrayupdate using User-Managed Page Migrations (UMPMs)");
    for run in 0..RUNS {
        // create and initialize input array
        let v = vec![0u8; ARRAY_SIZE_BYTES];
        let v_boxed = v.into_boxed_slice();
        let p = v_boxed.as_ptr() as *mut i32;
        unsafe {
            for i in 0..ARRAY_SIZE {
                *p.offset(i as isize) = i as i32;
            }
        }

        // To use UMPMs we pass the pointer as DataTransferAlloc parameter
        let arg_vec = vec![PEParameter::DataTransferAlloc(DataTransferAlloc {
            data: v_boxed,
            from_device: true,
            to_device: true,
            free: true,         // this parameter has no influence when SVM is active
            memory: device.default_memory().context(DeviceInit {})?, // other memories currently not supported
            fixed: None,
        })];
        let mut pe = device.acquire_pe(arrayupdate_id).context(DeviceInit {})?;
        pe.start(arg_vec).context(JobError {})?;

        let (_ret, out_vecs) = pe.release(true, false).context(JobError {})?;

        // check array
        let p = out_vecs[0].as_ptr() as *mut i32;
        let mut errs = 0;
        for i in 0..ARRAY_SIZE {
            unsafe {
                if *p.offset(i as isize) != i as i32 + 42 {
                    errs += 1;
                }
            }
        }
        if errs != 0 {
            failed_runs += 1;
            warn!("RUN {} NOT OK", run);
        } else {
            info!("RUN {} OK", run);
        }
    }

    if failed_runs != 0 {
        error!("Errors occurred while running arrayupdate example");
    }
    Ok(())
}

fn run_pipeline(device: Arc<Device>, arrayinit_id: PEId, arraysum_id: PEId, arrayupdate_id: PEId) -> Result<()> {
    info!("Run pipeline example...");

    // we create an vector with uninitialized memory to avoid unnecessary copies to device memory
    // (has only an effect for larger arrays over multiple pages)
    let mut v = Vec::<u8>::with_capacity(ARRAY_SIZE_BYTES);
    unsafe { v.set_len(ARRAY_SIZE_BYTES); }
    let v_boxed = v.into_boxed_slice();

    // for arrayinit we use a UMPM to device, however we do not migrate it back to host
    // -> nevertheless, this buffer will be returned by 'pe.release()' so that we can regain ownership
    let arrayinit_args = vec![PEParameter::DataTransferAlloc(DataTransferAlloc {
        data: v_boxed,
        from_device: false,
        to_device: true,
        free: true,         // this parameter has no influence when SVM is active
        memory: device.default_memory().context(DeviceInit {})?, // other memories currently not supported
        fixed: None,
    })];
    let mut arrayinit_pe = device.acquire_pe(arrayinit_id).context(DeviceInit {})?;
    arrayinit_pe.start(arrayinit_args).context(JobError {})?;

    // do not forget to regain ownership of our array (returned in out_vecs vector although we did not set 'from_device'!)
    let (_ret, out_init) = arrayinit_pe.release(true, false).context(JobError {})?;

    // for arrayupdate and arraysum we now simply pass the array's base address since
    // the data is already present in device memory
    let arrayupdate_args = vec![PEParameter::VirtualAddress(out_init[0].as_ptr())];
    let mut arrayupdate_pe = device.acquire_pe(arrayupdate_id).context(DeviceInit {})?;
    arrayupdate_pe.start(arrayupdate_args).context(JobError {})?;

    let (_ret, _out_update) = arrayupdate_pe.release(true, false).context(JobError {})?;

    let arraysum_args = vec![PEParameter::VirtualAddress(out_init[0].as_ptr())];
    let mut arraysum_pe = device.acquire_pe(arraysum_id).context(DeviceInit {})?;
    arraysum_pe.start(arraysum_args).context(JobError {})?;

    let (ret, _out_sum) = arraysum_pe.release(true, true).context(JobError {})?;

    // calculate reference result
    let mut ref_sum = 0u64;
    for i in 0..ARRAY_SIZE {
        ref_sum += i as u64 + 42;
    }

    // check result
    if ret != ref_sum {
        error!("Pipeline example failed (act = {} vs. exp = {})!", ret, ref_sum);
    } else {
        info!("Pipeline example completed successfully");
    }
    Ok(())
}

fn main() -> Result<()> {
    env_logger::init();

    let tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInit)?;
    for mut x in devices {
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInit {})?;

        // get IDs
        let arrayinit_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayinit:1.0") {
            Ok(x) => x,
            Err(_e) => 11,
        };
        let arraysum_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:arraysum:1.0") {
            Ok(x) => x,
            Err(_e) => 10,
        };
        let arrayupdate_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayupdate:1.0") {
            Ok(x) => x,
            Err(_e) => 9,
        };

        // get instance counts
        let arrayinit_count = x.num_pes(arrayinit_id);
        let arraysum_count = x.num_pes(arraysum_id);
        let arrayupdate_count = x.num_pes(arrayupdate_id);

        let x_shared = Arc::new(x);

        if arrayinit_count == 0 && arraysum_count == 0 && arrayupdate_count == 0 {
            error!("Need at least one arrayinit, arraysum or arrayupdate instance to run!");
            return Ok(());
        }

        if arrayinit_count != 0 {
            match run_arrayinit(x_shared.clone(), arrayinit_id) {
                Err(e) => {
                    error!("Arrayinit example failed: {}", e);
                    if let Some(backtrace) = ErrorCompat::backtrace(&e) {
                        error!("{}", backtrace);
                    }
                    return Ok(());
                }
                Ok(()) => {
                    info!("Arrayinit example completed successfully");
                }
            };
        }

        if arraysum_count != 0 {
            match run_arraysum(x_shared.clone(), arraysum_id) {
                Err(e) => {
                    error!("Arraysum example failed: {}", e);
                    return Ok(());
                }
                Ok(()) => {
                    info!("Arraysum example completed successfully");
                }
            };
        }

        if arrayupdate_count != 0 {
            match run_arrayupdate(x_shared.clone(), arrayupdate_id) {
                Err(e) => {
                    error!("Arrayupdate example failed: {}", e);
                    return Ok(());
                }
                Ok(()) => {
                    info!("Arrayupdate example completed successfully");
                }
            };
        }

        if arrayinit_count != 0 && arraysum_count != 0 && arrayupdate_count != 0 {
            match run_pipeline(x_shared.clone(), arrayinit_id, arraysum_id, arrayupdate_id) {
                Err(e) => {
                    error!("Pipeline example failed: {}", e);
                    return Ok(());
                }
                Ok(()) => {
                    info!("Pipeline example completed successfully");
                }
            }
        }
    }
    Ok(())
}
