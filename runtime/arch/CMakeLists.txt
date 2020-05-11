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
project(arch-axi4mm VERSION 1.0 LANGUAGES C CXX)

set(PCMNDIR "common/src")

set(AXI4MM_SOURCES "axi4mm/src/tapasco_regs.c")
set(COMMON_SOURCES "${PCMNDIR}/tapasco_context.c"
                   "${PCMNDIR}/tapasco_delayed_transfers.c"
                   "${PCMNDIR}/tapasco_device.c"
                   "${PCMNDIR}/tapasco_errors.c"
                   "${PCMNDIR}/tapasco_jobs.c"
	                 "${PCMNDIR}/tapasco_logging.c"
                   "${PCMNDIR}/tapasco_local_mem.c"
                   "${PCMNDIR}/tapasco_memory.c"
                   "${PCMNDIR}/tapasco_pemgmt.c"
                   "${PCMNDIR}/tapasco_scheduler.c"
                   "${PCMNDIR}/tapasco_version.c"
                   "${PCMNDIR}/tapasco_perfc.c"
                   )

add_library(tapasco ${AXI4MM_SOURCES} ${COMMON_SOURCES})

target_include_directories(tapasco PUBLIC "$<INSTALL_INTERFACE:include/tapasco>"
                                          "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
                                          "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/common/include>"
                          )

set_property(TARGET tapasco PROPERTY PUBLIC_HEADER include/tapasco_errors.h
                                                   include/tapasco_global.h
                                                   include/tapasco.h
                                                   include/tapasco.hpp
                                                   include/tapasco_types.h
                                                   common/include/tapasco_context.h
                                                   common/include/khash.h
                                                  common/include/tapasco_context.h
                                                  common/include/tapasco_delayed_transfers.h
                                                  common/include/tapasco_device.h
                                                  common/include/tapasco_jobs.h
                                                  common/include/tapasco_local_mem.h
                                                  common/include/tapasco_logging.h
                                                  common/include/tapasco_memory.h
                                                  common/include/tapasco_pemgmt.h
                                                  common/include/tapasco_perfc.h
                                                  common/include/tapasco_regs.h
                                                  common/include/tapasco_scheduler.h)

target_compile_definitions(tapasco PRIVATE -DUSE_ASSERTIONS)
target_compile_definitions(tapasco PRIVATE -DLOG_USE_COLOR)
target_compile_definitions(tapasco PRIVATE -DNPERFC)

set_tapasco_defaults(tapasco)

find_package (Threads)

target_link_libraries(tapasco PUBLIC tlkm platform tapasco-common PRIVATE atomic ${CMAKE_THREAD_LIBS_INIT})

install(TARGETS tapasco EXPORT TapascoConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco
        )

install(EXPORT TapascoConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tapasco FILE TapascoConfig.cmake)