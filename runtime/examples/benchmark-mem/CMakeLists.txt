cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (benchmark-mem)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable (benchmark-mem benchmark-mem.c)
set_tapasco_defaults(benchmark-mem)
target_link_libraries (benchmark-mem m rt pthread tapasco platform)

add_executable (benchmark-mem++ benchmark-mem.cpp)
set_tapasco_defaults(benchmark-mem++)
target_link_libraries (benchmark-mem++ m rt pthread tapasco platform)

install (TARGETS benchmark-mem benchmark-mem++
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

