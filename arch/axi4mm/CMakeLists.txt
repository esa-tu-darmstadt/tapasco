project(arch-axi4mm VERSION 1.0 LANGUAGES C CXX)

set(PCMNDIR "../common/src")
set(GPCMNDIR "${TAPASCO_HOME}/common")

set(AXI4MM_SOURCES "src/tapasco_regs.c")
set(COMMON_SOURCES "${PCMNDIR}/tapasco_context.c"
                   "${PCMNDIR}/tapasco_delayed_transfers.c"
                   "${PCMNDIR}/tapasco_device.c"
                   "${PCMNDIR}/tapasco_errors.c"
                   "${PCMNDIR}/tapasco_jobs.c"
	               "${PCMNDIR}/tapasco_logging.c"
                   "${PCMNDIR}/tapasco_local_mem.c"
                   "${PCMNDIR}/tapasco_memory.c"
                   "${PCMNDIR}/tapasco_pemgmt.c"
                   "${PCMNDIR}/tapasco_scheduler.c"
                   "${PCMNDIR}/tapasco_version.c"
                   "${PCMNDIR}/tapasco_perfc.c"
                   "${CMNDIR}/src/gen_mem.c"
                   "${CMNDIR}/src/gen_queue.c")

add_library(tapasco ${AXI4MM_SOURCES} ${COMMON_SOURCES})

target_include_directories(tapasco PUBLIC "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>" "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../common/include>" PRIVATE ${CMNDIR}/include)

add_definitions(-DUSE_ASSERTIONS)

target_link_libraries(tapasco platform atomic pthread)

install(TARGETS tapasco EXPORT TapascoConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})

install(EXPORT TapascoConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tapasco FILE TapascoConfig.cmake)
