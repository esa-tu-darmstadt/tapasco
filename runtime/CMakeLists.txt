# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
#
# This file is part of TaPaSCo (see
# https://github.com/esa-tu-darmstadt/tapasco).
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)
project(TapascoInstall)

set(CPACK_GENERATOR "RPM" "DEB" "TGZ" "ZIP" "STGZ" "TBZ2")
set(CPACK_PACKAGE_CONTACT "tapasco@esa.tu-darmstadt.de")

set(CPACK_PACKAGE_VERSION_MAJOR 2024)
set(CPACK_PACKAGE_VERSION_MINOR 1)
set(CPACK_PACKAGE_VERSION_PATCH 0)
set(CPACK_PACKAGE_NAME tapasco)

include(CPack)
include(GNUInstallDirs)

install(FILES scripts/pcie/program_pcie.tcl
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/scripts/pcie/)
install(PROGRAMS scripts/pcie/bit_reload.sh
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/scripts/pcie/)
install(PROGRAMS scripts/zynq/bit_reload.sh
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/scripts/zynq/)
install(PROGRAMS scripts/f1/bit_reload.sh
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/scripts/f1/)
install(PROGRAMS bin/tapasco-load-bitstream
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)

add_subdirectory(libtapasco)
if(NOT ${CMAKE_CROSSCOMPILING})
  add_subdirectory(examples)
endif()
