cmake_minimum_required (VERSION 2.8)
include(ExternalProject)
project (tpc-debug)
set(ADD_CXXFLAGS "-g -Wall -Werror -std=c++11 -fno-rtti")
set(ADD_LDFLAGS "-flto -static-libstdc++ -static-libgcc")

if ("$ENV{TPC_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TPC_HOME to root directory of ThreadPoolComposer.")
endif ("$ENV{TPC_HOME}" STREQUAL "")

include ("$ENV{TPC_HOME}/cmake/ThreadPoolComposer.cmake")
set (CMAKE_INSTALL_PREFIX "${TPC_HOME}/bin")

link_directories(${TPC_HOME}/arch/lib/${TPC_TARGET}/static  ${TPC_HOME}/platform/lib/${TPC_TARGET}/static)
include_directories(${TPC_HOME}/arch/common/include ${TPC_HOME}/platform/common/include)

add_executable (tpc-debug tpc_debug.cpp)
target_link_libraries (tpc-debug tpc platform pthread atomic ncurses)
set_target_properties (tpc-debug PROPERTIES COMPILE_FLAGS ${ADD_CXXFLAGS})
set_target_properties (tpc-debug PROPERTIES LINK_FLAGS ${ADD_LDFLAGS})

add_executable (tpc-benchmark tpc_benchmark.cpp json11.cpp)
target_link_libraries (tpc-benchmark tpc platform pthread atomic ncurses)
set_target_properties (tpc-benchmark PROPERTIES COMPILE_FLAGS ${ADD_CXXFLAGS})
set_target_properties (tpc-benchmark PROPERTIES LINK_FLAGS ${ADD_LDFLAGS})

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/json11.cpp ${CMAKE_CURRENT_SOURCE_DIR}/json11.hpp
  COMMAND git clone https://github.com/dropbox/json11.git
  COMMAND cp json11/json11.* ${CMAKE_CURRENT_SOURCE_DIR}
  )

install (TARGETS tpc-debug tpc-benchmark
	 RUNTIME DESTINATION ${TPC_HOME}/bin)
