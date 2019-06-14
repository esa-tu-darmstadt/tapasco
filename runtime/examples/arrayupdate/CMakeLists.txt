cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (arrayupdate)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(arrayupdate arrayupdate-example.c)
set_tapasco_defaults(arrayupdate)
target_link_libraries(arrayupdate tapasco pthread platform tlkm)

install(TARGETS arrayupdate
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

