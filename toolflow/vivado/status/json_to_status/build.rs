fn main() {
    prost_build::compile_protos(&["src/status_core.proto"], &["src/"]).unwrap();
}
