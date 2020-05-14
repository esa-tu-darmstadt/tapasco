set(CARGO_GREP grep -oP \"note: native-static-libs: \\K.+\")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CARGO_CMD RUSTFLAGS="--print=native-static-libs" cargo build)
  set(TARGET_DIR "debug")
else()
  set(CARGO_CMD RUSTFLAGS="--print=native-static-libs" cargo build --release)
  set(TARGET_DIR "release")
endif()

add_custom_target(
  tapasco_rust ALL
  CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR}
  ${CARGO_CMD}
  --manifest-path=${CMAKE_CURRENT_LIST_DIR}/Cargo.toml
  2>&1
  |
  tee
  ${CMAKE_CURRENT_BINARY_DIR}/cargo.log
  COMMAND ${CARGO_GREP} ${CMAKE_CURRENT_BINARY_DIR}/cargo.log 2>&1 | tee
          ${CMAKE_CURRENT_BINARY_DIR}/rust_links.txt
  COMMAND ${CMAKE_COMMAND} -E echo \" string
          (STRIP \\\"`cat ${CMAKE_CURRENT_BINARY_DIR}/rust_links.txt`\\\"
           RUST_LINK) \" | tee ${CMAKE_CURRENT_BINARY_DIR}/rust_links2.cmake
  COMMAND
    ${CMAKE_COMMAND} -E compare_files
    ${CMAKE_CURRENT_BINARY_DIR}/rust_links2.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/rust_links.cmake\; if [ $$? -ne 0 ] \; then
    ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/rust_links2.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/rust_links.cmake\; fi\;
  COMMENT "Compiling tapasco module in ${CMAKE_CURRENT_LIST_DIR}")
