#[macro_use]
extern crate log;
#[macro_use]
extern crate common_failures;
#[macro_use]
extern crate failure;
extern crate env_logger;
extern crate hex;
extern crate serde;
extern crate serde_json;

use std::u64;

use common_failures::prelude::*;

use serde::Deserialize;

use std::fs;
use std::fs::File;
use std::path::Path;

use std::io::BufReader;

use clap::{App, AppSettings, Arg};

mod status_core_generated;
pub use status_core_generated::*;

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Composition {
    Type: String,
    SlotId: u64,
    Kernel: u64,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Version {
    Software: String,
    Year: u64,
    Release: u64,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Clocks {
    Domain: String,
    Frequency: u64,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Component {
    Name: String,
    Address: String,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct ComponentAddresses {
    Base: String,
    Components: Vec<Component>,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct PEAddresses {
    Base: String,
    Offsets: Vec<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct BaseAddresses {
    Architecture: PEAddresses,
    Platform: ComponentAddresses,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Design {
    Composition: Vec<Composition>,
    Timestamp: u64,
    Versions: Vec<Version>,
    Clocks: Vec<Clocks>,
    BaseAddresses: BaseAddresses,
}

#[derive(Debug, Fail)]
pub enum JSONToStatusError {
    #[fail(display = "Invalid json format for input file {}", filename)]
    JSONFormatError {
        #[fail(cause)]
        err: serde_json::Error,
        filename: String,
    },

    #[fail(display = "Could not convert HEX string to u64")]
    HexToIntError {
        #[fail(cause)]
        err: std::num::ParseIntError,
    },

    #[fail(
        display = "Missing input argument. This error should've been caught be the CLI parser."
    )]
    MissingInput,

    #[fail(
        display = "Missing output argument. This error should've been caught be the CLI parser."
    )]
    MissingOutput,

    #[fail(display = "Found local memory but no preceeding PE.")]
    MemoryWithoutPE,
}

impl From<std::num::ParseIntError> for JSONToStatusError {
    fn from(err: std::num::ParseIntError) -> JSONToStatusError {
        JSONToStatusError::HexToIntError { err: err }
    }
}

impl From<serde_json::Error> for JSONToStatusError {
    fn from(err: serde_json::Error) -> JSONToStatusError {
        JSONToStatusError::JSONFormatError {
            err: err,
            filename: "UNKNOWN".to_string(),
        }
    }
}

impl JSONToStatusError {
    fn from_filename(filename: String) -> impl Fn(serde_json::Error) -> JSONToStatusError {
        move |x| JSONToStatusError::JSONFormatError {
            err: x,
            filename: filename.clone(),
        }
    }
}

fn from_hex_str(s: &String) -> Result<u64> {
    u64::from_str_radix(s.trim_start_matches("0x"), 16)
        .map_err(JSONToStatusError::from)
        .map_err(failure::Error::from)
}

fn write_mem_file(filename: &Path, data: &[u8]) -> Result<()> {
    info!("Generating hex representation of flatbuffer");
    let hex_data: Vec<char> = hex::encode(data).chars().collect();
    let mut init_vec = String::new();
    for c in hex_data.chunks(2) {
        let cstr = c.iter().cloned().collect::<String>();
        if init_vec.is_empty() {
            init_vec = format!("{}", cstr);
        } else {
            init_vec = format!(
                "{},
                {}",
                init_vec, cstr
            );
        }
    }

    let coe_content = format!(
        "memory_initialization_radix=16;
    memory_initialization_vector=
    {};
    ",
        init_vec
    );
    trace!("Generated {}", coe_content);
    info!("Writing to file {:?}", filename);
    fs::write(filename, coe_content).io_read_context(filename)?;

    Ok(())
}

fn run() -> Result<()> {
    env_logger::init();

    let matches = App::new("libplatform_tests")
        .setting(AppSettings::ArgRequiredElseHelp)
        .version("0.1")
        .about("Converts a JSON file describing a TaPaSCo Design into a flatbuffer binary format readable by Vivado as MEM file.")
        .arg(
            Arg::with_name("INPUT")
                .help("JSON file generated from TaPaSCo design flow")
                .takes_value(true)
                .required(true),
        )
        .arg(
            Arg::with_name("OUTPUT")
                .help("Hex encoded file for use in BRAM initialization")
                .takes_value(true)
                .required(true),
        )
        .get_matches();

    let input_file_name = matches
        .value_of("INPUT")
        .ok_or_else(|| JSONToStatusError::MissingInput)?;
    info!("Opening input JSON file {}", input_file_name);
    let json_input = File::open(input_file_name)?;
    let json_reader = BufReader::new(json_input);
    info!("Parsing JSON file {}", input_file_name);

    let json: Design = serde_json::from_reader(json_reader).map_err(
        JSONToStatusError::from_filename(input_file_name.to_string()),
    )?;

    info!("Successfully parsed JSON file {}", input_file_name);
    trace!("{} => {:#?}", input_file_name, json);

    info!("Starting to build the binary representation");

    let arch_base = from_hex_str(&json.BaseAddresses.Architecture.Base)?;

    let platform_base = from_hex_str(&json.BaseAddresses.Platform.Base)?;

    info!(
        "Architecture start: 0x{:X}, Platform start: 0x{:X}",
        arch_base, platform_base
    );

    let mut builder = flatbuffers::FlatBufferBuilder::new();

    let mut pes: Vec<tapasco::PEArgs> = Vec::new();
    for pe in json.Composition {
        let addr = from_hex_str(&json.BaseAddresses.Architecture.Offsets[pe.SlotId as usize])?;
        if pe.Type == "Memory" {
            let last = pes
                .last_mut()
                .ok_or_else(|| JSONToStatusError::MemoryWithoutPE)?;
            last.has_local_memory = true;
            last.local_memory = addr
        } else {
            pes.push(tapasco::PEArgs {
                name: Some(builder.create_string("UNNAMED KERNEL")),
                id: pe.Kernel as u32,
                offset: addr,
                has_local_memory: false,
                local_memory: 0,
            });
        }
    }

    let pes_built: Vec<_> = pes
        .iter()
        .map(|x| tapasco::PE::create(&mut builder, &x))
        .collect();

    let pes_build_done = builder.create_vector(&pes_built);

    let clocks: Vec<_> = json
        .Clocks
        .iter()
        .map(|x| tapasco::ClockArgs {
            name: Some(builder.create_string(&x.Domain)),
            frequency_mhz: x.Frequency as u16,
        })
        .collect();

    let clocks: Vec<_> = clocks
        .iter()
        .map(|x| tapasco::Clock::create(&mut builder, &x))
        .collect();

    let clocks = builder.create_vector(&clocks);

    let platforms: Vec<_> = json
        .BaseAddresses
        .Platform
        .Components
        .iter()
        .map(|x| tapasco::PlatformArgs {
            name: Some(builder.create_string(&x.Name)),
            offset: from_hex_str(&x.Address).unwrap(),
        })
        .collect();

    let platforms: Vec<_> = platforms
        .iter()
        .map(|x| tapasco::Platform::create(&mut builder, &x))
        .collect();

    let platforms = builder.create_vector(&platforms);

    let versions: Vec<_> = json
        .Versions
        .iter()
        .map(|x| tapasco::VersionArgs {
            software: Some(builder.create_string(&x.Software)),
            year: x.Year as u16,
            release: x.Release as u16,
        })
        .collect();

    let versions: Vec<_> = versions
        .iter()
        .map(|x| tapasco::Version::create(&mut builder, &x))
        .collect();

    let versions = builder.create_vector(&versions);

    let status = tapasco::Status::create(
        &mut builder,
        &tapasco::StatusArgs {
            arch_base: arch_base,
            platform_base: platform_base,
            timestamp: json.Timestamp,
            pe: Some(pes_build_done),
            platform: Some(platforms),
            clocks: Some(clocks),
            versions: Some(versions),
        },
    );
    builder.finish(status, None);
    info!("Generating binary flatbuffer representation.");
    let buf = builder.finished_data();
    info!(
        "Successfully generated binary flatbuffer representation: {} bytes",
        buf.len()
    );

    let output_file_name = matches
        .value_of("OUTPUT")
        .ok_or_else(|| JSONToStatusError::MissingOutput)?;

    let output_path = Path::new(output_file_name);
    write_mem_file(output_path, buf)
}

quick_main!(run);
