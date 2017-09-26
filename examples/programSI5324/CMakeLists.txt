cmake_minimum_required (VERSION 2.7)
set(ADD_CXXFLAGS "-g -Wall -Werror -std=c++11 -O3")
set(ADD_LDFLAGS "-flto -static-libstdc++ -static-libgcc")

if ("$ENV{TAPASCO_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TAPASCO_HOME to root directory of Tapasco.")
endif ("$ENV{TAPASCO_HOME}" STREQUAL "")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

link_directories(${TAPASCO_HOME}/arch/lib/${TAPASCO_TARGET}/static  ${TAPASCO_HOME}/platform/lib/${TAPASCO_TARGET}/static)
include_directories(${TAPASCO_HOME}/arch/common/include ${TAPASCO_HOME}/platform/common/include)

add_executable(programSI5324 programSI5324.cpp)
target_link_libraries (programSI5324 tapasco platform pthread atomic ncurses)
set_target_properties (programSI5324 PROPERTIES COMPILE_FLAGS ${ADD_CXXFLAGS})
set_target_properties (programSI5324 PROPERTIES LINK_FLAGS ${ADD_LDFLAGS})

install(TARGETS programSI5324
        RUNTIME DESTINATION bin/${CMAKE_SYSTEM_PROCESSOR})

