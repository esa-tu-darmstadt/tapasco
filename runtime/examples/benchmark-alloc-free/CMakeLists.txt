cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (benchmark-alloc-dealloc)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable (benchmark-alloc-dealloc benchmark-alloc-dealloc.c)
set_tapasco_defaults(benchmark-alloc-dealloc)
target_link_libraries (benchmark-alloc-dealloc m rt pthread tapasco platform)

install (TARGETS benchmark-alloc-dealloc
         RUNTIME DESTINATION share/Tapasco/bin/)

