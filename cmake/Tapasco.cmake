#
# Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TaPaSCo).
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

# don't link with full path
set (CMAKE_SKIP_RPATH true)

# basic directory variables
set (TAPASCO_HOME "$ENV{TAPASCO_HOME}")
set (TAPASCO_TLKM_DIR		"${TAPASCO_HOME}/tlkm")
set (TAPASCO_COMMON_DIR 	"${TAPASCO_HOME}/common")
set (TAPASCO_LIB_DIR	 	"${TAPASCO_HOME}/lib")
set (TAPASCO_PLATFORM_DIR 	"${TAPASCO_HOME}/platform")
set (TAPASCO_ARCH_DIR		"${TAPASCO_HOME}/arch")

# set target architecture
if (NOT EXISTS "$ENV{TAPASCO_TARGET}")
  message (STATUS "TAPASCO_TARGET environment variable not set, using ${CMAKE_SYSTEM_PROCESSOR}")
  set (TAPASCO_TARGET "${CMAKE_SYSTEM_PROCESSOR}")
else (NOT EXISTS "$ENV{TAPASCO_TARGET}")
  set (TAPASCO_TARGET "$ENV{TAPASCO_TARGET}")
endif (NOT EXISTS "$ENV{TAPASCO_TARGET}")

# static libraries
set (TAPASCO_PLATFORM_LIB "${TAPASCO_LIB_DIR}/${TAPASCO_TARGET}/static/libplatform.a")
set (TAPASCO_ARCH_LIB "${TAPASCO_LIB_DIR}/${TAPASCO_TARGET}/static/libtapasco.a")

# basic include directories
set (TAPASCO_INCDIRS
	"${TAPASCO_TLKM_DIR}"
	"${TAPASCO_TLKM_DIR}/user"
	"${TAPASCO_COMMON_DIR}/include"
	"${TAPASCO_PLATFORM_DIR}/include"
	"${TAPASCO_ARCH_DIR}/include"
)

# directories for static libraries
set (TAPASCO_STATICLINKDIRS
	"${TAPASCO_LIB_DIR}/${TAPASCO_TARGET}/static"
)

# directories for dynamic link libraries
set (TAPASCO_LINKDIRS
	"${TAPASCO_LIB_DIR}/${TAPASCO_TARGET}"
)

# default C flags
set (TAPASCO_CFLAGS   "-Wall -Werror -g -std=gnu11 -fPIC")
# default C++ flags
set (TAPASCO_CXXFLAGS "-Wall -Werror -g -std=c++11 -fPIC -Wno-write-strings -fno-rtti")
# default linker flags (activates link-time optimizations)
set (TAPASCO_LDFLAGS  "-flto -static-libstdc++ -static-libgcc")

# used to analyze the code using clang instead of actually building
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
