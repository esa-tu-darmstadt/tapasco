cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake)
project(tapasco-common VERSION 1.0 LANGUAGES C CXX)

add_library(tapasco-common
                src/gen_mem.c
                src/gen_mem_test.c
                src/gen_queue.c
                src/gen_queue_test.c
                src/gen_stack_test.c
                src/log.c)

target_include_directories(tapasco-common PUBLIC $<INSTALL_INTERFACE:include/tapasco/common> $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)

set_property(TARGET tapasco-common PROPERTY PUBLIC_HEADER
            include/gen_fixed_size_pool.h
            include/gen_mem.h
            include/gen_queue.h
            include/gen_stack.h
            include/log.h
)

set_tapasco_defaults(tapasco-common)

install(TARGETS tapasco-common
        EXPORT TapascoCommonConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/common
        )

install(EXPORT TapascoCommonConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tapasco-common FILE TapascoCommonConfig.cmake)
