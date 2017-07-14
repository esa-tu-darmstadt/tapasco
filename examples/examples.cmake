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
set(ARCH "${CMAKE_SYSTEM_PROCESSOR}")

if ("$ENV{TAPASCO_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TAPASCO_HOME to root directory of Tapasco.")
endif ("$ENV{TAPASCO_HOME}" STREQUAL "")
set(TAPASCO_HOME "$ENV{TAPASCO_HOME}")

# link_directories(${TAPASCO_HOME}/arch/lib/${ARCH}/static ${TAPASCO_HOME}/platform/lib/${ARCH}/static)
link_directories(${TAPASCO_HOME}/arch/lib/${ARCH}  ${TAPASCO_HOME}/platform/lib/${ARCH})

include_directories(${TAPASCO_HOME}/arch/common/include ${TAPASCO_HOME}/platform/common/include)
