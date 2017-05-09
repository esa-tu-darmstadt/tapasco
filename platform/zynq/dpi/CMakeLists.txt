cmake_minimum_required(VERSION 2.6)
project(platform-zynq-dpi)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)

if (NOT EXISTS "$ENV{TPC_HOME}")
  message(FATAL_ERROR "Please set TPC_HOME environment variable to root directory of ThreadPoolComposer")
endif (NOT EXISTS "$ENV{TPC_HOME}")

set(ARCH "${CMAKE_SYSTEM_PROCESSOR}")
set(SRCDIR "../src")
set(CMNDIR "../../common")
set(GCMNDIR "${TPC_HOME}/common")
set(CMNSRCS "${CMNDIR}/src/platform_logging.c"
            "${CMNDIR}/src/platform_errors.c"
            "${SRCDIR}/platform_address_map.c"
            "${CMNDIR}/src/platform_version.c"
            "${GCMNDIR}/src/gen_queue.c")
set(COMPFLAGS "-Wall -Werror -g -O3 -std=gnu11")

set(DPI_LL rt pthread)
set(DPI_SERVER_SRCS "../include/platform_dpi.h" "${SRCDIR}/platform_server.c")
set(DPI_CLIENT_SRCS "../include/platform_dpi.h" "${SRCDIR}/platform_client.c")

find_path(VSIM_PATH NAMES "vsim")
find_path(SVDPI_HEADER_PATH NAMES "svdpi.h" PATHS "${VSIM_PATH}/../include")

include_directories("${SVDPI_HEADER_PATH}" "../include" "${CMNDIR}/include" "${GCMNDIR}/include")
set_source_files_properties(${CMNSRCS} ${SRCS} PROPERTIES COMPILE_FLAGS ${COMPFLAGS})

add_library(libplatform-server SHARED ${CMNSRCS} ${DPI_SERVER_SRCS})
add_library(libplatform-server-static STATIC ${CMNSRCS} ${DPI_SERVER_SRCS})
add_library(libplatform-client SHARED ${CMNSRCS} ${DPI_CLIENT_SRCS})
add_library(libplatform-client-static STATIC ${CMNSRCS} ${DPI_CLIENT_SRCS})

target_link_libraries(libplatform-server ${DPI_LL})

set_target_properties(libplatform-server PROPERTIES OUTPUT_NAME platform-server)
set_target_properties(libplatform-server-static PROPERTIES OUTPUT_NAME platform-server)

set_target_properties(libplatform-client PROPERTIES OUTPUT_NAME platform-client)
set_target_properties(libplatform-client-static PROPERTIES OUTPUT_NAME platform-client)

add_custom_command(OUTPUT "include/platform_dpi.h"
                   COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR}/include && ${VSIM_PATH}/vlib work && ${VSIM_PATH}/vlog -dpiheader platform_dpi.h -sv ../sv/platform-dpi.sv +incdir+../include && rm -rf work transcript)
