cmake_minimum_required(VERSION 2.6)
project (rot13)

include_directories("$ENV{TPC_HOME}/arch/common/include" "$ENV{TPC_HOME}/platform/common/include")
link_directories("$ENV{TPC_HOME}/arch/baseline/lib/${CMAKE_SYSTEM_PROCESSOR}" "$ENV{TPC_HOME}/platform/vc709/lib/${CMAKE_SYSTEM_PROCESSOR}")

add_executable(rot13 rot13.cpp)
add_executable(tpc-rot13 tpc_rot13.cpp)
target_link_libraries(tpc-rot13 platform tpc atomic)
set_target_properties(rot13 tpc-rot13 PROPERTIES COMPILE_FLAGS "-Wall -std=c++11 -g")
