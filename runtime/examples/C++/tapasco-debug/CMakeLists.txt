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
include(${CMAKE_CURRENT_LIST_DIR}/../../../cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (tapasco-debug)

if(NOT TARGET tapasco)
    find_package(Tapasco REQUIRED)
endif ()

find_package(Curses REQUIRED)
find_package (Threads)

add_executable(tapasco-debug tapasco_debug.cpp)
set_tapasco_defaults(tapasco-debug)
target_include_directories(tapasco-debug PRIVATE ${CURSES_INCLUDE_DIR})
target_link_libraries(tapasco-debug PRIVATE tapasco ${CMAKE_THREAD_LIBS_INIT} ${CURSES_LIBRARIES})

include(GNUInstallDirs)

install (TARGETS tapasco-debug
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})
