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
cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project(examples)

add_subdirectory(arrayinit)
add_subdirectory(arraysum)
add_subdirectory(arrayupdate)
add_subdirectory(memcheck)
add_subdirectory(tapasco-benchmark)
add_subdirectory(tapasco-debug)
add_subdirectory(bandwidth)
add_subdirectory(job_completion)
add_subdirectory(start_latency)