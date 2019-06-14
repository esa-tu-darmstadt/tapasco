cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (tapasco-debug)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

find_package(Curses REQUIRED)

add_executable(tapasco-debug tapasco_debug.cpp)
set_tapasco_defaults(tapasco-debug)
target_include_directories(tapasco-debug PRIVATE ${CURSES_INCLUDE_DIR})
target_link_libraries(tapasco-debug PRIVATE tapasco pthread atomic ${CURSES_LIBRARIES})

include(GNUInstallDirs)

install (TARGETS tapasco-debug
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})
