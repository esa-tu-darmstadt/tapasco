mod app;
mod ui;

use snafu::{ResultExt, Snafu};

#[derive(Debug, Snafu)]
enum Error {
    #[snafu(display(
        "Failed to initialize TLKM object: {}. Have you loaded the kernel module?",
        source
    ))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display(
        "Failed to initialize App: {}. Have you loaded the kernel module?",
        source
    ))]
    App { source: app::Error },

    #[snafu(display("Failed to initialize UI: {}. Have you checked your Terminal?", source))]
    UI { source: ui::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;

use structopt::StructOpt;

/// The interactive `TaPaSCo` Debugger can be used to retrieve information about the loaded
/// bitstream, monitor other `TaPaSCo` runtimes and write values to the registers of your PEs
#[derive(StructOpt, Debug)]
#[structopt(rename_all = "kebab-case")]
struct Opt {
    /// The Device ID of the FPGA you want to use if you got more than one
    #[structopt(short = "d", long = "device", default_value = "0")]
    device_id: u32,

    /// Specify the Access Mode as subcommand
    #[structopt(subcommand)]
    pub subcommand: Command,
}

#[derive(StructOpt, Debug, PartialEq)]
pub enum Command {
    /// Enter Monitor Mode where values cannot be modified, e.g. to monitor another runtime
    Monitor {},
    /// Enter Debug Mode where values can only be modified interactively in this debugger
    Debug {},
    /// Enter Unsafe Mode where values can be modified by this debugger and another runtime
    Unsafe {},
}

fn init() -> Result<()> {
    let Opt {
        device_id,
        subcommand,
    } = Opt::from_args();
    // Specify the Access Mode as subcommand
    ui::setup(&mut app::App::new(device_id, subcommand).context(App {})?).context(UI {})
}

fn main() {
    env_logger::init();

    match init() {
        Ok(_) => {}
        Err(e) => {
            eprintln!("An error occurred: {}", e);
            if let Some(backtrace) = snafu::ErrorCompat::backtrace(&e) {
                println!("{}", backtrace);
            }
        }
    };
}