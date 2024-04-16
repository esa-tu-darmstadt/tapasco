// The app module holds all state (of TaPaSCo) and interacts with PEs
mod app;
// The ui module handles (key press) events and displaying the app in the TUI
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

use clap::Parser;

// TODO: 1. When issue #296 is fixed, remove the paragraph about the `EMFILE` error.
/// The interactive `TaPaSCo` Debugger can be used to retrieve information about the loaded
/// bitstream, monitor other `TaPaSCo` runtimes and write values to the registers of your PEs
///
/// Currently due to a `libtapasco` bug where DMA Buffers, Interrupts, etc. are allocated even in monitor mode, you will have to start your other runtime twice, where the first time the `EMFILE` error is to be expected.
#[derive(Parser, Debug)]
#[structopt(rename_all = "kebab-case")]
struct Args {
    /// The Device ID of the FPGA you want to use if you got more than one
    #[structopt(short = 'd', long = "device", default_value = "0")]
    device_id: u32,

    /// Specify the Access Mode as subcommand
    #[structopt(subcommand)]
    pub subcommand: Command,
}

#[derive(Parser, Debug, PartialEq)]
pub enum Command {
    /// Enter Monitor Mode where values cannot be modified, e.g. to monitor another runtime
    Monitor {},
    // TODO: 2. When issue #296 is fixed, enable debug mode again.
    // /// Enter Debug Mode where values can only be modified interactively in this debugger
    // Debug {},
    /// Enter Unsafe Mode where values can be modified by this debugger and another runtime
    Unsafe {},
}

fn init() -> Result<()> {
    // Parse command line arguments:
    let Args {
        device_id,
        subcommand,
    } = Args::parse();

    // Specify the Access Mode as subcommand and setup the App and UI
    ui::setup(&mut app::App::new(device_id, subcommand).context(AppSnafu {})?).context(UISnafu {})
}

fn main() {
    // Initialize the env logger. Export `RUST_LOG=debug` to see logs on stderr.
    env_logger::init();

    // Initialize app and error reporting with Snafu:
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
