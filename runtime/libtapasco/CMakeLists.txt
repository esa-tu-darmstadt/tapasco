cmake_minimum_required(VERSION 3.0)

project(
  tapasco
  VERSION 2.0
  LANGUAGES C CXX)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CARGO_CMD cargo build)
  set(TARGET_DIR "debug")
else()
  set(CARGO_CMD cargo build --release)
  set(TARGET_DIR "release")
endif()

add_library(tapasco SHARED ${CMAKE_CURRENT_BINARY_DIR}/unused.c)

add_custom_target(
  tapasco_rust ALL
  CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR} ${CARGO_CMD}
  --manifest-path=${CMAKE_CURRENT_LIST_DIR}/Cargo.toml
  COMMENT "Compiling tapasco module in ${CMAKE_CURRENT_LIST_DIR}")

add_dependencies(tapasco tapasco_rust)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/unused.c
  COMMENT "Creating dummy file to force build"
  COMMAND echo "" | tee ${CMAKE_CURRENT_BINARY_DIR}/unused.c)

add_custom_command(
  TARGET tapasco
  POST_BUILD
  COMMENT "Replacing libtapasco.so"
  COMMAND cp -f ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/libtapasco.so
          ${CMAKE_CURRENT_BINARY_DIR}/
  COMMAND rm -f ${CMAKE_CURRENT_BINARY_DIR}/unused.c
          )

target_include_directories(
  tapasco
  PUBLIC $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/tapasco>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/>)

set_property(
  TARGET tapasco
  PROPERTY PUBLIC_HEADER ${CMAKE_CURRENT_BINARY_DIR}/tapasco.h
           ${CMAKE_CURRENT_BINARY_DIR}/tapasco_inner.hpp
           ${CMAKE_CURRENT_SOURCE_DIR}/src/tapasco.hpp)

include(GNUInstallDirs)

install(
  TARGETS tapasco
  EXPORT TapascoConfig
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/cmake
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/)
