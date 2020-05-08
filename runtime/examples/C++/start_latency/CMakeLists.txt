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
project (start_latency)

if(NOT TARGET tapasco)
    find_package(Tapasco REQUIRED)
endif ()

add_executable(start_latency start_latency.cpp)
set_tapasco_defaults(start_latency)
target_link_libraries(start_latency PRIVATE tapasco tlkm platform tapasco-common)

add_executable(read_latency read_latency.cpp)
set_tapasco_defaults(read_latency)
target_link_libraries(read_latency PRIVATE tapasco tlkm platform tapasco-common)

install(TARGETS read_latency start_latency
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)