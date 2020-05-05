// build.rs
extern crate cbindgen;

use std::env;

fn main() {
    prost_build::compile_protos(&["src/status_core.proto"], &["src/"]).unwrap();

    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("tapasco.h");
}
