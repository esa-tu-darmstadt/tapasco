cmake_minimum_required(VERSION 2.8)
project(tapasco-async-benchmark)

set (TAPASCO_HOME "$ENV{TAPASCO_HOME}")
set (ARCH "${CMAKE_SYSTEM_PROCESSOR}")
set (ARCHCMN "${TAPASCO_HOME}/arch/common/src")

set (ASYNCS "${ARCHCMN}/tapasco_async.c" "${ARCHCMN}/tapasco_async_dispatcher.c" "${ARCHCMN}/tapasco_async_collector.c")

set (SRCS ${ASYNCS} tapasco_async_benchmark.c)

include_directories(../../include "${TAPASCO_HOME}/arch/common/include" "${TAPASCO_HOME}/platform/common/include" "${TAPASCO_HOME}/common/include")
link_directories("${TAPASCO_HOME}/arch/lib/${ARCH}" "${TAPASCO_HOME}/platform/lib/${ARCH}")

add_executable(tapasco-async-benchmark ${ASYNCS} tapasco_async_benchmark.c)
target_link_libraries(tapasco-async-benchmark pthread platform tapasco)
set_source_files_properties(${SRCS} PROPERTIES COMPILE_FLAGS "-Wall -Werror -g -O3 -std=gnu11 -Wno-unused-variable")
