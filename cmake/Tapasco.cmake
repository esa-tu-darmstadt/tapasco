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
if (NOT EXISTS "$ENV{TAPASCO_HOME}")
  message (FATAL_ERROR "Please set TAPASCO_HOME environment variable to root directory of Tapasco")
endif (NOT EXISTS "$ENV{TAPASCO_HOME}")

set (CMAKE_SKIP_RPATH true)
set (TAPASCO_HOME "$ENV{TAPASCO_HOME}")
if (NOT EXISTS "$ENV{TAPASCO_TARGET}")
  message (STATUS "TAPASCO_TARGET environment variable not set, using ${CMAKE_SYSTEM_PROCESSOR}")
  set (TAPASCO_TARGET "${CMAKE_SYSTEM_PROCESSOR}")
else (NOT EXISTS "$ENV{TAPASCO_TARGET}")
  set (TAPASCO_TARGET "$ENV{TAPASCO_TARGET}")
endif (NOT EXISTS "$ENV{TAPASCO_TARGET}")

if (${ANALYZE})
  message ("Static analysis pass, skipping build.")
  set (TAPASCO_ANALYZE_ONLY true)
  find_path (CLANG_PATH "clang")
  set (CMAKE_C_COMPILER "clang")
  set (CMAKE_CXX_COMPILER "clang")
  set (TAPASCO_ANALYSIS_FLAGS "--analyze -Wall -Werror")
  set (CMAKE_CXX_FLAGS "--stdlib=libc++")
  add_definitions (${TAPASCO_ANALYSIS_FLAGS})
endif (${ANALYZE})
