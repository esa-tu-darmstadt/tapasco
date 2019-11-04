cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (arrayinit)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(arrayinit arrayinit-example.c)
set_tapasco_defaults(arrayinit)
target_link_libraries(arrayinit tapasco pthread platform tlkm)

add_executable(arrayinit-cpp arrayinit-example.cpp)
set_tapasco_defaults(arrayinit-cpp)
target_link_libraries(arrayinit-cpp tapasco pthread platform tlkm)

install(TARGETS arrayinit-cpp
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

