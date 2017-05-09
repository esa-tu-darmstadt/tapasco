cmake_minimum_required(VERSION 2.6)
project(arch-baseline)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)

if (NOT EXISTS "$ENV{TPC_HOME}")
  message(FATAL_ERROR "Please set TPC_HOME environment variable to root directory of ThreadPoolComposer")
endif (NOT EXISTS "$ENV{TPC_HOME}")

include ("$ENV{TPC_HOME}/cmake/ThreadPoolComposer.cmake")

set(SRCDIR "src")
set(CMNDIR "../common/src")
set(GCMNDIR "${TPC_HOME}/common")
set(PLATFORMDIR "${TPC_HOME}/platform")
set(LIBPLATFORM_STATIC "${TPC_HOME}/platform/lib/${TPC_TARGET}/static/libplatform.a")

set(BASELINE_SOURCES "${SRCDIR}/tpc_init.c"
                     "${SRCDIR}/tpc_device.c"
                     "${SRCDIR}/tpc_address_map.c")
set(COMMON_SOURCES "${CMNDIR}/tpc_logging.c"
                   "${CMNDIR}/tpc_errors.c"
                   "${CMNDIR}/tpc_functions.c"
                   "${CMNDIR}/tpc_scheduler.c"
                   "${CMNDIR}/tpc_jobs.c"
                   "${CMNDIR}/tpc_status.c"
                   "${CMNDIR}/tpc_version.c"
                   "${GCMNDIR}/src/gen_queue.c")
set(TPC_LIBS_DIR "${TPC_HOME}/arch/lib")

include_directories("include" "../common/include" "${PLATFORMDIR}/common/include" "${GCMNDIR}/include")
link_directories("${PLATFORMDIR}/lib/${TPC_TARGET}")

add_definitions(-DUSE_ASSERTIONS)

set_source_files_properties(${BASELINE_SOURCES} ${COMMON_SOURCES} PROPERTIES COMPILE_FLAGS "-g -O3 -Wall -Werror -std=gnu11")
add_library(tpc SHARED ${BASELINE_SOURCES} ${COMMON_SOURCES})
add_library(libtpc-static STATIC ${BASELINE_SOURCES} ${COMMON_SOURCES} ${LIBPLATFORM_STATIC})

target_link_libraries(tpc platform atomic pthread)
set_target_properties(libtpc-static PROPERTIES OUTPUT_NAME tpc)

install(TARGETS tpc libtpc-static
        LIBRARY DESTINATION "lib/${TPC_TARGET}"
        ARCHIVE DESTINATION "lib/${TPC_TARGET}/static")

get_filename_component(LIBSDIR "lib" REALPATH)
add_custom_command(OUTPUT ${TPC_LIBS_DIR}
                   COMMAND ln;-fs;${LIBSDIR};${TPC_LIBS_DIR})
add_custom_target(install_libs ALL DEPENDS tpc libtpc-static ${TPC_LIBS_DIR})
