cmake_minimum_required(VERSION 2.6)
project(sudoku)
set (CMAKE_INSTALL_PREFIX "..")
include (../../examples/examples.cmake)

add_executable(sudoku src/multithreaded.cpp src/Sudoku.cpp src/Sudoku_HLS.cpp)
target_link_libraries(sudoku rt pthread tapasco platform)
set_target_properties(sudoku PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=c++11 -Wno-unknown-pragmas")

install(TARGETS sudoku
        RUNTIME DESTINATION bin/${ARCH})
