cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (arrayupdate)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

find_package (Threads)

add_executable(arrayupdate arrayupdate-example.c)
set_tapasco_defaults(arrayupdate)
target_link_libraries(arrayupdate tapasco ${CMAKE_THREAD_LIBS_INIT} platform tlkm)

add_executable(arrayupdate-cpp arrayupdate-example.cpp)
set_tapasco_defaults(arrayupdate-cpp)
target_link_libraries(arrayupdate-cpp tapasco ${CMAKE_THREAD_LIBS_INIT} platform tlkm)

install(TARGETS arrayupdate arrayupdate-cpp
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

