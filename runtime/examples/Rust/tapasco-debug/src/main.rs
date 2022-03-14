mod app;
use app::App;

mod ui;
use ui::setup;

use snafu::{ResultExt, Snafu};

#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum Error {
    #[snafu(display("Failed to initialize TLKM object: {}. Have you loaded the kernel module?", source))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display("Failed to initialize App: {}. Have you loaded the kernel module?", source))]
    AppError { source: app::Error },

    #[snafu(display("Failed to initialize UI: {}. Have you checked your Terminal?", source))]
    UIError { source: ui::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;

use env_logger;


fn init() -> Result<()> {
    setup(&mut App::new().context(AppError {})?).context(UIError {})
}
fn main() {
    env_logger::init();

    match init() {
        Ok(_) => {},
        Err(e) => {
            eprintln!("An error occurred: {}", e);
            if let Some(backtrace) = snafu::ErrorCompat::backtrace(&e) {
                println!("{}", backtrace);
            }
        },
    };
}
