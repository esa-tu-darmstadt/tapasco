cmake_minimum_required(VERSION 2.6)
project(arch-axi4mm)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)

if (NOT EXISTS "$ENV{TAPASCO_HOME}")
  message(FATAL_ERROR "Please set TAPASCO_HOME environment variable to root directory of Tapasco")
endif (NOT EXISTS "$ENV{TAPASCO_HOME}")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

set(SRCDIR "src")
set(CMNDIR "../common/src")
set(GCMNDIR "${TAPASCO_HOME}/common")
set(PLATFORMDIR "${TAPASCO_HOME}/platform")
set(LIBPLATFORM_STATIC "${TAPASCO_HOME}/platform/lib/${TAPASCO_TARGET}/static/libplatform.a")

set(BASELINE_SOURCES "${SRCDIR}/tapasco_init.c"
                     "${SRCDIR}/tapasco_device.c"
                     "${SRCDIR}/tapasco_address_map.c")
set(COMMON_SOURCES "${CMNDIR}/tapasco_logging.c"
                   "${CMNDIR}/tapasco_errors.c"
                   "${CMNDIR}/tapasco_functions.c"
                   "${CMNDIR}/tapasco_scheduler.c"
                   "${CMNDIR}/tapasco_jobs.c"
                   "${CMNDIR}/tapasco_status.c"
                   "${CMNDIR}/tapasco_version.c"
                   "${GCMNDIR}/src/gen_queue.c")
set(TAPASCO_LIBS_DIR "${TAPASCO_HOME}/arch/lib")

include_directories("include" "../common/include" "${PLATFORMDIR}/common/include" "${GCMNDIR}/include")
link_directories("${PLATFORMDIR}/lib/${TAPASCO_TARGET}")

add_definitions(-DUSE_ASSERTIONS)

set_source_files_properties(${BASELINE_SOURCES} ${COMMON_SOURCES} PROPERTIES COMPILE_FLAGS "-g -O3 -Wall -Werror -std=gnu11")
add_library(tapasco SHARED ${BASELINE_SOURCES} ${COMMON_SOURCES})
add_library(libtapasco-static STATIC ${BASELINE_SOURCES} ${COMMON_SOURCES} ${LIBPLATFORM_STATIC})

target_link_libraries(tapasco platform atomic pthread)
set_target_properties(libtapasco-static PROPERTIES OUTPUT_NAME tapasco)

install(TARGETS tapasco libtapasco-static
        LIBRARY DESTINATION "lib/${TAPASCO_TARGET}"
        ARCHIVE DESTINATION "lib/${TAPASCO_TARGET}/static")

get_filename_component(LIBSDIR "lib" REALPATH)
add_custom_command(OUTPUT ${TAPASCO_LIBS_DIR}
                   COMMAND ln;-fs;${LIBSDIR};${TAPASCO_LIBS_DIR})
add_custom_target(install_libs ALL DEPENDS tapasco libtapasco-static ${TAPASCO_LIBS_DIR})
