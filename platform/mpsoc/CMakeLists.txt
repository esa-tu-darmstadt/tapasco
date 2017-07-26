cmake_minimum_required(VERSION 2.6)
project(platform-zynq)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)

if (NOT EXISTS "$ENV{TAPASCO_HOME}")
  message(FATAL_ERROR "Please set TAPASCO_HOME environment variable to root directory of Tapasco")
endif (NOT EXISTS "$ENV{TAPASCO_HOME}")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

set(SRCDIR "src")
set(CMNDIR "../common")
set(GCMNDIR "${TAPASCO_HOME}/common")
set(COMPFLAGS "-Wall -Werror -g -O3 -std=gnu11")
set(CMNSRCS "${CMNDIR}/src/platform_logging.c"
            "${CMNDIR}/src/platform_errors.c"
            "${SRCDIR}/platform_address_map.c"
            "${CMNDIR}/src/platform_version.c"
            "${GCMNDIR}/src/gen_queue.c")
set(SRCS "${SRCDIR}/platform_zynq.c")
set(PLATFORM_LIBS_DIR "${TAPASCO_HOME}/platform/lib")

include_directories("." "include" "${CMNDIR}/include" "${GCMNDIR}/include")
set_source_files_properties(${CMNSRCS} ${SRCS} PROPERTIES COMPILE_FLAGS ${COMPFLAGS})

add_library(platform SHARED ${CMNSRCS} ${SRCS})
add_library(platform-static STATIC ${CMNSRCS} ${SRCS})
set_target_properties(platform-static PROPERTIES OUTPUT_NAME platform)

set_target_properties(platform PROPERTIES COMPILE_FLAGS ${COMPFLAGS})
set_target_properties(platform-static PROPERTIES COMPILE_FLAGS ${COMPFLAGS})

if ("armv71" STREQUAL ${TAPASCO_TARGET})
	target_link_libraries(platform atomic)
	target_link_libraries(platform-static atomic)
endif ()

install(TARGETS platform platform-static
        LIBRARY DESTINATION "lib/${TAPASCO_TARGET}"
        ARCHIVE DESTINATION "lib/${TAPASCO_TARGET}/static")

get_filename_component(LIBSDIR "lib" REALPATH)
add_custom_command(OUTPUT ${PLATFORM_LIBS_DIR}
                   COMMAND ln;-fs;${LIBSDIR};${PLATFORM_LIBS_DIR})
add_custom_target(install_libs ALL DEPENDS platform platform-static ${PLATFORM_LIBS_DIR})
