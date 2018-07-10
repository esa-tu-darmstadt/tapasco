cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (arrayinit)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(arrayinit arrayinit-example.c)
set_tapasco_defaults(arrayinit)
target_link_libraries(arrayinit tapasco pthread platform tlkm)

install(TARGETS arrayinit
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

