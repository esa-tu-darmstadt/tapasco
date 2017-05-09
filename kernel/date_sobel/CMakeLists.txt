cmake_minimum_required(VERSION 2.6)
project(date_sobel)

include_directories($ENV{TPC_HOME}/arch/common/include)
link_directories($ENV{TPC_HOME}/arch/lib/${CMAKE_SYSTEM_PROCESSOR} $ENV{TPC_HOME}/platform/lib/${CMAKE_SYSTEM_PROCESSOR})

set_property(SOURCE sobel_tb.cpp PROPERTY COMPILE_FLAGS "-Wall -Werror -std=c++11 -Wno-unknown-pragmas")
add_executable(date_sobel sobel_tb.cpp)
target_link_libraries(date_sobel pthread tpc platform)

