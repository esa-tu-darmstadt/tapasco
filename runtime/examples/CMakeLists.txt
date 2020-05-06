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
project(examples)

add_subdirectory(C/arrayinit)
add_subdirectory(C/arraysum)
add_subdirectory(C/arrayupdate)
add_subdirectory(C/cffitest)
add_subdirectory(C++/arrayinit)
add_subdirectory(C++/arraysum)
add_subdirectory(C++/arrayupdate)
add_subdirectory(C++/memcheck)
add_subdirectory(C++/tapasco-benchmark)
add_subdirectory(C++/tapasco-debug)
add_subdirectory(C++/bandwidth)
add_subdirectory(C++/job_completion)
add_subdirectory(C++/start_latency)
