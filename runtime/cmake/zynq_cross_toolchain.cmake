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

cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

find_program(GNUEABIHF_GCC arm-linux-gnueabihf-gcc)
if(${GNUEABIHF_GCC} MATCHES "GNUEABIHF_GCC-NOTFOUND")
    set(CMAKE_C_COMPILER arm-linux-gnu-gcc)
else()
    set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)
endif()

find_program(GNUEABIHF_GPP arm-linux-gnueabihf-g++)
if(${GNUEABIHF_GPP} MATCHES "GNUEABIHF_GPP-NOTFOUND")
    set(CMAKE_CXX_COMPILER arm-linux-gnu-g++)
else()
    set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
endif()
