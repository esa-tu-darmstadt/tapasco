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

if(POLICY CMP0069)
  cmake_policy(SET CMP0069 NEW)
endif()

function(set_tapasco_defaults target_name)
    target_compile_options(${target_name} PRIVATE $<$<CXX_COMPILER_ID:GNU>:-Wall>
                                           $<$<CXX_COMPILER_ID:GNU>:-Werror>)
    target_compile_options(${target_name} PRIVATE $<$<C_COMPILER_ID:GNU>:-Wall>
                                       $<$<C_COMPILER_ID:GNU>:-Werror>)
    set_target_properties(${target_name} PROPERTIES DEBUG_POSTFIX d)
    set_target_properties(${target_name} PROPERTIES CXX_STANDARD 11 CXX_STANDARD_REQUIRED ON)
    set_target_properties(${target_name} PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED ON)

    target_compile_definitions(${target_name} PRIVATE -DLOG_USE_COLOR)

    if(${CMAKE_VERSION} VERSION_LESS "3.9.0")
    else()
        include(CheckIPOSupported)
        check_ipo_supported(RESULT ipo_supported)
        if(ipo_supported)
            set_target_properties(${target_name} PROPERTIES INTERPROCEDURAL_OPTIMIZATION TRUE)
        else()
            message(WARNING "IPO is not supported!")
        endif()
    endif()
endfunction(set_tapasco_defaults)
