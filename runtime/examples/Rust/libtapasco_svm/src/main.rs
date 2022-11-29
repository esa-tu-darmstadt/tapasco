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
        let mut pe = device.acquire_pe(arrayinit_id).context(DeviceInitSnafu {})?;
        pe.start(arg_vec).context(JobSnafu {})?;

        let _out_args = pe.release(true, false).context(JobSnafu {})?;

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
            memory: device.default_memory().context(DeviceInitSnafu {})?, // other memories currently not supported
            fixed: None,
        })];
        let mut pe = device.acquire_pe(arrayinit_id).context(DeviceInitSnafu {})?;
        pe.start(arg_vec).context(JobSnafu {})?;

        let (_ret, out_vecs) = pe.release(true, false).context(JobSnafu {})?;

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
        let mut pe = device.acquire_pe(arraysum_id).context(DeviceInitSnafu {})?;
        pe.start(arg_vec).context(JobSnafu {})?;
        let (ret, _out_vecs) = pe.release(true, true).context(JobSnafu {})?;
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
            memory: device.default_memory().context(DeviceInitSnafu {})?, // other memories currently not supported
            fixed: None,
        })];
        let mut pe = device.acquire_pe(arraysum_id).context(DeviceInitSnafu {})?;
        pe.start(arg_vec).context(JobSnafu {})?;

        let (ret, _out_vecs) = pe.release(true, true).context(JobSnafu {})?;

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
        let mut pe = device.acquire_pe(arrayupdate_id).context(DeviceInitSnafu {})?;
        pe.start(arg_vec).context(JobSnafu {})?;

        let _out_args = pe.release(true, false).context(JobSnafu {})?;

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
            memory: device.default_memory().context(DeviceInitSnafu {})?, // other memories currently not supported
            fixed: None,
        })];
        let mut pe = device.acquire_pe(arrayupdate_id).context(DeviceInitSnafu {})?;
        pe.start(arg_vec).context(JobSnafu {})?;

        let (_ret, out_vecs) = pe.release(true, false).context(JobSnafu {})?;

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

fn run_pipeline(arrayinit_dev: Arc<Device>, arrayinit_id: PEId, arrayupdate_dev: Arc<Device>,
                arrayupdate_id: PEId, arraysum_dev: Arc<Device>, arraysum_id: PEId) -> Result<()> {
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
        memory: arrayinit_dev.default_memory().context(DeviceInitSnafu {})?, // other memories currently not supported
        fixed: None,
    })];
    let mut arrayinit_pe = arrayinit_dev.acquire_pe(arrayinit_id).context(DeviceInitSnafu {})?;
    arrayinit_pe.start(arrayinit_args).context(JobSnafu {})?;

    // do not forget to regain ownership of our array (returned in out_vecs vector although we did not set 'from_device'!)
    let (_ret, out_init) = arrayinit_pe.release(true, false).context(JobSnafu {})?;

    // for arrayupdate and arraysum we now simply pass the array's base address
    // when running on one FPGA only, the data is already present in device memory
    //   and no further migrations are required
    // in a distributed run direct device-to-device migrations will be initiated
    //   by device page faults
    let arrayupdate_args = vec![PEParameter::VirtualAddress(out_init[0].as_ptr())];
    let mut arrayupdate_pe = arrayupdate_dev.acquire_pe(arrayupdate_id).context(DeviceInitSnafu {})?;
    arrayupdate_pe.start(arrayupdate_args).context(JobSnafu {})?;

    let (_ret, _out_update) = arrayupdate_pe.release(true, false).context(JobSnafu {})?;

    let arraysum_args = vec![PEParameter::VirtualAddress(out_init[0].as_ptr())];
    let mut arraysum_pe = arraysum_dev.acquire_pe(arraysum_id).context(DeviceInitSnafu {})?;
    arraysum_pe.start(arraysum_args).context(JobSnafu {})?;

    let (ret, _out_sum) = arraysum_pe.release(true, true).context(JobSnafu {})?;

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

    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let device_list = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    let mut devices: Vec<Arc<Device>> = Vec::new();
    for mut d in device_list {
        d.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;
        devices.push(Arc::new(d));
    }

    // retrieve PE IDs and count available PEs on all devices
    let mut arrayinit_pe_count = Vec::new();
    let mut arrayupdate_pe_count = Vec::new();
    let mut arraysum_pe_count = Vec::new();
    let mut arrayinit_id = None;
    let mut arrayupdate_id = None;
    let mut arraysum_id = None;
    for d in devices.iter() {
        match d.get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayinit:1.0") {
            Ok(id) => {
                arrayinit_id = Some(id);
                arrayinit_pe_count.push(d.num_pes(id));
            },
            Err(_e) => {
                arrayinit_pe_count.push(0);
            },
        };
        match d.get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayupdate:1.0") {
            Ok(id) => {
                arrayupdate_id = Some(id);
                arrayupdate_pe_count.push(d.num_pes(id));
            },
            Err(_e) => {
                arrayupdate_pe_count.push(0);
            },
        };
        match d.get_pe_id("esa.cs.tu-darmstadt.de:hls:arraysum:1.0") {
            Ok(id) => {
                arraysum_id = Some(id);
                arraysum_pe_count.push(d.num_pes(id));
            },
            Err(_e) => {
                arraysum_pe_count.push(0);
            },
        };
    }

    // No PEs found to run any tests
    if arrayinit_id.is_none() && arrayupdate_id.is_none() && arraysum_id.is_none() {
        error!("Need at least one arrayinit, arrayupdate or arraysum instance to run.");
        return Ok(());
    }

    // Run tests on all devices if required PEs are available
    for (i, d) in devices.iter().enumerate() {
        if arrayinit_pe_count[i] != 0 {
            match run_arrayinit(d.clone(), arrayinit_id.unwrap()) {
                Err(e) => {
                    error!("Arrayinit example failed: {}", e);
                    if let Some(backtrace) = ErrorCompat::backtrace(&e) {
                        error!("{}", backtrace);
                    }
                    return Ok(());
                }
                Ok(()) => {
                    info!("Arrayinit example completed");
                }
            };
        }

        if arrayupdate_pe_count[i] != 0 {
            match run_arrayupdate(d.clone(), arrayupdate_id.unwrap()) {
                Err(e) => {
                    error!("Arrayupdate example failed: {}", e);
                    return Ok(());
                }
                Ok(()) => {
                    info!("Arrayupdate example completed");
                }
            };
        }

        if arraysum_pe_count[i] != 0 {
            match run_arraysum(d.clone(), arraysum_id.unwrap()) {
                Err(e) => {
                    error!("Arraysum example failed: {}", e);
                    return Ok(());
                }
                Ok(()) => {
                    info!("Arraysum example completed");
                }
            };
        }
    }

    if arrayinit_id.is_some() && arrayupdate_id.is_some() && arraysum_id.is_some() {
        // try to find PEs distributed across FPGAs for pipeline example (nothing too sophisticated)
        let mut arrayinit_dev_idx = None;
        let mut arrayupdate_dev_idx = None;
        let mut arrayinit_device = None;
        let mut arrayupdate_device = None;
        let mut arraysum_device = None;
        for (i, d) in devices.iter().enumerate() {
            if arrayinit_pe_count[i] > 0 {
                arrayinit_dev_idx = Some(i);
                arrayinit_device = Some(d.clone());
                break;
            }
        }
        for (i, d) in devices.iter().enumerate() {
            if arrayupdate_pe_count[i] > 0 {
                arrayupdate_dev_idx = Some(i);
                arrayupdate_device = Some(d.clone());
                if arrayinit_dev_idx.is_some() && arrayinit_dev_idx.unwrap() != i {
                    break;
                }
            }
        }
        for (i, d) in devices.iter().enumerate() {
            if arraysum_pe_count[i] > 0 {
                arraysum_device = Some(d.clone());
                if arrayupdate_dev_idx.is_some() && arrayupdate_dev_idx.unwrap() != i {
                    break;
                }
            }
        }

        match run_pipeline(arrayinit_device.unwrap(), arrayinit_id.unwrap(),
                           arrayupdate_device.unwrap(), arrayupdate_id.unwrap(),
                           arraysum_device.unwrap(), arraysum_id.unwrap()) {
            Err(e) => {
                error!("Pipeline example failed: {}", e);
                return Ok(());
            }
            Ok(()) => {
                info!("Pipeline example completed");
            }
        }
    }

    Ok(())
}
