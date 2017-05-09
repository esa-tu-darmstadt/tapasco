cmake_minimum_required (VERSION 2.7)
project (benchmark-alloc-dealloc)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

add_executable (benchmark-alloc-dealloc benchmark-alloc-dealloc.c)
target_link_libraries (benchmark-alloc-dealloc m rt pthread tapasco platform)
set_target_properties (benchmark-alloc-dealloc PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99")

install (TARGETS benchmark-alloc-dealloc
         RUNTIME DESTINATION bin/${ARCH})

