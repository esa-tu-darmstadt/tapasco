cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (memcheck)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(memcheck memcheck.cpp)
set_tapasco_defaults(memcheck)
target_link_libraries(memcheck PRIVATE tapasco tlkm platform tapasco-common)

find_package(OpenMP)
if(OpenMP_CXX_FOUND)
    target_link_libraries(memcheck PUBLIC OpenMP::OpenMP_CXX)
endif()

install(TARGETS memcheck
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

