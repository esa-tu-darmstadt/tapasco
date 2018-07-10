cmake_minimum_required(VERSION 3.1 FATAL_ERROR)
project(tapasco VERSION 1.0 LANGUAGES C CXX)

include(GNUInstallDirs)

set(CMNDIR "${CMAKE_CURRENT_SOURCE_DIR}/common")
set(TLKMDIR "${CMAKE_CURRENT_SOURCE_DIR}/tlkm")

set(CMAKE_DEBUG_POSTFIX d)

set (CMAKE_CXX_STANDARD 11)
set (CMAKE_C_STANDARD 11)

add_definitions(-DNPERFC)
add_definitions(-DLOG_USE_COLOR)
add_definitions(-Wall)
add_definitions(-Werror)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D__MY_FILE__='\"$(subst ${CMAKE_SOURCE_DIR}/,,$(abspath $<))\"'")

add_subdirectory(tlkm)
add_subdirectory(common)
add_subdirectory(platform)
add_subdirectory(arch)
