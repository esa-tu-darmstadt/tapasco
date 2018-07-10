cmake_minimum_required(VERSION 3.0)
project (benchmark-mem)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable (benchmark-mem benchmark-mem.c)
target_link_libraries (benchmark-mem m rt pthread tapasco platform)

add_executable (benchmark-mem++ benchmark-mem.cpp)
target_link_libraries (benchmark-mem++ m rt pthread tapasco platform)

install (TARGETS benchmark-mem benchmark-mem++
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

