// build.rs
extern crate cbindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=src/ffi.rs");
    println!("cargo:rerun-if-changed=src/status_core.proto");

    prost_build::compile_protos(&["src/status_core.proto"], &["src/"]).unwrap();

    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    let package_name = env::var("CARGO_PKG_NAME").unwrap();
    let output_file = target_dir()
        .join(format!("{}.h", package_name))
        .display()
        .to_string();

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(&output_file);

    let output_file2 = target_dir()
        .join(format!("{}_inner.hpp", package_name))
        .display()
        .to_string();

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_language(cbindgen::Language::Cxx)
        .with_namespace("tapasco")
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(&output_file2);
}

/// Find the location of the `target/` directory. Note that this may be
/// overridden by `cmake`, so we also need to check the `CARGO_TARGET_DIR`
/// variable.
fn target_dir() -> PathBuf {
    if let Ok(target) = env::var("CARGO_TARGET_DIR") {
        PathBuf::from(target)
    } else {
        PathBuf::from(env::var("OUT_DIR").unwrap())
    }
}
