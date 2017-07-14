cmake_minimum_required (VERSION 2.6)
project (benchmark-mem)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

add_executable (benchmark-mem benchmark-mem.c)
target_link_libraries (benchmark-mem m rt pthread tapasco platform)
set_target_properties (benchmark-mem PROPERTIES COMPILE_FLAGS "-Wall -Werror -std=gnu99")

add_executable (benchmark-mem++ benchmark-mem.cpp)
target_link_libraries (benchmark-mem++ m rt pthread tapasco platform)
set_target_properties (benchmark-mem++ PROPERTIES COMPILE_FLAGS "-Wall -Werror -std=c++11")

install (TARGETS benchmark-mem benchmark-mem++
         RUNTIME DESTINATION bin/${ARCH})

