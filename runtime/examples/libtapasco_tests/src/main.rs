extern crate snafu;
use snafu::{ErrorCompat, ResultExt, Snafu};

#[macro_use]
extern crate log;

extern crate tapasco;

use tapasco::tlkm::*;

use clap::{App, AppSettings, ArgMatches, SubCommand};

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
        let mut pe = x.acquire_pe(14).context(DeviceInit)?;
        for _ in 0..1000 {
            x.start_pe(&mut pe, vec![1000]).context(DeviceInit)?;
            x.wait_for_completion(&mut pe).context(DeviceInit)?;
        }
        x.release_pe(pe).context(DeviceInit)?;
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
        .get_matches();

    match match matches.subcommand() {
        ("version", Some(m)) => print_version(m),
        ("enum", Some(m)) => enum_devices(m),
        ("allocate", Some(m)) => allocate_devices(m),
        ("status", Some(m)) => print_status(m),
        ("run_counter", Some(m)) => run_counter(m),
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
