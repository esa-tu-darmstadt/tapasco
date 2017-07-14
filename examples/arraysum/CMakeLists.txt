cmake_minimum_required(VERSION 2.6)
project(arraysum)
set (CMAKE_INSTALL_PREFIX "..")
set (CMAKE_SKIP_RPATH true)
include (../examples.cmake)

include_directories(../../kernel/arraysum)

add_executable(arraysum arraysum-example.c ../../kernel/arraysum/arraysum.c)
target_link_libraries(arraysum rt pthread tapasco platform atomic)
set_target_properties(arraysum PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

add_executable(arraysum-mt arraysum-example-mt.c ../../kernel/arraysum/arraysum.c)
target_link_libraries(arraysum-mt rt pthread tapasco platform atomic)
set_target_properties(arraysum-mt PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

install(TARGETS arraysum
        RUNTIME DESTINATION bin/${ARCH})
