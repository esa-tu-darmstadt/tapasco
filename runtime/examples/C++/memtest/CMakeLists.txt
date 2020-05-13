# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
# 
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
project (memtest)

if(NOT TARGET tapasco)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(memtest memtest.cpp)
set_tapasco_defaults(memtest)
target_link_libraries(memtest PRIVATE tapasco)

install(TARGETS memtest
        RUNTIME  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)

add_executable(memtest_parallel memtest_parallel.cpp)
set_tapasco_defaults(memtest_parallel)
target_link_libraries(memtest_parallel PRIVATE tapasco)

install(TARGETS memtest_parallel
	RUNTIME DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)
