cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake)
project (arrayupdate)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(arrayupdate arrayupdate-example.c)
set_tapasco_defaults(arrayupdate)
target_link_libraries(arrayupdate tapasco pthread platform tlkm)

install(TARGETS arrayupdate
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

