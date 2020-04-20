extern crate snafu;
use snafu::{ErrorCompat, ResultExt, Snafu};

#[macro_use]
extern crate log;

extern crate tapasco;

use tapasco::tlkm::*;

use clap::{App, AppSettings, ArgMatches, SubCommand};

use std::time::Instant;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Invalid subcommand"))]
    UnknownCommand {},
    #[snafu(display("Failed to initialize TLKM object: {}", source))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display("Failed to decode TLKM device: {}", source))]
    DeviceInit { source: tapasco::device::Error },
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
        for _ in 0..4 {
            pes.push(x.acquire_pe(14).context(DeviceInit)?);
        }
        for _ in (0..1000).step_by(4) {
            for pe in &mut pes.iter_mut() {
                x.start_pe(pe, vec![tapasco::device::PEParameter::Single64(1000)])
                    .context(DeviceInit)?;
            }
            for pe in &mut pes.iter_mut() {
                x.wait_for_completion(pe).context(DeviceInit)?;
            }
        }
        for pe in pes {
            x.release_pe(pe).context(DeviceInit)?;
        }
    }
    Ok(())
}

fn benchmark_counter(_: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    let devices = tlkm.device_enum().context(TLKMInit)?;
    for mut x in devices {
        x.create(
            &tlkm.file(),
            tapasco::tlkm::tlkm_access::TlkmAccessExclusive,
        )
        .context(DeviceInit {})?;
        let iterations = 300000;
        println!("Starting benchmark.");
        let now = Instant::now();
        for _ in 0..iterations {
            let mut pe = x.acquire_pe(14).context(DeviceInit)?;
            x.start_pe(&mut pe, vec![tapasco::device::PEParameter::Single64(1)])
                .context(DeviceInit)?;
            x.wait_for_completion(&mut pe).context(DeviceInit)?;
            x.release_pe(pe).context(DeviceInit)?;
        }
        println!(
            "Result: {} calls/s",
            iterations as f32 / now.elapsed().as_secs_f32()
        );
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
            SubCommand::with_name("run_benchmark").about("Runs a counter benchmark with ID 14."),
        )
        .get_matches();

    match match matches.subcommand() {
        ("version", Some(m)) => print_version(m),
        ("enum", Some(m)) => enum_devices(m),
        ("allocate", Some(m)) => allocate_devices(m),
        ("status", Some(m)) => print_status(m),
        ("run_counter", Some(m)) => run_counter(m),
        ("run_benchmark", Some(m)) => benchmark_counter(m),
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
