cmake_minimum_required(VERSION 2.6)
project(tpc-logging-benchmark)

set (TPC_HOME "$ENV{TPC_HOME}")
set (ARCH "${CMAKE_SYSTEM_PROCESSOR}")

include_directories(../../include)
link_directories("${TPC_HOME}/arch/lib/${ARCH}" "${TPC_HOME}/platform/lib/${ARCH}")

add_executable(tpc-logging-benchmark tpc_logging_benchmark.c)
target_link_libraries(tpc-logging-benchmark pthread platform tpc)
set_source_files_properties(tpc_logging_benchmark.c PROPERTIES COMPILE_FLAGS "-Wall -Werror -g -O3 -std=gnu11 -Wno-unused-variable")
