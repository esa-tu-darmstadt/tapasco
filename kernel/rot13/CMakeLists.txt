cmake_minimum_required(VERSION 2.6)
project (rot13)

include_directories("$ENV{TAPASCO_HOME}/arch/common/include" "$ENV{TAPASCO_HOME}/platform/common/include")
link_directories("$ENV{TAPASCO_HOME}/arch/axi4mm/lib/${CMAKE_SYSTEM_PROCESSOR}" "$ENV{TAPASCO_HOME}/platform/vc709/lib/${CMAKE_SYSTEM_PROCESSOR}")

add_executable(rot13 rot13.cpp)
add_executable(tapasco-rot13 tapasco_rot13.cpp)
target_link_libraries(tapasco-rot13 platform tapasco atomic pthread)
set_target_properties(rot13 tapasco-rot13 PROPERTIES COMPILE_FLAGS "-Wall -std=c++11 -g")
