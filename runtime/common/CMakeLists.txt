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
project(tapasco-common VERSION 1.0 LANGUAGES C)

add_library(tapasco-common
                src/gen_mem.c
                src/gen_queue.c
                src/log.c)

target_include_directories(tapasco-common PUBLIC $<INSTALL_INTERFACE:include/tapasco/common> $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)

set_property(TARGET tapasco-common PROPERTY PUBLIC_HEADER
            include/gen_fixed_size_pool.h
            include/gen_mem.h
            include/gen_queue.h
            include/gen_stack.h
            include/log.h
)

set_tapasco_defaults(tapasco-common)

install(TARGETS tapasco-common
        EXPORT TapascoCommonConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/common
        )

install(EXPORT TapascoCommonConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tapasco-common FILE TapascoCommonConfig.cmake)
