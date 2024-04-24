// Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
//
// This file is part of TaPaSCo
// (see https://github.com/esa-tu-darmstadt/tapasco).
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//

#[macro_use]
extern crate log;
#[macro_use]
extern crate common_failures;
#[macro_use]
extern crate failure;
extern crate env_logger;
extern crate hex;
extern crate regex;
extern crate serde;
extern crate serde_json;

use clap::{arg, Command};
use common_failures::prelude::*;
use prost::Message;
use regex::Regex;
use serde::Deserialize;
use std::collections::HashMap;
use std::fs;
use std::fs::File;
use std::path::Path;
use std::ffi::OsStr;
use std::io::BufReader;
use std::u64;

pub mod status {
    include!(concat!(env!("OUT_DIR"), "/tapasco.status.rs"));
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Composition {
    Type: String,
    SlotId: u64,
    Kernel: u64,
    Offset: String,
    Size: String,
    VLNV: String,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Version {
    Software: String,
    Year: u64,
    Release: u64,
    ExtraVersion: String,
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
    Size: String,
    Offset: String,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Debug {
    Name: String,
    Size: String,
    Offset: String,
    PE_ID: u64,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct InterruptMapping {
    Name: String,
    Mapping: u64,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct ComponentAddresses {
    Base: String,
    Components: Vec<Component>,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct ArchitectureAddresses {
    Base: String,
    Composition: Vec<Composition>,
}

#[allow(non_snake_case)]
#[derive(Deserialize, Debug)]
struct Design {
    Architecture: ArchitectureAddresses,
    Timestamp: u64,
    Versions: Vec<Version>,
    Clocks: Vec<Clocks>,
    Platform: ComponentAddresses,
    Debug: Vec<Debug>,
    Interrupts: Vec<InterruptMapping>,
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
    for c in hex_data.chunks(16) {
        let b: Vec<_> = c.chunks(2).rev().into_iter().collect();
        let joined: Vec<String> = b.iter().map(|x| x.into_iter().collect()).collect();
        let joined = joined.join("");
        if init_vec.is_empty() {
            init_vec = format!("{}", joined);
        } else {
            init_vec = format!(
                "{}
{}",
                init_vec, joined
            );
        }
    }

    trace!("Use .mem output format");
    let coe_content = format!(
        "@0
{}", init_vec
    );
    trace!("Generated {}", coe_content);
    info!("Writing to file {:?}", filename);
    fs::write(filename, coe_content).io_read_context(filename)?;

    Ok(())
}

fn write_coe_file(filename: &Path, data: &[u8]) -> Result<()> {
    info!("Generating hex representation of flatbuffer");
    let hex_data: Vec<char> = hex::encode(data).chars().collect();
    let mut init_vec = String::new();
    for c in hex_data.chunks(16) {
        let b: Vec<_> = c.chunks(2).rev().into_iter().collect();
        let joined: Vec<String> = b.iter().map(|x| x.into_iter().collect()).collect();
        let joined = joined.join("");
        if init_vec.is_empty() {
            init_vec = format!("{}", joined);
        } else {
            init_vec = format!(
                "{},
                {}",
                init_vec, joined
            );
        }
    }

    trace!("Use .coe output format");
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

    let matches = Command::new("json_to_status")
        .arg_required_else_help(true)
        .version("0.1")
        .about("Converts a JSON file describing a TaPaSCo Design into a flatbuffer binary format readable by Vivado as MEM file.")
        .arg(
            arg!(<INPUT>)
                .help("JSON file generated from TaPaSCo design flow")
                .required(true),
        )
        .arg(
            arg!(<OUTPUT>)
                .help("Hex encoded file {.coe or .mem} for use in BRAM initialization")
                .required(true),
        )
        .arg(arg!(-b --binary).help("Output binary representation of ProtoBuf as well."))
        .get_matches();

    let input_file_name = matches
        .get_one::<String>("INPUT")
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

    let arch_base = from_hex_str(&json.Architecture.Base)?;

    let platform_base = from_hex_str(&json.Platform.Base)?;

    info!(
        "Architecture start: 0x{:X}, Platform start: 0x{:X}",
        arch_base, platform_base
    );

    let mut debugs: HashMap<u64, status::Platform> = HashMap::new();
    for debug in json.Debug {
        let offset = from_hex_str(&debug.Offset)?;
        let size = from_hex_str(&debug.Size)?;
        let name = &debug.Name;
        let pe_id = &debug.PE_ID;
        debugs.insert(
            *pe_id,
            status::Platform {
                name: name.clone(),
                offset: offset,
                size: size,
                interrupts: Vec::new(),
            },
        );
    }

    let mut interrupts_pes: HashMap<u64, Vec<status::Interrupt>> = HashMap::new();
    let mut interrupts_plat: HashMap<String, Vec<status::Interrupt>> = HashMap::new();

    let pe_re = Regex::new(r"PE_(\d+)_(\d+)")?;
    let platform_re = Regex::new(r"(PLATFORM_COMPONENT_.*)_(.*)")?;

    for interrupt in json.Interrupts {
        if pe_re.is_match(&interrupt.Name) {
            let g = pe_re.captures(&interrupt.Name).unwrap();
            let peid = u64::from_str_radix(&g[1], 10).unwrap();

            let v = match interrupts_pes.get_mut(&peid) {
                Some(x) => x,
                None => {
                    interrupts_pes.insert(peid, Vec::new());
                    interrupts_pes.get_mut(&peid).unwrap()
                }
            };

            v.push(status::Interrupt {
                mapping: interrupt.Mapping,
                name: g[2].to_string(),
            });
        } else if platform_re.is_match(&interrupt.Name) {
            let g = platform_re.captures(&interrupt.Name).unwrap();
            let component = &g[1];
            let name = &g[2];

            let v = match interrupts_plat.get_mut(component) {
                Some(x) => x,
                None => {
                    interrupts_plat.insert(component.to_string(), Vec::new());
                    interrupts_plat.get_mut(component).unwrap()
                }
            };

            v.push(status::Interrupt {
                mapping: interrupt.Mapping,
                name: name.to_string(),
            });
        } else {
            trace!("Unknown interrupt mapping {:?}.", interrupt);
        }
    }

    let mut pes: Vec<status::Pe> = Vec::new();
    let mut peid = 0;
    for pe in json.Architecture.Composition {
        let addr = from_hex_str(&pe.Offset)?;
        let size = from_hex_str(&pe.Size)?;
        if pe.Type == "Memory" {
            let last = pes
                .last_mut()
                .ok_or_else(|| JSONToStatusError::MemoryWithoutPE)?;
            last.local_memory = Some(status::MemoryArea {
                base: addr,
                size: size,
            });
        } else {
            let int = match interrupts_pes.remove(&peid) {
                Some(x) => x,
                None => Vec::new(),
            };
            pes.push(status::Pe {
                name: pe.VLNV,
                id: pe.Kernel as u32,
                offset: addr,
                size: size,
                local_memory: None,
                debug: debugs.remove(&pe.SlotId),
                interrupts: int,
            });
            peid += 1;
        }
    }

    let clocks: Vec<_> = json
        .Clocks
        .iter()
        .map(|x| status::Clock {
            name: x.Domain.clone(),
            frequency_mhz: x.Frequency as u32,
        })
        .collect();

    let platforms: Vec<_> = json
        .Platform
        .Components
        .iter()
        .map(|x| status::Platform {
            name: x.Name.clone(),
            offset: from_hex_str(&x.Offset).unwrap(),
            size: from_hex_str(&x.Size).unwrap(),
            interrupts: match interrupts_plat.remove(&x.Name) {
                Some(x) => x,
                None => Vec::new(),
            },
        })
        .collect();

    let versions: Vec<_> = json
        .Versions
        .iter()
        .map(|x| status::Version {
            software: x.Software.clone(),
            year: x.Year as u32,
            release: x.Release as u32,
            extra_version: x.ExtraVersion.clone(),
        })
        .collect();

    let mut max_offset = 0;
    let mut max_size = 0;
    for pe in &pes {
        if pe.offset >= max_offset {
            max_offset = pe.offset;
            max_size = pe.size;
        }
        if let Some(i) = &pe.local_memory {
            if i.base >= max_offset {
                max_offset = i.base;
                max_size = i.size;
            }
        }
    }
    let arch_size = max_offset + max_size;

    max_offset = 0;
    max_size = 0;
    for plat in &platforms {
        if plat.offset >= max_offset {
            max_offset = plat.offset;
            max_size = plat.size;
        }
    }
    let platform_size = max_offset + max_size;

    let status = status::Status {
        arch_base: Some(status::MemoryArea {
            base: arch_base,
            size: arch_size,
        }),
        platform_base: Some(status::MemoryArea {
            base: platform_base,
            size: platform_size,
        }),
        timestamp: json.Timestamp,
        pe: pes,
        platform: platforms,
        clocks: clocks,
        versions: versions,
    };

    let mut buf: Vec<u8> = Vec::new();
    status.encode_length_delimited(&mut buf)?;

    info!(
        "Successfully generated binary protobuf representation: {} bytes",
        status.encoded_len()
    );

    let output_file_name = matches
        .get_one::<String>("OUTPUT")
        .ok_or_else(|| JSONToStatusError::MissingOutput)?;

    if matches.contains_id("binary") {
        let ofn = format!("{}.bin", output_file_name);
        let ofp = Path::new(&ofn);
        info!("Outputting binary as well to {}", ofn);
        fs::write(ofp, &buf).io_read_context(ofp)?;
    }

    let output_path = Path::new(output_file_name);
    if output_path.extension() == Some(OsStr::new("mem")) {
        write_mem_file(output_path, &buf)
    } else {
        write_coe_file(output_path, &buf)
    }
}

quick_main!(run);
