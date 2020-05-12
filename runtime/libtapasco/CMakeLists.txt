cmake_minimum_required(VERSION 3.0)

project(tapasco VERSION 2.0 LANGUAGES C CXX)

SET(CPACK_GENERATOR "RPM" "DEB" "TGZ" "ZIP" "STGZ" "TBZ2")
SET(CPACK_PACKAGE_CONTACT "tapasco@esa.tu-darmstadt.de")

SET(CPACK_PACKAGE_VERSION_MAJOR 2020)
SET(CPACK_PACKAGE_VERSION_MINOR 4)
SET(CPACK_PACKAGE_VERSION_PATCH 0)

INCLUDE(CPack)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CARGO_CMD cargo build)
    set(TARGET_DIR "debug")
else ()
    set(CARGO_CMD cargo build --release)
    set(TARGET_DIR "release")
endif ()

add_library(tapasco SHARED ${CMAKE_CURRENT_SOURCE_DIR}/unused.c ${CMAKE_CURRENT_SOURCE_DIR}/src/tapasco.hpp)

add_custom_command(TARGET tapasco POST_BUILD
    COMMENT "Compiling tapasco module in ${CMAKE_CURRENT_LIST_DIR}"
    COMMAND CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR} ${CARGO_CMD} --manifest-path=${CMAKE_CURRENT_LIST_DIR}/Cargo.toml
    COMMAND cp -f ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/libtapasco.so ${CMAKE_CURRENT_BINARY_DIR}/
    )

target_include_directories(tapasco PUBLIC $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/tapasco> $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/> $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/>)

set_property(TARGET tapasco PROPERTY PUBLIC_HEADER ${CMAKE_CURRENT_BINARY_DIR}/tapasco.h ${CMAKE_CURRENT_BINARY_DIR}/tapasco_inner.hpp ${CMAKE_CURRENT_SOURCE_DIR}/src/tapasco.hpp)

include(GNUInstallDirs)

install(TARGETS tapasco EXPORT TapascoConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/)

install(EXPORT TapascoConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tapasco FILE TapascoConfig.cmake)