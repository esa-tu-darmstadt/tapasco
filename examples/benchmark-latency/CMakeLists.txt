cmake_minimum_required(VERSION 3.0)
project (benchmark-latency)

find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(benchmark-latency benchmark-latency.c)
target_link_libraries(benchmark-latency rt pthread tapasco platform atomic)

add_executable(benchmark-latency++ benchmark-latency.cpp)
target_link_libraries(benchmark-latency++ m pthread  atomic tapasco platform atomic)

install(TARGETS benchmark-latency
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
