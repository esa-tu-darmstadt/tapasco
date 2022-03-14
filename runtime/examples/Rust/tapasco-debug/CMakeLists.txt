# Copyright (c) 2014-2021 Embedded Systems and Applications, TU Darmstadt.
#
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

cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
project(tapasco-debug)

# Add a Rust/Cargo project to CMake watching all files in the current directory because Cargo already doesn't do anything if nothing has changed.
add_executable(tapasco-debug .)

# Use Cargo to build this project in debug mode by defining a custom target running after the tapasco target has been built.
add_custom_target(tapasco_debug_cargo_build_debug   COMMAND CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR} cargo build -q --debug   WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR} DEPENDS tapasco COMMENT "Building tapasco-debug with Cargo")

# Use Cargo to build this project in release mode by defining a custom target running after the tapasco target has been built.
add_custom_target(tapasco_debug_cargo_build_release COMMAND CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR} cargo build -q --release WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR} DEPENDS tapasco COMMENT "Building tapasco-debug with Cargo")

# Check if building should be in Debug or Release mode
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(TARGET_DIR "debug")
  add_dependencies(tapasco-debug tapasco_debug_cargo_build_debug)
else()
  set(TARGET_DIR "release")
  add_dependencies(tapasco-debug tapasco_debug_cargo_build_release)
endif()


# This tells CMake that this is a C++ executable (but it's Rust) because CMake really wants to know how to link this executable
set_target_properties(tapasco-debug PROPERTIES CXX_STANDARD 11 CXX_STANDARD_REQUIRED ON LINKER_LANGUAGE CXX)
# but it has already been linked by Cargo, so we then tell CMake to use the most failure-proof linker available (none, it's just /usr/bin/true).
# You can't tell CMake not to link this at all, so this is the dirty workaround:
set(CMAKE_CXX_LINK_EXECUTABLE "true")

# Install the executable in the TaPaSCo PATH
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/tapasco-debug
	DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/bin)
