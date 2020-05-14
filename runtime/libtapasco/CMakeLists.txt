cmake_minimum_required(VERSION 3.0)

project(
  tapasco
  VERSION 2.0
  LANGUAGES C CXX)

set(CARGO_GREP grep -oP \"note: native-static-libs: \\K.+\")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CARGO_CMD RUSTFLAGS="--print=native-static-libs" cargo build)
  set(TARGET_DIR "debug")
else()
  set(CARGO_CMD RUSTFLAGS="--print=native-static-libs" cargo build --release)
  set(TARGET_DIR "release")
endif()

add_library(tapasco STATIC ${CMAKE_CURRENT_BINARY_DIR}/unused.c)

add_custom_target(
  tapasco_rust ALL
  CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR} ${CARGO_CMD}
  --manifest-path=${CMAKE_CURRENT_LIST_DIR}/Cargo.toml 2>&1 | tee ${CMAKE_CURRENT_BINARY_DIR}/cargo.log
  COMMENT "Compiling tapasco module in ${CMAKE_CURRENT_LIST_DIR}")

add_dependencies(tapasco tapasco_rust)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/unused.c ${CMAKE_CURRENT_BINARY_DIR}/rust_links.txt
  COMMENT "Creating dummy file to force build"
  COMMAND echo "" | tee ${CMAKE_CURRENT_BINARY_DIR}/unused.c
  COMMAND ${CARGO_GREP} ${CMAKE_CURRENT_BINARY_DIR}/cargo.log 2>&1 | tee ${CMAKE_CURRENT_BINARY_DIR}/rust_links.txt)

add_custom_command(
  TARGET tapasco
  POST_BUILD
  COMMENT "Replacing libtapasco.a"
  COMMAND cp -f ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/libtapasco.a
          ${CMAKE_CURRENT_BINARY_DIR}/
  COMMAND rm -f ${CMAKE_CURRENT_BINARY_DIR}/unused.c)

target_include_directories(
  tapasco
  PUBLIC $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/tapasco>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/>)

file(READ ${CMAKE_CURRENT_BINARY_DIR}/rust_links.txt RUST_LINK_FLAGS_INNER)
string(STRIP "${RUST_LINK_FLAGS_INNER}" RUST_LINK_FLAGS)

target_link_libraries(tapasco PUBLIC ${RUST_LINK_FLAGS})

set_property(
  TARGET tapasco
  PROPERTY PUBLIC_HEADER ${CMAKE_CURRENT_BINARY_DIR}/tapasco.h
           ${CMAKE_CURRENT_BINARY_DIR}/tapasco_inner.hpp
           ${CMAKE_CURRENT_SOURCE_DIR}/src/tapasco.hpp)

include(GNUInstallDirs)

install(
  TARGETS tapasco
  EXPORT tapasco-export
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/)

install(
  EXPORT tapasco-export
  FILE TapascoConfig.cmake
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/cmake)
