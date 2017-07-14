cmake_minimum_required(VERSION 2.6)
project(basic_test)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

add_executable(basic_test basic_test.cpp)
target_link_libraries(basic_test rt pthread tapasco platform atomic)
set_target_properties(basic_test PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -O3 -std=c++11")

install(TARGETS basic_test
        RUNTIME DESTINATION bin/${ARCH})
