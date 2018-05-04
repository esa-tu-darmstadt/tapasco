cmake_minimum_required (VERSION 2.8)
include(ExternalProject)
project (tapasco-debug)

if ("$ENV{TAPASCO_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TAPASCO_HOME to root directory of Tapasco.")
endif ("$ENV{TAPASCO_HOME}" STREQUAL "")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")
set (CMAKE_INSTALL_PREFIX "${TAPASCO_HOME}/bin")

set(CXX_SOURCES tapasco_benchmark.cpp tapasco_debug.cpp json11.cpp jobs/Jobs.cpp)
set(CC_SOURCES ${TAPASCO_COMMON_DIR}/src/gen_queue.c)

set_source_files_properties(${CXX_SOURCES} PROPERTIES COMPILE_FLAGS ${TAPASCO_CXXFLAGS})
set_source_files_properties(${CC_SOURCES} PROPERTIES COMPILE_FLAGS ${TAPASCO_CFLAGS})

link_directories(${TAPASCO_STATICLINKDIRS})
include_directories(${TAPASCO_INCDIRS} "${TAPASCO_HOME}/arch/common/include" "${TAPASCO_HOME}/platform/common/include")

add_executable (tapasco-debug tapasco_debug.cpp ${TAPASCO_COMMON_DIR}/src/gen_queue.c)
target_link_libraries (tapasco-debug m tapasco platform pthread atomic ncurses)
set_target_properties (tapasco-debug PROPERTIES LINK_FLAGS ${TAPASCO_LDFLAGS})

add_executable (tapasco-benchmark tapasco_benchmark.cpp json11.cpp)
target_link_libraries (tapasco-benchmark pthread atomic ncurses)
set_target_properties (tapasco-benchmark PROPERTIES LINK_SEARCH_START_STATIC 1)
set_target_properties (tapasco-benchmark PROPERTIES LINK_SEARCH_END_STATIC 1)
set (CMAKE_FIND_LIBRARY_SUFFIXES ".a")
target_link_libraries (tapasco-benchmark tapasco platform)
set_target_properties (tapasco-benchmark PROPERTIES LINK_FLAGS ${TAPASCO_LDFLAGS})

add_executable (tapasco-jobs jobs/Jobs.cpp)
target_link_libraries (tapasco-jobs tapasco platform pthread atomic ncurses)
set_target_properties (tapasco-jobs PROPERTIES LINK_FLAGS ${TAPASCO_LDFLAGS})

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/json11.cpp ${CMAKE_CURRENT_SOURCE_DIR}/json11.hpp
  COMMAND rm -rf json11
  COMMAND git clone https://github.com/dropbox/json11.git
  COMMAND cp json11/json11.* ${CMAKE_CURRENT_SOURCE_DIR}
  )

install (TARGETS tapasco-debug tapasco-benchmark
	 RUNTIME DESTINATION ${TAPASCO_HOME}/bin)
