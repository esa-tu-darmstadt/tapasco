cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (start_latency)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(start_latency start_latency.cpp)
set_tapasco_defaults(start_latency)
target_link_libraries(start_latency PRIVATE tapasco tlkm platform tapasco-common)

add_executable(read_latency read_latency.cpp)
set_tapasco_defaults(read_latency)
target_link_libraries(read_latency PRIVATE tapasco tlkm platform tapasco-common)

install(TARGETS read_latency start_latency
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)