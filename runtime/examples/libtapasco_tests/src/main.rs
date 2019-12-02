extern crate snafu;
use snafu::{ErrorCompat, ResultExt, Snafu};

#[macro_use]
extern crate log;

extern crate tapasco;
use tapasco::device::Device;
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
            "ID: {} Name: {}, Vendor: {}, Product {}",
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
    let ids: Vec<DeviceId> = tlkm
        .device_enum()
        .context(TLKMInit {})?
        .into_iter()
        .map(|x| *x.id())
        .collect();

    for x in ids.iter() {
        println!("Allocating ID {} exclusively.", x);
        tlkm.device_create(*x, tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
            .context(TLKMInit {})?;
    }

    Ok(())
}

fn print_status(_: &ArgMatches) -> Result<()> {
    let mut tlkm = TLKM::new().context(TLKMInit {})?;
    for i in 0..tlkm.device_enum().context(TLKMInit)?.len() {
        let dev = Device::new(i as DeviceId).context(DeviceInit)?;
        println!("Device {}", i);
        println!("{:?}", dev);
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
        .get_matches();

    match match matches.subcommand() {
        ("version", Some(m)) => print_version(m),
        ("enum", Some(m)) => enum_devices(m),
        ("allocate", Some(m)) => allocate_devices(m),
        ("status", Some(m)) => print_status(m),
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
