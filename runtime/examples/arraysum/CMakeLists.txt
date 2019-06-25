cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (arraysum)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(arraysum arraysum-example.c)
set_tapasco_defaults(arraysum)
target_link_libraries(arraysum tapasco pthread platform tlkm)

install(TARGETS arraysum
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

