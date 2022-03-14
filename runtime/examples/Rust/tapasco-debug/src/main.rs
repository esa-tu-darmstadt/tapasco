mod app;
mod ui;
use app::App;
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

fn main() -> Result<()> {
    env_logger::init();

    setup(&mut App::new().context(AppError {})?).context(UIError {})
}
