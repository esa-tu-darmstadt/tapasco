#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TPC).
#
# Tapasco is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Tapasco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
#
cmake_minimum_required(VERSION 2.6)
project(examples)
set (CMAKE_INSTALL_PREFIX "bin")
include (examples.cmake)

add_subdirectory(arrayinit)
add_subdirectory(arraysum)
add_subdirectory(arrayupdate)
add_subdirectory(basic_test)
add_subdirectory(benchmark-alloc-free)
add_subdirectory(benchmark-cd)
add_subdirectory(benchmark-latency)
add_subdirectory(benchmark-mem)
add_subdirectory(memcheck)
