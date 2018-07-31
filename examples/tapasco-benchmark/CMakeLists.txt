cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (tapasco-benchmark)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(tapasco-benchmark tapasco_benchmark.cpp ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.cpp)
target_include_directories(tapasco-benchmark PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/json11)
set_tapasco_defaults(tapasco-benchmark)
target_link_libraries(tapasco-benchmark PRIVATE tapasco pthread atomic)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.cpp ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.hpp
  COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/json11
  COMMAND git clone https://github.com/dropbox/json11.git ${CMAKE_CURRENT_BINARY_DIR}/json11
  )

include(GNUInstallDirs)

install (TARGETS tapasco-benchmark
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})
