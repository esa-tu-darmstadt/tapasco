cmake_minimum_required(VERSION 2.7)
project(benchmark-cd)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

add_executable(benchmark-cd benchmark-cd.c)
target_link_libraries(benchmark-cd rt pthread tapasco platform)
set_target_properties(benchmark-cd PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99")

install(TARGETS benchmark-cd
        RUNTIME DESTINATION bin/${ARCH})
