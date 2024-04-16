extern crate crossbeam;
extern crate num_cpus;
extern crate rand;
extern crate rayon;
extern crate snafu;
extern crate tapasco;
#[macro_use]
extern crate log;
extern crate indicatif;
extern crate clap;
extern crate uom;

use average::{concatenate, Estimate, Max, MeanWithError, Min};
use clap::{Command, Arg, ArgMatches, ArgAction};
use crossbeam::thread;
use indicatif::{HumanBytes, ProgressBar, ProgressStyle};
use itertools::Itertools;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use snafu::{ErrorCompat, ResultExt, Snafu};
use std::collections::HashMap;
use std::env;
use std::io;
use std::io::Write;
use std::iter;
use std::sync::{Arc, Mutex};
use std::time::Instant;
use tapasco::device::OffchipMemory;
use tapasco::tlkm::*;
use uom::si::f32::*;
use uom::si::time::microsecond;
use uom::si::time::nanosecond;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Allocator Error: {}", source))]
    AllocatorError { source: tapasco::allocator::Error },

    #[snafu(display("DMA Error: {}", source))]
    DMAError { source: tapasco::dma::Error },

    #[snafu(display("Invalid subcommand"))]
    UnknownCommand {},
    #[snafu(display("Failed to initialize TLKM object: {}", source))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display("Failed to decode TLKM device: {}", source))]
    DeviceInit { source: tapasco::device::Error },

    #[snafu(display("Error while executing Job: {}", source))]
    JobError { source: tapasco::job::Error },

    #[snafu(display("IO Error: {}", source))]
    IOError { source: std::io::Error },

    #[snafu(display("Mutex has been poisoned"))]
    MutexError {},

    #[snafu(display("Crossbeam encountered an error {}", s))]
    CrossbeamError { s: String },
}

impl<T> From<std::sync::PoisonError<T>> for Error {
    fn from(_error: std::sync::PoisonError<T>) -> Self {
        Error::MutexError {}
    }
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

fn print_version(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let ver = tlkm.version().context(TLKMInitSnafu {})?;
    println!("TLKM version is {}", ver);
    Ok(())
}

fn enum_devices(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu {})?;
    println!("Got {} devices.", devices.len());
    for x in devices {
        println!(
            "Device {}: Name: {}, Vendor: {}, Product {}",
            x.id(),
            x.name(),
            x.vendor(),
            x.product()
        );
    }
    Ok(())
}

fn allocate_devices(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let mut devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu {})?;

    for x in devices.iter_mut() {
        println!("Allocating ID {} exclusively.", x.id());
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;
    }

    Ok(())
}

fn print_status(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for x in devices {
        println!("Device {}", x.id());
        println!("{:?}", x.status());
    }
    Ok(())
}

fn run_arrayinit(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices {
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;
        let counter_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:arrayinit:1.0") {
            Ok(x) => x,
            Err(_e) => 11,
        };
        let mut pe = x.acquire_pe(counter_id).context(DeviceInitSnafu)?;

        pe.start(vec![tapasco::device::PEParameter::DataTransferAlloc(
            tapasco::device::DataTransferAlloc {
                data: vec![255; 256 * 4].into_boxed_slice(),
                free: true,
                from_device: true,
                to_device: false,
                memory: x.default_memory().context(DeviceInitSnafu)?,
                fixed: None,
            },
        )])
        .context(JobSnafu)?;

        println!("{:?}", pe.release(true, false).context(JobSnafu)?);
    }
    Ok(())
}

fn run_counter(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices {
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;

        let counter_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:counter:0.9") {
            Ok(x) => x,
            Err(_e) => 14,
        };

        let mut pes = Vec::new();
        pes.push(x.acquire_pe(counter_id).context(DeviceInitSnafu)?);
        pes.push(x.acquire_pe(counter_id).context(DeviceInitSnafu)?);
        pes.push(x.acquire_pe(counter_id).context(DeviceInitSnafu)?);
        pes.push(x.acquire_pe(counter_id).context(DeviceInitSnafu)?);
        for _ in 0..10 {
            for pe in &mut pes.iter_mut() {
                pe.start(vec![tapasco::device::PEParameter::Single64(1000)])
                    .context(JobSnafu)?;
            }
            for pe in &mut pes.iter_mut() {
                pe.release(false, false).context(JobSnafu)?;
            }
        }
        for mut pe in pes {
            pe.release(true, false).context(JobSnafu)?;
        }
    }
    Ok(())
}

fn benchmark_counter(m: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices.into_iter() {
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu)?;

        let counter_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:counter:0.9") {
            Ok(x) => x,
            Err(_e) => 14,
        };

        let x_l = Arc::new(x);
        let iterations: usize = *m.get_one("iterations").unwrap();
        let mut num_threads = *m.get_one("threads").unwrap();
        if num_threads == -1 {
            num_threads = num_cpus::get() as i32;
        }
        let pb_step: usize = *m.get_one("pb_step").unwrap();
        println!(
            "Starting {} thread benchmark with {} iterations and {} step.",
            num_threads, iterations, pb_step
        );

        for cur_threads in 1..num_threads + 1 {
            let iterations_per_threads = iterations / cur_threads as usize;
            let iterations_cur = iterations_per_threads * cur_threads as usize;

            let mut pb = ProgressBar::new(iterations_cur as u64);
            if *m.get_one("pb_disable").unwrap() {
                pb = ProgressBar::hidden();
            }
            pb.tick();

            let now = Instant::now();
            thread::scope(|s| {
                for _t in 0..cur_threads {
                    s.spawn(|_| {
                        let x_local = x_l.clone();
                        let mut pe =
                            { x_local.acquire_pe(counter_id).context(DeviceInitSnafu).unwrap() };
                        for i in 0..iterations_per_threads {
                            pe.start(vec![tapasco::device::PEParameter::Single64(1)])
                                .context(JobSnafu)
                                .unwrap();
                            pe.release(false, false).context(JobSnafu).unwrap();
                            if i > 0 && i % pb_step == 0 {
                                pb.inc(pb_step as u64);
                            }
                        }
                    });
                }
            })
            .unwrap();

            let done = now.elapsed().as_secs_f32();

            pb.finish_and_clear();
            println!(
                "Result with {} Threads: {} calls/s",
                cur_threads,
                iterations_cur as f32 / done
            );
        }
    }
    Ok(())
}

concatenate!(
    LatencyStats,
    [Min, min],
    [Max, max],
    [MeanWithError, mean],
    [MeanWithError, error]
);

fn latency_benchmark(m: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices {
        println!("Evaluating device {:?}", x.id());
        let design_mhz = x.design_frequency_mhz().context(DeviceInitSnafu)?;
        println!("Counter running with {:?} MHz.", design_mhz);
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;
        let mut iterations = *m.get_one("iterations").unwrap();
        let max_step = *m.get_one("steps").unwrap();
        println!("Starting benchmark.");

        let counter_id = match x.get_pe_id("esa.cs.tu-darmstadt.de:hls:counter:0.9") {
            Ok(x) => x,
            Err(_e) => 14,
        };

        for step_pow in 0..max_step {
            let step = u64::pow(2, step_pow);
            let step_duration_ns = (step as f32) * (1.0 / design_mhz);
            let mut var = LatencyStats::new();

            if iterations * (step_duration_ns as usize) > (4 * 1000000000) {
                iterations = (4 * 1000000000) / (step_duration_ns as usize);
            }

            print!(
                "Checking {:.0} us execution (I {}): ",
                step_duration_ns, iterations
            );
            io::stdout().flush().context(IOSnafu)?;

            for _ in 0..iterations {
                let mut pe = x.acquire_pe(counter_id).context(DeviceInitSnafu)?;
                let now = Instant::now();
                pe.start(vec![tapasco::device::PEParameter::Single64(step)])
                    .context(JobSnafu)?;
                pe.release(true, false).context(JobSnafu)?;
                let dur = now.elapsed();
                let diff = Time::new::<nanosecond>(dur.as_nanos() as f32)
                    - Time::new::<nanosecond>(step_duration_ns);
                var.add(diff.get::<microsecond>() as f64);
            }
            println!(
                "The mean latency is {:.2}us ± {:.2}us (Min: {:.2}, Max: {:.2}).",
                var.mean(),
                var.error(),
                var.min(),
                var.max(),
            );
        }
    }
    Ok(())
}

fn test_copy(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices {
        println!("Evaluating device {}", x.id());
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;

        let mem = x.default_memory().context(DeviceInitSnafu)?;

        let mut small_rng = StdRng::from_entropy();

        for len_pow in 0..28 {
            let len = i32::pow(2, len_pow);
            println!("Checking {}", HumanBytes(len as u64));
            let a = mem
                .allocator()
                .lock()?
                .allocate(len as u64, None)
                .context(AllocatorSnafu)?;

            let mut golden_samples: Vec<u8> = Vec::new();
            let mut result: Vec<u8> = Vec::new();
            for _ in 0..len {
                golden_samples.push(small_rng.gen());
                result.push(255);
            }

            mem.dma().copy_to(&golden_samples, a).context(DMASnafu)?;
            mem.dma().copy_from(a, &mut result).context(DMASnafu)?;

            let not_matching = golden_samples
                .iter()
                .zip(result.iter())
                .filter(|&(a, b)| a != b)
                .count();

            if not_matching != 0 {
                println!("{} Bytes not matching", not_matching);
            } else {
                println!("All bytes matching.");
            }

            if not_matching != 0 {
                for (i, v) in golden_samples.iter().enumerate() {
                    if *v != result[i] {
                        println!("result[{}] == {} != {}", i, result[i], v);
                    }
                }
            }

            mem.allocator().lock()?.free(a).context(AllocatorSnafu)?;
        }
    }
    Ok(())
}

fn evaluate_copy(_m: &ArgMatches) -> Result<()> {
    let buffer_size_min: f64 = 4.0 * 1024.0;
    let buffer_size_max: f64 = 4.0 * 1024.0 * 1024.0;

    let buffer_num_min = 1;
    let buffer_num_max = 16;

    let mut curr = buffer_size_min;
    let pow2 = iter::repeat_with(|| {
        let tmp = curr;
        curr *= 2.0;
        tmp as u64
    })
    .take((buffer_size_max.log2() - buffer_size_min.log2()) as usize + 1)
    .cartesian_product(buffer_num_min..buffer_num_max);

    let mut results = HashMap::new();

    let mut best_results = HashMap::new();

    let repetitions = 100;

    let chunk_max = 26;

    let mut data = vec![0; usize::pow(2, chunk_max as u32)];

    for (size, num) in pow2 {
        env::set_var("tapasco_dma__read_buffers", format!("{}", num));
        env::set_var("tapasco_dma__write_buffers", format!("{}", num));
        env::set_var("tapasco_dma__read_buffer_size", format!("{}", size));
        env::set_var("tapasco_dma__write_buffer_size", format!("{}", size));
        let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
        let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
        let mem = devices[0].default_memory().context(DeviceInitSnafu)?;

        println!("Testing {} x {}kB", num, size);

        for chunk_pow in 10..(chunk_max + 1) {
            let chunk = usize::pow(2, chunk_pow as u32);

            println!("Chunk: {}", chunk);

            let repetitions_used = if chunk * repetitions > (256 * 1024 * 1024) {
                (256 * 1024 * 1024) / chunk
            } else {
                repetitions
            };

            let a = mem
                .allocator()
                .lock()?
                .allocate(chunk as u64, None)
                .context(AllocatorSnafu)?;

            let now = Instant::now();
            for _ in 0..repetitions_used {
                mem.dma().copy_to(&data[0..chunk], a).context(DMASnafu)?;
            }
            let done = now.elapsed().as_secs_f64();

            let bps = (chunk as f64) / (done / (repetitions_used as f64));
            results.insert((size, num, chunk, "r"), bps);
            let config = (chunk, "r");
            let r = (bps, size, num);
            match best_results.get_mut(&config) {
                Some(k) => {
                    let (bps_old, _, _) = *k;
                    if bps_old < bps {
                        *k = r;
                    }
                }
                None => {
                    best_results.insert(config, r);
                }
            }

            let now = Instant::now();
            for _ in 0..repetitions_used {
                mem.dma()
                    .copy_from(a, &mut data[0..chunk])
                    .context(DMASnafu)?;
            }
            let done = now.elapsed().as_secs_f64();

            let bps = (chunk as f64) / (done / (repetitions_used as f64));
            results.insert((size, num, chunk, "w"), bps);
            let config = (chunk, "w");
            let r = (bps, size, num);
            match best_results.get_mut(&config) {
                Some(k) => {
                    let (bps_old, _, _) = *k;
                    if bps_old < bps {
                        *k = r;
                    }
                }
                None => {
                    best_results.insert(config, r);
                }
            }

            mem.allocator().lock()?.free(a).context(AllocatorSnafu)?;
        }
    }

    println!("Best results:");
    for ((chunk, dir), (bps, size, num)) in best_results {
        let mbps = bps / (1024.0 * 1024.0);
        if dir == "r" {
            println!(
                "{} kB Read: {} Mbps -> Num: {}, Size: {}",
                chunk / 1024,
                mbps,
                num,
                size
            );
        } else {
            println!(
                "{} kB Write: {} Mbps -> Num: {}, Size: {}",
                chunk / 1024,
                mbps,
                num,
                size
            );
        }
    }

    Ok(())
}

fn transfer_to(
    pb: &ProgressBar,
    mem: Arc<OffchipMemory>,
    bytes: usize,
    chunk: usize,
    data: Vec<u8>,
) -> Result<()> {
    let a = mem
        .allocator()
        .lock()?
        .allocate(chunk as u64, None)
        .context(AllocatorSnafu)?;
    let mut transferred = 0;
    let mut incr = 0;

    while transferred < bytes {
        mem.dma().copy_to(&data, a).context(DMASnafu)?;
        transferred += chunk;
        if incr % 1024 == 0 {
            pb.inc((chunk * 1024) as u64);
        }
        incr += 1;
    }

    mem.allocator().lock()?.free(a).context(AllocatorSnafu)?;

    Ok(())
}

fn transfer_from(
    pb: &ProgressBar,
    mem: Arc<OffchipMemory>,
    bytes: usize,
    chunk: usize,
    mut data: Vec<u8>,
) -> Result<()> {
    let a = mem
        .allocator()
        .lock()?
        .allocate(chunk as u64, None)
        .context(AllocatorSnafu)?;
    let mut transferred = 0;
    let mut incr = 0;

    while transferred < bytes {
        mem.dma().copy_from(a, &mut data).context(DMASnafu)?;
        transferred += chunk;
        if incr % 1024 == 0 {
            pb.inc((chunk * 1024) as u64);
        }
        incr += 1;
    }

    mem.allocator().lock()?.free(a).context(AllocatorSnafu)?;

    Ok(())
}

fn benchmark_copy(m: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices.into_iter() {
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu)?;
        let x_l = Arc::new(x);
        let max_size_power: u32 = *m.get_one("max_bytes").unwrap();
        let max_size = usize::pow(2, max_size_power);

        let total_bytes_power: u32 = *m.get_one("total_bytes").unwrap();
        let total_bytes = usize::pow(2, total_bytes_power);

        let mut num_threads = *m.get_one("threads").unwrap();
        if num_threads == -1 {
            num_threads = num_cpus::get() as i32;
        }
        let _pb_step: usize = *m.get_one("pb_step").unwrap();
        println!(
            "Starting {} thread transfer benchmark with maximum of {} per transfer and total {}.",
            num_threads,
            HumanBytes(max_size as u64),
            HumanBytes(total_bytes as u64)
        );
        for cur_threads in 1..num_threads + 1 {
            for chunk_pow in 10..(max_size_power + 1) {
                let chunk = usize::pow(2, chunk_pow as u32);
                let bytes_per_threads = total_bytes / cur_threads as usize;
                let mut total_bytes_cur = bytes_per_threads * cur_threads as usize;

                for d in ["r", "w", "rw"].iter() {
                    if *d == "rw" {
                        total_bytes_cur *= 2;
                    }
                    let mut pb = ProgressBar::new(total_bytes_cur as u64);
                    pb.set_style(
                        ProgressStyle::default_bar()
                            .template("{wide_bar} {bytes}/{total_bytes} {bytes_per_sec}").unwrap(),
                    );
                    if *m.get_one("pb_disable").unwrap() {
                        pb = ProgressBar::hidden();
                    }
                    pb.tick();

                    let data = Arc::new(Mutex::new(Vec::new()));
                    for _ in 0..if *d == "rw" {
                        cur_threads * 2
                    } else {
                        cur_threads
                    } {
                        data.lock().unwrap().push(vec![0; chunk]);
                    }

                    let now = Instant::now();
                    thread::scope(|s| {
                        for i in 0..cur_threads {
                            if *d == "rw" {
                                if i % 2 == 0 {
                                    s.spawn(|_s_local| {
                                        let v = data.lock().unwrap().pop().unwrap();
                                        let v2 = data.lock().unwrap().pop().unwrap();
                                        let x_local = x_l.clone();
                                        let mem = x_local.default_memory().unwrap();
                                        let mem2 = x_local.default_memory().unwrap();
                                        transfer_to(&pb, mem, bytes_per_threads, chunk, v).unwrap();
                                        transfer_from(&pb, mem2, bytes_per_threads, chunk, v2)
                                            .unwrap();
                                    });
                                } else {
                                    s.spawn(|_s_local| {
                                        let v = data.lock().unwrap().pop().unwrap();
                                        let v2 = data.lock().unwrap().pop().unwrap();
                                        let x_local = x_l.clone();
                                        let mem = x_local.default_memory().unwrap();
                                        let mem2 = x_local.default_memory().unwrap();
                                        transfer_from(&pb, mem, bytes_per_threads, chunk, v)
                                            .unwrap();
                                        transfer_to(&pb, mem2, bytes_per_threads, chunk, v2)
                                            .unwrap();
                                    });
                                }
                            } else {
                                if *d == "w" {
                                    s.spawn(|_s_local| {
                                        let v = data.lock().unwrap().pop().unwrap();
                                        let x_local = x_l.clone();
                                        let mem = x_local.default_memory().unwrap();
                                        transfer_to(&pb, mem, bytes_per_threads, chunk, v).unwrap();
                                    });
                                }
                                if *d == "r" {
                                    s.spawn(|_s_local| {
                                        let v = data.lock().unwrap().pop().unwrap();
                                        let x_local = x_l.clone();
                                        let mem = x_local.default_memory().unwrap();
                                        transfer_from(&pb, mem, bytes_per_threads, chunk, v)
                                            .unwrap();
                                    });
                                }
                            }
                        }
                    })
                    .unwrap();
                    let done = now.elapsed().as_secs_f64();

                    pb.finish_and_clear();
                    println!(
                        "Result for {} with {} Threads and Chunk Size of {}: {}/s",
                        d,
                        cur_threads,
                        HumanBytes(chunk as u64),
                        HumanBytes((total_bytes_cur as f64 / done) as u64)
                    );
                }
            }
        }
    }
    Ok(())
}

fn test_localmem(_: &ArgMatches) -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInitSnafu {})?;
    let devices = tlkm.device_enum(&HashMap::new()).context(TLKMInitSnafu)?;
    for mut x in devices {
        x.change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(DeviceInitSnafu {})?;
        let mut pe = x.acquire_pe(42).context(DeviceInitSnafu)?;
        pe.start(vec![tapasco::device::PEParameter::DataTransferLocal(
            tapasco::device::DataTransferLocal {
                data: vec![0, 1, 2, 3, 4, 5, 6].into_boxed_slice(),
                free: true,
                from_device: true,
                to_device: true,
                fixed: None,
            },
        )])
        .context(JobSnafu)?;

        let r = pe.release(true, false).context(JobSnafu)?;
        println!("{:?}", r);
    }
    Ok(())
}

fn main() -> Result<()> {
    env_logger::init();

    let matches = Command::new("libtapasco_tests")
        .arg_required_else_help(true)
        .subcommand(
            Command::new("version").about("Print information about the driver version."),
        )
        .subcommand(
            Command::new("enum")
                .about("Print information about the available TLKM devices."),
        )
        .subcommand(
            Command::new("allocate").about("Try to exclusively allocate all devices."),
        )
        .subcommand(
            Command::new("status").about("Print status core information of all devices."),
        )
        .subcommand(Command::new("run_counter").about("Runs a counter with ID 14."))
        .subcommand(
            Command::new("run_arrayinit").about("Runs an arrayinit instance with ID 11."),
        )
        .subcommand(
            Command::new("benchmark_copy")
                .about("Runs a copy benchmark for r, w and rw.")
                .arg(
                    Arg::new("pb_disable")
                        .short('p')
                        .long("pb_disable")
                        .num_args(0)
                        .action(ArgAction::SetTrue)
                        .help("Disables the progress bar to avoid overhead."),
                )
                .arg(
                    Arg::new("pb_step")
                        .short('s')
                        .long("pb_step")
                        .help("Step size for the progress bar.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(usize))
                        .default_value("1000"),
                )
                .arg(
                    Arg::new("max_bytes")
                        .short('m')
                        .long("max_bytes")
                        .help("Maximum number of bytes in a single transfer transfer log_2.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(u32))
                        .default_value("24"),
                )
                .arg(
                    Arg::new("total_bytes")
                        .short('b')
                        .long("total_bytes")
                        .help("Total number of bytes to transfer transfer log_2.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(u32))
                        .default_value("30"),
                )
                .arg(
                    Arg::new("threads")
                        .short('t')
                        .long("threads")
                        .help("How many threads should be used? (-1 for auto)")
                        .num_args(1)
                        .value_parser(clap::value_parser!(i32))
                        .default_value("-1"),
                ),
        )
        .subcommand(
            Command::new("run_benchmark")
                .about("Runs a counter benchmark with ID 14.")
                .arg(
                    Arg::new("pb_disable")
                        .short('p')
                        .long("pb_disable")
                        .num_args(0)
                        .action(ArgAction::SetTrue)
                        .help("Disables the progress bar to avoid overhead."),
                )
                .arg(
                    Arg::new("pb_step")
                        .short('s')
                        .long("pb_step")
                        .help("Step size for the progress bar.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(usize))
                        .default_value("1000"),
                )
                .arg(
                    Arg::new("iterations")
                        .short('i')
                        .long("iterations")
                        .help("How many counter iterations.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(usize))
                        .default_value("100000"),
                )
                .arg(
                    Arg::new("threads")
                        .short('t')
                        .long("threads")
                        .help("How many threads should be used? (-1 for auto)")
                        .num_args(1)
                        .value_parser(clap::value_parser!(i32))
                        .default_value("-1"),
                ),
        )
        .subcommand(
            Command::new("run_latency")
                .about("Runs a counter based latency check with ID 14.")
                .arg(
                    Arg::new("steps")
                        .short('s')
                        .long("steps")
                        .help("Testing from 2**0 to 2**s.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(u32))
                        .default_value("28"),
                )
                .arg(
                    Arg::new("iterations")
                        .short('i')
                        .long("iterations")
                        .help("How many counter iterations.")
                        .num_args(1)
                        .value_parser(clap::value_parser!(usize))
                        .default_value("1000"),
                ),
        )
        .subcommand(
            Command::new("test_copy")
                .about("Tests the copy to and from the device on memory 0."),
        )
        .subcommand(
            Command::new("test_localmem")
                .about("Tests running a job with local memory (uses ID 42)."),
        )
        .subcommand(
            Command::new("evaluate_copy")
                .about("Find optimal buffer settings for current host/device combination."),
        )
        .get_matches();

    match match matches.subcommand() {
        Some(("version", m)) => print_version(m),
        Some(("enum", m)) => enum_devices(m),
        Some(("allocate", m)) => allocate_devices(m),
        Some(("status", m)) => print_status(m),
        Some(("run_counter", m)) => run_counter(m),
        Some(("run_arrayinit", m)) => run_arrayinit(m),
        Some(("run_benchmark", m)) => benchmark_counter(m),
        Some(("run_latency", m)) => latency_benchmark(m),
        Some(("test_copy", m)) => test_copy(m),
        Some(("benchmark_copy", m)) => benchmark_copy(m),
        Some(("test_localmem", m)) => test_localmem(m),
        Some(("evaluate_copy", m)) => evaluate_copy(m),
        _ => Err(Error::UnknownCommand {}),
    } {
        Ok(()) => Ok(()),
        Err(e) => {
            error!("An error occured: {}", e);
            if let Some(backtrace) = ErrorCompat::backtrace(&e) {
                error!("{}", backtrace);
            }
            Ok(())
        }
    }
}
