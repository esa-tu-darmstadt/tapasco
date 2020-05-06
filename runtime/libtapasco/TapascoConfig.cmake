project(tapasco VERSION 2.0 LANGUAGES C CXX)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CARGO_CMD cargo build)
    set(TARGET_DIR "debug")
else ()
    set(CARGO_CMD cargo build --release)
    set(TARGET_DIR "release")
endif ()

add_library(tapasco SHARED ${CMAKE_CURRENT_LIST_DIR}/unused.c)

add_custom_command(TARGET tapasco POST_BUILD
    COMMENT "Compiling tapasco module in ${CMAKE_CURRENT_LIST_DIR}"
    COMMAND CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR} ${CARGO_CMD} --manifest-path=${CMAKE_CURRENT_LIST_DIR}/Cargo.toml
    COMMENT "cp -f ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/libtapasco.so ${CMAKE_CURRENT_BINARY_DIR}/"
    COMMAND cp -f ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/libtapasco.so ${CMAKE_CURRENT_BINARY_DIR}/
    )

target_include_directories(tapasco PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/)
