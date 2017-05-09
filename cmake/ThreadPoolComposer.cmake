#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
#
# This file is part of ThreadPoolComposer (TPC).
#
# ThreadPoolComposer is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ThreadPoolComposer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
#
if (NOT EXISTS "$ENV{TPC_HOME}")
  message (FATAL_ERROR "Please set TPC_HOME environment variable to root directory of ThreadPoolComposer")
endif (NOT EXISTS "$ENV{TPC_HOME}")

set (CMAKE_SKIP_RPATH true)
set (TPC_HOME "$ENV{TPC_HOME}")
if (NOT EXISTS "$ENV{TPC_TARGET}")
  message (STATUS "TPC_TARGET environment variable not set, using ${CMAKE_SYSTEM_PROCESSOR}")
  set (TPC_TARGET "${CMAKE_SYSTEM_PROCESSOR}")
else (NOT EXISTS "$ENV{TPC_TARGET}")
  set (TPC_TARGET "$ENV{TPC_TARGET}")
endif (NOT EXISTS "$ENV{TPC_TARGET}")

if (${ANALYZE})
  message ("Static analysis pass, skipping build.")
  set (TPC_ANALYZE_ONLY true)
  find_path (CLANG_PATH "clang")
  set (CMAKE_C_COMPILER "clang")
  set (CMAKE_CXX_COMPILER "clang")
  set (TPC_ANALYSIS_FLAGS "--analyze -Wall -Werror")
  set (CMAKE_CXX_FLAGS "--stdlib=libc++")
  add_definitions (${TPC_ANALYSIS_FLAGS})
endif (${ANALYZE})
