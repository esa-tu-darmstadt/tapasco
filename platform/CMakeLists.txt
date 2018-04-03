cmake_minimum_required(VERSION 2.8)
project(platform)

if (NOT EXISTS "$ENV{TAPASCO_HOME}")
  message(FATAL_ERROR "Please set TAPASCO_HOME environment variable to root directory of Tapasco")
endif (NOT EXISTS "$ENV{TAPASCO_HOME}")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

add_definitions("-DNPERFC")
set(CMAKE_INSTALL_PREFIX "${TAPASCO_HOME}")

set(SRCDIR "src")
set(CMNDIR "common")
set(GCMNDIR "${TAPASCO_HOME}/common")
set(TLKMDIR "${TAPASCO_HOME}/module")
set(CMNSRCS "${CMNDIR}/src/platform_addr_map.c"
            "${CMNDIR}/src/platform_signaling.c"
            "${CMNDIR}/src/platform_ctx.c"
            "${CMNDIR}/src/platform_devctx.c"
            "${CMNDIR}/src/platform_device_operations.c"
            "${CMNDIR}/src/platform_errors.c"
            "${CMNDIR}/src/platform_info.c"
	    "${CMNDIR}/src/platform_logging.c"
            "${CMNDIR}/src/platform_version.c"
            "${GCMNDIR}/src/gen_queue.c")
set(ZYNQSRCS "zynq/src/platform_zynq.c")

link_directories(${TAPASCO_STATICLINKDIRS})
include_directories(
	"include"
	"common/include"
	"zynq/src"
	${TAPASCO_INCDIRS}
)

set_source_files_properties(${CMNSRCS} ${ZYNQSRCS} PROPERTIES COMPILE_FLAGS ${TAPASCO_CFLAGS})

add_library(platform SHARED ${CMNSRCS} ${ZYNQSRCS})
add_library(platform-static STATIC ${CMNSRCS} ${ZYNQSRCS})
set_target_properties(platform PROPERTIES LINKER_FLAGS ${TAPASCO_LDFLAGS})
set_target_properties(platform-static PROPERTIES OUTPUT_NAME platform)
set_target_properties(platform-static PROPERTIES LINKER_FLAGS ${TAPASCO_LDFLAGS})

if ("armv71" STREQUAL ${TAPASCO_TARGET})
	target_link_libraries(platform atomic)
	target_link_libraries(platform-static atomic)
endif ()

install(TARGETS platform platform-static
        LIBRARY DESTINATION "lib/${TAPASCO_TARGET}"
        ARCHIVE DESTINATION "lib/${TAPASCO_TARGET}/static")
