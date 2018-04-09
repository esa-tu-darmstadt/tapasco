cmake_minimum_required(VERSION 2.8)
project(arch-axi4mm)

if (NOT EXISTS "$ENV{TAPASCO_HOME}")
  message(FATAL_ERROR "Please set TAPASCO_HOME environment variable to root directory of Tapasco")
endif (NOT EXISTS "$ENV{TAPASCO_HOME}")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

set(CMAKE_INSTALL_PREFIX "${TAPASCO_HOME}")
set(SRCDIR "axi4mm/src")
set(CMNDIR "common/src")

set(AXI4MM_SOURCES "${SRCDIR}/tapasco_regs.c")
set(COMMON_SOURCES "${CMNDIR}/tapasco_context.c"
                   "${CMNDIR}/tapasco_delayed_transfers.c"
                   "${CMNDIR}/tapasco_device.c"
                   "${CMNDIR}/tapasco_errors.c"
                   "${CMNDIR}/tapasco_jobs.c"
	           "${CMNDIR}/tapasco_logging.c"
                   "${CMNDIR}/tapasco_local_mem.c"
                   "${CMNDIR}/tapasco_memory.c"
                   "${CMNDIR}/tapasco_pemgmt.c"
                   "${CMNDIR}/tapasco_scheduler.c"
                   "${CMNDIR}/tapasco_version.c"
                   "${TAPASCO_COMMON_DIR}/src/gen_mem.c"
                   "${TAPASCO_COMMON_DIR}/src/gen_queue.c")

include_directories(${TAPASCO_INCDIRS})
include_directories("include" "common/include" "${TAPASCO_PLATFORM_DIR}/common/include")
link_directories(${TAPASCO_STATICLINKDIRS})

set_source_files_properties(${AXI4MM_SOURCES} ${COMMON_SOURCES} PROPERTIES COMPILE_FLAGS ${TAPASCO_CFLAGS})
add_library(tapasco SHARED ${AXI4MM_SOURCES} ${COMMON_SOURCES})
add_library(libtapasco-static STATIC ${AXI4MM_SOURCES} ${COMMON_SOURCES} ${TAPASCO_PLATFORM_LIB})

target_link_libraries(tapasco platform atomic pthread)
set_target_properties(libtapasco-static PROPERTIES OUTPUT_NAME tapasco)

install(TARGETS tapasco libtapasco-static
        LIBRARY DESTINATION "lib/${TAPASCO_TARGET}"
        ARCHIVE DESTINATION "lib/${TAPASCO_TARGET}/static")
