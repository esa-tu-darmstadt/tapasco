cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (bandwidth)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(bandwidth bandwidth.cpp)
set_tapasco_defaults(bandwidth)
target_link_libraries(bandwidth PRIVATE tapasco tlkm platform tapasco-common)

install(TARGETS bandwidth
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

