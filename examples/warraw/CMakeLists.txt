cmake_minimum_required(VERSION 2.7)
project(warraw)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

include_directories(../../kernel/warraw)

add_executable(warraw warraw-example.c ../../kernel/warraw/warraw.c)
target_link_libraries(warraw rt pthread tapasco platform-client)
set_target_properties(warraw PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

install(TARGETS warraw
        RUNTIME DESTINATION bin/${ARCH})
