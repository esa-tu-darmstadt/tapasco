cmake_minimum_required(VERSION 3.1 FATAL_ERROR)
project(tapasco VERSION 1.0 LANGUAGES C CXX)

include(GNUInstallDirs)

set(CMNDIR "${CMAKE_CURRENT_SOURCE_DIR}/common")

set(CMAKE_DEBUG_POSTFIX d)

set (CMAKE_CXX_STANDARD 11)
set (CMAKE_C_STANDARD 11)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Werror")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")

add_subdirectory(platform)
add_subdirectory(arch/axi4mm)
add_subdirectory(arch/tests)