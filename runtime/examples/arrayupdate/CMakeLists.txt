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
project (arrayupdate)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

find_package (Threads)

add_executable(arrayupdate arrayupdate-example.c)
set_tapasco_defaults(arrayupdate)
target_link_libraries(arrayupdate tapasco ${CMAKE_THREAD_LIBS_INIT} platform tlkm)

add_executable(arrayupdate-cpp arrayupdate-example.cpp)
set_tapasco_defaults(arrayupdate-cpp)
target_link_libraries(arrayupdate-cpp tapasco ${CMAKE_THREAD_LIBS_INIT} platform tlkm)

install(TARGETS arrayupdate arrayupdate-cpp
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

