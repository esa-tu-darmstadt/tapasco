cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake)
project(tapasco VERSION 1.0 LANGUAGES C CXX)

SET(CPACK_GENERATOR "RPM" "DEB" "TGZ" "ZIP" "STGZ" "TBZ2")
SET(CPACK_PACKAGE_CONTACT "korinth@esa.tu-darmstadt.de")

SET(CPACK_PACKAGE_VERSION_MAJOR 2019)
SET(CPACK_PACKAGE_VERSION_MINOR 6)
SET(CPACK_PACKAGE_VERSION_PATCH 0)

INCLUDE(CPack)

include(GNUInstallDirs)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D__MY_FILE__='\"$(subst ${CMAKE_SOURCE_DIR}/,,$(abspath $<))\"'")

add_subdirectory(tlkm)
add_subdirectory(common)
add_subdirectory(platform)
add_subdirectory(arch)
add_subdirectory(examples)
