extern crate crossbeam;
extern crate num_cpus;
extern crate rand;
extern crate rayon;
extern crate snafu;
extern crate tapasco;
#[macro_use]
extern crate log;
extern crate indicatif;
#[macro_use]
extern crate clap;
extern crate uom;

use average::{concatenate, Estimate, Max, MeanWithError, Min};
use clap::{App, AppSettings, Arg, ArgMatches, SubCommand};
use crossbeam::thread;
use indicatif::{HumanBytes, ProgressBar, ProgressStyle};
use snafu::{ErrorCompat, ResultExt, Snafu};
use std::io;
use std::io::Write;
use std::sync::{Arc, Mutex};
use std::time::Instant;
use tapasco::device::OffchipMemory;
use tapasco::tlkm::*;
use uom::si::f32::*;
use uom::si::frequency::megahertz;
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
    let tlkm = TLKM::new().context(TLKMInit {})?;
    let ver = tlkm.version().context(TLKMInit {})?;
    println!("TLKM version is {}", ver);
    Ok(())
}

fn enum_devices(_: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit {})?;
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
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let mut devices = tlkm.device_enum().context(TLKMInit {})?;

    for x in devices.iter_mut() {
        println!("Allocating ID {} exclusively.", x.id());
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit {})?;
    }

    Ok(())
}

fn print_status(_: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for x in devices {
        println!("Device {}", x.id());
        println!("{:?}", x.status());
    }
    Ok(())
}

fn run_counter(_: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for mut x in devices {
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit {})?;
        let mut pes = Vec::new();
        pes.push(x.acquire_pe(14).context(DeviceInit)?);
        pes.push(x.acquire_pe(14).context(DeviceInit)?);
        pes.push(x.acquire_pe(14).context(DeviceInit)?);
        pes.push(x.acquire_pe(14).context(DeviceInit)?);
        for _ in 0..10 {
            for pe in &mut pes.iter_mut() {
                pe.start(vec![tapasco::device::PEParameter::Single64(1000)])
                    .context(JobError)?;
            }
            for pe in &mut pes.iter_mut() {
                pe.release(false).context(JobError)?;
            }
        }
        for mut pe in pes {
            pe.release(true).context(JobError)?;
        }
    }
    Ok(())
}

fn benchmark_counter(m: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for mut x in devices.into_iter() {
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit)?;
        let x_l = Arc::new(x);
        let iterations = value_t!(m, "iterations", usize).unwrap();
        let mut num_threads = value_t!(m, "threads", i32).unwrap();
        if num_threads == -1 {
            num_threads = num_cpus::get() as i32;
        }
        let pb_step: usize = value_t!(m, "pb_step", usize).unwrap();
        println!(
            "Starting {} thread benchmark with {} iterations and {} step.",
            num_threads, iterations, pb_step
        );
        for cur_threads in 1..num_threads + 1 {
            let iterations_per_threads = iterations / cur_threads as usize;
            let iterations_cur = iterations_per_threads * cur_threads as usize;

            let mut pb = ProgressBar::new(iterations_cur as u64);
            if m.is_present("pb_disable") {
                pb = ProgressBar::hidden();
            }
            pb.tick();

            let now = Instant::now();
            thread::scope(|s| {
                for _t in 0..cur_threads {
                    s.spawn(|_| {
                        let x_local = x_l.clone();
                        let mut pe = { x_local.acquire_pe(14).context(DeviceInit).unwrap() };
                        for i in 0..iterations_per_threads {
                            pe.start(vec![tapasco::device::PEParameter::Single64(1)])
                                .context(JobError)
                                .unwrap();
                            pe.release(false).context(JobError).unwrap();
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
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for mut x in devices {
        println!("Evaluating device {:?}", x.id());
        let design_mhz = x.design_frequency().context(DeviceInit)?;
        println!(
            "Counter running with {:?} MHz.",
            design_mhz.get::<megahertz>()
        );
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit {})?;
        let mut iterations = value_t!(m, "iterations", usize).unwrap();
        let max_step = value_t!(m, "steps", u32).unwrap();
        println!("Starting benchmark.");
        for step_pow in 0..max_step {
            let step = u64::pow(2, step_pow);
            let step_duration = (step as f32) * (1.0 / design_mhz);
            let mut var = LatencyStats::new();

            if iterations * (step_duration.get::<nanosecond>() as usize) > (4 * 1000000000) {
                iterations = (4 * 1000000000) / (step_duration.get::<nanosecond>() as usize);
            }

            print!(
                "Checking {:.0} us execution (I {}): ",
                step_duration.get::<nanosecond>(),
                iterations
            );
            io::stdout().flush().context(IOError)?;

            for _ in 0..iterations {
                let mut pe = x.acquire_pe(14).context(DeviceInit)?;
                let now = Instant::now();
                pe.start(vec![tapasco::device::PEParameter::Single64(step)])
                    .context(JobError)?;
                pe.release(true).context(JobError)?;
                let dur = now.elapsed();
                let diff = Time::new::<nanosecond>(dur.as_nanos() as f32) - step_duration;
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
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for mut x in devices {
        println!("Evaluating device {}", x.id());
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit {})?;

        let mem = x.default_memory().context(DeviceInit)?;

        for len_pow in 0..28 {
            let len = i32::pow(2, len_pow);
            println!("Checking {}", HumanBytes(len as u64));
            let a = mem
                .allocator()
                .lock()?
                .allocate(256 * 4)
                .context(AllocatorError)?;

            let mut golden_samples: Vec<u8> = Vec::new();
            let mut result: Vec<u8> = Vec::new();
            for _ in 0..len {
                golden_samples.push(rand::random());
                result.push(255);
            }

            mem.dma().copy_to(&golden_samples, a).context(DMAError)?;
            mem.dma().copy_from(a, &mut result).context(DMAError)?;

            let not_matching = golden_samples
                .iter()
                .zip(result.iter())
                .filter(|&(a, b)| a != b)
                .count();
            println!("{} Bytes not matching", not_matching);

            if not_matching != 0 {
                for (i, v) in golden_samples.iter().enumerate() {
                    if *v != result[i] {
                        println!("result[{}] == {} != {}", i, result[i], v);
                    }
                }
            }

            mem.allocator().lock()?.free(a).context(AllocatorError)?;
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
        .allocate(chunk as u64)
        .context(AllocatorError)?;
    let mut transferred = 0;
    let mut incr = 0;

    while transferred < bytes {
        mem.dma().copy_to(&data, a).context(DMAError)?;
        transferred += chunk;
        if incr % 1024 == 0 {
            pb.inc((chunk * 1024) as u64);
        }
        incr += 1;
    }

    mem.allocator().lock()?.free(a).context(AllocatorError)?;

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
        .allocate(chunk as u64)
        .context(AllocatorError)?;
    let mut transferred = 0;
    let mut incr = 0;

    while transferred < bytes {
        mem.dma().copy_from(a, &mut data).context(DMAError)?;
        transferred += chunk;
        if incr % 1024 == 0 {
            pb.inc((chunk * 1024) as u64);
        }
        incr += 1;
    }

    mem.allocator().lock()?.free(a).context(AllocatorError)?;

    Ok(())
}

fn benchmark_copy(m: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for mut x in devices.into_iter() {
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit)?;
        let x_l = Arc::new(x);
        let max_size_power = value_t!(m, "max_bytes", usize).unwrap();
        let max_size = usize::pow(2, max_size_power as u32);

        let total_bytes_power = value_t!(m, "total_bytes", usize).unwrap();
        let total_bytes = usize::pow(2, total_bytes_power as u32);

        let mut num_threads = value_t!(m, "threads", i32).unwrap();
        if num_threads == -1 {
            num_threads = num_cpus::get() as i32;
        }
        let _pb_step: usize = value_t!(m, "pb_step", usize).unwrap();
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
                            .template("{wide_bar} {bytes}/{total_bytes} {bytes_per_sec}"),
                    );
                    if m.is_present("pb_disable") {
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

fn main() -> Result<()> {
    env_logger::init();

    let matches = App::new("libtapasco_tests")
        .setting(AppSettings::ArgRequiredElseHelp)
        .subcommand(
            SubCommand::with_name("version").about("Print information about the driver version."),
        )
        .subcommand(
            SubCommand::with_name("enum")
                .about("Print information about the available TLKM devices."),
        )
        .subcommand(
            SubCommand::with_name("allocate").about("Try to exclusively allocate all devices."),
        )
        .subcommand(
            SubCommand::with_name("status").about("Print status core information of all devices."),
        )
        .subcommand(SubCommand::with_name("run_counter").about("Runs a counter with ID 14."))
        .subcommand(
            SubCommand::with_name("benchmark_copy")
                .about("Runs a copy benchmark for r, w and rw.")
                .arg(
                    Arg::with_name("pb_disable")
                        .short("p")
                        .long("pb_disable")
                        .help("Disables the progress bar to avoid overhead."),
                )
                .arg(
                    Arg::with_name("pb_step")
                        .short("s")
                        .long("pb_step")
                        .help("Step size for the progress bar.")
                        .takes_value(true)
                        .default_value("1000"),
                )
                .arg(
                    Arg::with_name("max_bytes")
                        .short("m")
                        .long("max_bytes")
                        .help("Maximum number of bytes in a single transfer transfer log_2.")
                        .takes_value(true)
                        .default_value("24"),
                )
                .arg(
                    Arg::with_name("total_bytes")
                        .short("b")
                        .long("total_bytes")
                        .help("Total number of bytes to transfer transfer log_2.")
                        .takes_value(true)
                        .default_value("30"),
                )
                .arg(
                    Arg::with_name("threads")
                        .short("t")
                        .long("threads")
                        .help("How many threads should be used? (-1 for auto)")
                        .takes_value(true)
                        .default_value("-1"),
                ),
        )
        .subcommand(
            SubCommand::with_name("run_benchmark")
                .about("Runs a counter benchmark with ID 14.")
                .arg(
                    Arg::with_name("pb_disable")
                        .short("p")
                        .long("pb_disable")
                        .help("Disables the progress bar to avoid overhead."),
                )
                .arg(
                    Arg::with_name("pb_step")
                        .short("s")
                        .long("pb_step")
                        .help("Step size for the progress bar.")
                        .takes_value(true)
                        .default_value("1000"),
                )
                .arg(
                    Arg::with_name("iterations")
                        .short("i")
                        .long("iterations")
                        .help("How many counter iterations.")
                        .takes_value(true)
                        .default_value("100000"),
                )
                .arg(
                    Arg::with_name("threads")
                        .short("t")
                        .long("threads")
                        .help("How many threads should be used? (-1 for auto)")
                        .takes_value(true)
                        .default_value("-1"),
                ),
        )
        .subcommand(
            SubCommand::with_name("run_latency")
                .about("Runs a counter based latency check with ID 14.")
                .arg(
                    Arg::with_name("steps")
                        .short("s")
                        .long("steps")
                        .help("Testing from 2**0 to 2**s.")
                        .takes_value(true)
                        .default_value("28"),
                )
                .arg(
                    Arg::with_name("iterations")
                        .short("i")
                        .long("iterations")
                        .help("How many counter iterations.")
                        .takes_value(true)
                        .default_value("1000"),
                ),
        )
        .subcommand(
            SubCommand::with_name("test_copy")
                .about("Tests the copy to and from the device on memory 0."),
        )
        .get_matches();

    match match matches.subcommand() {
        ("version", Some(m)) => print_version(m),
        ("enum", Some(m)) => enum_devices(m),
        ("allocate", Some(m)) => allocate_devices(m),
        ("status", Some(m)) => print_status(m),
        ("run_counter", Some(m)) => run_counter(m),
        ("run_benchmark", Some(m)) => benchmark_counter(m),
        ("run_latency", Some(m)) => latency_benchmark(m),
        ("test_copy", Some(m)) => test_copy(m),
        ("benchmark_copy", Some(m)) => benchmark_copy(m),
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
