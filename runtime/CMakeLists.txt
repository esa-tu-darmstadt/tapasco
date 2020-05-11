# This file is part of TaPaSCo
# (see https://github.com/esa-tu-darmstadt/tapasco).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake)
project(tapasco VERSION 1.0 LANGUAGES C CXX)

SET(CPACK_GENERATOR "RPM" "DEB" "TGZ" "ZIP" "STGZ" "TBZ2")
SET(CPACK_PACKAGE_CONTACT "tapasco@esa.tu-darmstadt.de")

SET(CPACK_PACKAGE_VERSION_MAJOR 2020)
SET(CPACK_PACKAGE_VERSION_MINOR 04)
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
