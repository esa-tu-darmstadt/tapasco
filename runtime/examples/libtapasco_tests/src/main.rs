extern crate crossbeam;
extern crate num_cpus;
extern crate rayon;
extern crate snafu;
extern crate tapasco;

use average::{concatenate, Estimate, Max, MeanWithError, Min};
use crossbeam::thread;
use snafu::{ErrorCompat, ResultExt, Snafu};
use std::io;
use std::io::Write;
use std::sync::Arc;
use tapasco::device::DataTransferPrealloc;
use uom::si::f32::*;
use uom::si::frequency::megahertz;
use uom::si::time::microsecond;
use uom::si::time::nanosecond;

#[macro_use]
extern crate log;

extern crate indicatif;
use indicatif::ProgressBar;

use tapasco::tlkm::*;

#[macro_use]
extern crate clap;

use clap::{App, AppSettings, Arg, ArgMatches, SubCommand};

use std::time::Instant;

extern crate uom;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Allocator Error: {}", source))]
    AllocatorError { source: tapasco::allocator::Error },

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

            pb.finish();
            println!(
                "Result with {} Threads: {} calls/s",
                cur_threads,
                iterations_cur as f32 / now.elapsed().as_secs_f32()
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
        let a = mem
            .allocator()
            .lock()?
            .allocate(256 * 4)
            .context(AllocatorError)?;

        let mut pe = x.acquire_pe(11).context(DeviceInit)?;

        pe.start(vec![
            tapasco::device::PEParameter::Single64(1),
            tapasco::device::PEParameter::DataTransferPrealloc(DataTransferPrealloc {
                data: vec![0 as u8; 256 * 4],
                device_address: a,
                from_device: true,
                to_device: false,
                free: false,
                memory: mem.clone(),
            }),
        ])
        .context(JobError)?;
        println!("{:?}", pe.release(true).context(JobError)?);

        let mut pe = x.acquire_pe(9).context(DeviceInit)?;

        pe.start(vec![
            tapasco::device::PEParameter::Single64(1),
            tapasco::device::PEParameter::DataTransferPrealloc(DataTransferPrealloc {
                data: vec![0 as u8; 256 * 4],
                device_address: a,
                from_device: true,
                to_device: false,
                free: false,
                memory: mem.clone(),
            }),
        ])
        .context(JobError)?;
        println!("{:?}", pe.release(true).context(JobError)?);

        mem.allocator().lock()?.free(a).context(AllocatorError)?;
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
