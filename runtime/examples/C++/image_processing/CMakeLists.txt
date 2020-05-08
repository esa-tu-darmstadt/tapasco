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
include(${CMAKE_CURRENT_LIST_DIR}/../../../cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (image-processing)

if(NOT TARGET tapasco)
    find_package(Tapasco REQUIRED)
endif ()

find_package(PNG)
find_package (Threads)

add_executable (imgproc imgproc.cpp cliparser.cpp stringtools.cpp ${CMAKE_CURRENT_BINARY_DIR}/CImg/CImg.h)
target_include_directories(imgproc PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/)
set_tapasco_defaults(imgproc)
target_link_libraries (imgproc PRIVATE tapasco tlkm platform tapasco-common ${CMAKE_THREAD_LIBS_INIT} PNG::PNG)

add_executable (print_status print_status.cpp)
set_tapasco_defaults(print_status)
target_link_libraries (print_status PRIVATE tapasco tlkm platform tapasco-common ${CMAKE_THREAD_LIBS_INIT})

target_compile_definitions(imgproc PRIVATE -Dcimg_display=0)

IF(PNG_FOUND)
    target_compile_definitions(imgproc PRIVATE -Dcimg_use_png)
ENDIF()

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/CImg/CImg.h
  COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/CImg
  COMMAND wget -O ${CMAKE_CURRENT_BINARY_DIR}/CImg.zip "http://cimg.eu/files/CImg_latest.zip"
  COMMAND unzip ${CMAKE_CURRENT_BINARY_DIR}/CImg.zip
  COMMAND mv "${CMAKE_CURRENT_BINARY_DIR}/CImg-*" ${CMAKE_CURRENT_BINARY_DIR}/CImg
  COMMAND rm -f ${CMAKE_CURRENT_BINARY_DIR}/CImg.zip
  )
