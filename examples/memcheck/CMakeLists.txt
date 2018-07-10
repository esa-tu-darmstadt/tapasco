cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (memcheck)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(memcheck memcheck.c)
set_tapasco_defaults(memcheck)
target_link_libraries(memcheck PRIVATE tapasco tlkm platform tapasco-common)

add_executable(memcheck-mt memcheck-mt.c)
set_tapasco_defaults(memcheck-mt)
target_link_libraries(memcheck-mt PRIVATE tapasco tlkm platform tapasco-common)

install(TARGETS memcheck memcheck-mt
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

