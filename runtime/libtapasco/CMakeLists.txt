cmake_minimum_required(VERSION 3.0)

project(
  tapasco
  VERSION 2.0
  LANGUAGES C CXX)

include(TapascoInner.cmake)

add_library(tapasco STATIC ${CMAKE_CURRENT_BINARY_DIR}/unused.c)
add_dependencies(tapasco tapasco_rust)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/unused.c
  COMMENT "Creating dummy file to force build"
  COMMAND echo "" | tee ${CMAKE_CURRENT_BINARY_DIR}/unused.c)

add_custom_command(
  TARGET tapasco
  POST_BUILD
  COMMENT "Replacing libtapasco.a"
  COMMAND  ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_DIR}/libtapasco.a
          ${CMAKE_CURRENT_BINARY_DIR}/
  COMMAND  ${CMAKE_COMMAND} -E remove -f ${CMAKE_CURRENT_BINARY_DIR}/unused.c)

target_include_directories(
  tapasco
  PUBLIC $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/tapasco>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/>
         $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/>)

if(NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/rust_links.cmake)
  set(RUST_LINK "-lutil -ldl -lutil -ldl -lrt -lpthread -lgcc_s -lc -lm -lrt -lpthread -lutil -lutil")
else()
  include(${CMAKE_CURRENT_BINARY_DIR}/rust_links.cmake)
endif()

target_link_libraries(tapasco PUBLIC ${RUST_LINK})

set_property(
  TARGET tapasco
  PROPERTY PUBLIC_HEADER ${CMAKE_CURRENT_BINARY_DIR}/tapasco.h
           ${CMAKE_CURRENT_BINARY_DIR}/tapasco_inner.hpp
           ${CMAKE_CURRENT_SOURCE_DIR}/src/tapasco.hpp
           ${CMAKE_CURRENT_SOURCE_DIR}/src/plugins/tapasco-nvme.hpp)

include(GNUInstallDirs)

install(
  TARGETS tapasco
  EXPORT tapasco-export
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/)

install(
  EXPORT tapasco-export
  FILE TapascoConfig.cmake
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/Tapasco/cmake)
