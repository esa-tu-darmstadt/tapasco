cmake_minimum_required(VERSION 2.6)
project(benchmark-latency)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

add_executable(benchmark-latency benchmark-latency.c)
target_link_libraries(benchmark-latency rt pthread tapasco platform atomic)
set_target_properties(benchmark-latency PROPERTIES COMPILE_FLAGS "-Wall -Werror -std=gnu99 -Wno-unused-function")

add_executable(benchmark-latency++ benchmark-latency.cpp)
target_link_libraries(benchmark-latency++ m pthread  atomic tapasco platform atomic)
set_target_properties(benchmark-latency++ PROPERTIES COMPILE_FLAGS "-Wall -Werror -std=c++11 -Wno-unused-function -static-libstdc++ -flto")

install(TARGETS benchmark-latency
        RUNTIME DESTINATION bin/${ARCH})
