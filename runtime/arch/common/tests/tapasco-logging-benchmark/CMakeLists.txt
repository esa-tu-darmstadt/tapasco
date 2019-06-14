cmake_minimum_required(VERSION 2.6)
project(tapasco-logging-benchmark)

set (TAPASCO_HOME "$ENV{TAPASCO_HOME}")
set (ARCH "${CMAKE_SYSTEM_PROCESSOR}")

include_directories(../../include)
link_directories("${TAPASCO_HOME}/arch/lib/${ARCH}" "${TAPASCO_HOME}/platform/lib/${ARCH}")

add_executable(tapasco-logging-benchmark tapasco_logging_benchmark.c)
target_link_libraries(tapasco-logging-benchmark pthread platform tapasco)
set_source_files_properties(tapasco_logging_benchmark.c PROPERTIES COMPILE_FLAGS "-Wall -Werror -g -O3 -std=gnu11 -Wno-unused-variable")
