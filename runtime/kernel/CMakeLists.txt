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

cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project(tlkm VERSION 1.0 LANGUAGES C)

add_library(tlkm INTERFACE)

target_include_directories(tlkm INTERFACE $<INSTALL_INTERFACE:include/tapasco/tlkm>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/user>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/>)

install(TARGETS tlkm
        EXPORT TapascoTLKMConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        )
install(FILES user/tlkm_access.h
              user/tlkm_device_ioctl_cmds.h
              user/tlkm_ioctl_cmds.h
              user/tlkm_platform.h
              user/tlkm_types.h
              hsa/hsa_ioctl_calls.h
              DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/tlkm
        )

install(EXPORT TapascoTLKMConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tlkm FILE TapascoTLKMConfig.cmake)
