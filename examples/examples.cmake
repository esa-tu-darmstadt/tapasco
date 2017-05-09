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
set(ARCH "${CMAKE_SYSTEM_PROCESSOR}")

if ("$ENV{TPC_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TPC_HOME to root directory of ThreadPoolComposer.")
endif ("$ENV{TPC_HOME}" STREQUAL "")
set(TPC_HOME "$ENV{TPC_HOME}")

if (${REQUIRES_FASTFLOW})
if ("$ENV{FF_ROOT}" STREQUAL "")
  message(FATAL_ERROR "Please set env var FF_ROOT to root directory of FastFlow.")
endif ("$ENV{FF_ROOT}" STREQUAL "")
set(FF_ROOT "$ENV{FF_ROOT}")
endif (${REQUIRES_FASTFLOW})

# link_directories(${TPC_HOME}/arch/lib/${ARCH} ${TPC_HOME}/arch/lib/${ARCH}/static ${TPC_HOME}/platform/lib/${ARCH} ${TPC_HOME}/platform/lib/${ARCH}/static)
link_directories(${TPC_HOME}/arch/lib/${ARCH}/static  ${TPC_HOME}/platform/lib/${ARCH}/static)

include_directories(${TPC_HOME}/arch/common/include ${TPC_HOME}/platform/common/include ${FF_ROOT})

