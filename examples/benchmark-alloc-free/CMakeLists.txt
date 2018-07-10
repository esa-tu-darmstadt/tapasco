cmake_minimum_required(VERSION 3.0)
project (benchmark-alloc-dealloc)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable (benchmark-alloc-dealloc benchmark-alloc-dealloc.c)
target_link_libraries (benchmark-alloc-dealloc m rt pthread tapasco platform)

install (TARGETS benchmark-alloc-dealloc
         RUNTIME DESTINATION bin/)

