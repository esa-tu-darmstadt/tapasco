cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include(${CMAKE_CURRENT_LIST_DIR}/../../../cmake/Tapasco.cmake NO_POLICY_SCOPE)
project(arraysum)

if(NOT TARGET tapasco)
  find_package(Tapasco REQUIRED)
endif()

find_package(Threads)

add_executable(arraysum arraysum-example.c)
set_tapasco_defaults(arraysum)
target_link_libraries(arraysum tapasco ${CMAKE_THREAD_LIBS_INIT})

install(TARGETS arraysum
        RUNTIME DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)
