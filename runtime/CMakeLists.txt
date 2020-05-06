cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake)
project(tapasco VERSION 1.0 LANGUAGES C CXX)

SET(CPACK_GENERATOR "RPM" "DEB" "TGZ" "ZIP" "STGZ" "TBZ2")
SET(CPACK_PACKAGE_CONTACT "tapasco@esa.tu-darmstadt.de")

SET(CPACK_PACKAGE_VERSION_MAJOR 2019)
SET(CPACK_PACKAGE_VERSION_MINOR 10)
SET(CPACK_PACKAGE_VERSION_PATCH 0)

INCLUDE(CPack)

include(GNUInstallDirs)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D__MY_FILE__='\"$(subst ${CMAKE_SOURCE_DIR}/,,$(abspath $<))\"'")

install(FILES platform/pcie/module/program_pcie.tcl DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/platform/pcie/module/)
install(PROGRAMS platform/pcie/module/bit_reload.sh DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/platform/pcie/module/)
install(PROGRAMS bin/tapasco-load-bitstream DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)

add_subdirectory(kernel)
add_subdirectory(common)
add_subdirectory(platform)
add_subdirectory(arch)
if(NOT ${CMAKE_CROSSCOMPILING})
    add_subdirectory(examples)
endif()
