cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (image-processing)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable (imgproc imgproc.cpp cliparser.cpp stringtools.cpp ${CMAKE_CURRENT_BINARY_DIR}/png++/png.hpp)
target_include_directories(imgproc PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/)
set_tapasco_defaults(imgproc)
target_link_libraries (imgproc PRIVATE tapasco tlkm platform tapasco-common pthread atomic png)

add_executable (print_status print_status.cpp)
set_tapasco_defaults(print_status)
target_link_libraries (print_status PRIVATE tapasco tlkm platform tapasco-common pthread atomic)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/png++/png.hpp
  COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/png++
  COMMAND wget -O ${CMAKE_CURRENT_BINARY_DIR}/png++.tgz "http://download.savannah.nongnu.org/releases/pngpp/png++-0.2.9.tar.gz"
  COMMAND tar xf ${CMAKE_CURRENT_BINARY_DIR}/png++.tgz
  COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/png++-0.2.9 ${CMAKE_CURRENT_BINARY_DIR}/png++
  )
