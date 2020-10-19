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

cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include(${CMAKE_CURRENT_LIST_DIR}/../../../cmake/Tapasco.cmake NO_POLICY_SCOPE)
project(tapasco-benchmark)

if(NOT TARGET tapasco)
  find_package(Tapasco REQUIRED)
endif()

find_package(Threads)

add_executable(tapasco-benchmark tapasco_benchmark.cpp
                                 ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.cpp)
target_include_directories(tapasco-benchmark
                           PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/json11)
set_tapasco_defaults(tapasco-benchmark)
target_link_libraries(tapasco-benchmark
                      PRIVATE tapasco ${CMAKE_THREAD_LIBS_INIT} atomic)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.cpp
         ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.hpp
  COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/json11
  COMMAND git clone https://github.com/dropbox/json11.git
          ${CMAKE_CURRENT_BINARY_DIR}/json11)

include(GNUInstallDirs)

install(TARGETS tapasco-benchmark
        RUNTIME DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)
