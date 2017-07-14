cmake_minimum_required (VERSION 2.8)
include(ExternalProject)
project (tapasco-debug)
set(ADD_CXXFLAGS "-g -Wall -Werror -std=c++11 -fno-rtti")
set(ADD_LDFLAGS "-flto -static-libstdc++ -static-libgcc")

if ("$ENV{TAPASCO_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TAPASCO_HOME to root directory of Tapasco.")
endif ("$ENV{TAPASCO_HOME}" STREQUAL "")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")
set (CMAKE_INSTALL_PREFIX "${TAPASCO_HOME}/bin")

link_directories(${TAPASCO_HOME}/arch/lib/${TAPASCO_TARGET}/static  ${TAPASCO_HOME}/platform/lib/${TAPASCO_TARGET}/static)
include_directories(${TAPASCO_HOME}/arch/common/include ${TAPASCO_HOME}/platform/common/include)

add_executable (tapasco-debug tapasco_debug.cpp)
target_link_libraries (tapasco-debug tapasco platform pthread atomic ncurses)
set_target_properties (tapasco-debug PROPERTIES COMPILE_FLAGS ${ADD_CXXFLAGS})
set_target_properties (tapasco-debug PROPERTIES LINK_FLAGS ${ADD_LDFLAGS})

add_executable (tapasco-benchmark tapasco_benchmark.cpp json11.cpp)
target_link_libraries (tapasco-benchmark tapasco platform pthread atomic ncurses)
set_target_properties (tapasco-benchmark PROPERTIES COMPILE_FLAGS ${ADD_CXXFLAGS})
set_target_properties (tapasco-benchmark PROPERTIES LINK_FLAGS ${ADD_LDFLAGS})

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/json11.cpp ${CMAKE_CURRENT_SOURCE_DIR}/json11.hpp
  COMMAND rm -rf json11
  COMMAND git clone https://github.com/dropbox/json11.git
  COMMAND cp json11/json11.* ${CMAKE_CURRENT_SOURCE_DIR}
  )

install (TARGETS tapasco-debug tapasco-benchmark
	 RUNTIME DESTINATION ${TAPASCO_HOME}/bin)
