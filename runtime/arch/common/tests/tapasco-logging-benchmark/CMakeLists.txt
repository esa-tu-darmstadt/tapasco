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

cmake_minimum_required(VERSION 2.6)
project(tapasco-logging-benchmark)

set (TAPASCO_HOME_RUNTIME "$ENV{TAPASCO_HOME_RUNTIME}")
set (ARCH "${CMAKE_SYSTEM_PROCESSOR}")

include_directories(../../include)
link_directories("${TAPASCO_HOME_RUNTIME}/arch/lib/${ARCH}" "${TAPASCO_HOME_RUNTIME}/platform/lib/${ARCH}")

add_executable(tapasco-logging-benchmark tapasco_logging_benchmark.c)
target_link_libraries(tapasco-logging-benchmark pthread platform tapasco)
set_source_files_properties(tapasco_logging_benchmark.c PROPERTIES COMPILE_FLAGS "-Wall -Werror -g -O3 -std=gnu11 -Wno-unused-variable")
