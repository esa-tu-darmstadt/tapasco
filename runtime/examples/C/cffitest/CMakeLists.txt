cmake_minimum_required(VERSION 3.0)

project(cffitest)

if(NOT TARGET tapasco)
  find_package(Tapasco REQUIRED)
endif()

add_executable(ctest ctest.c)
target_link_libraries(ctest tapasco)
