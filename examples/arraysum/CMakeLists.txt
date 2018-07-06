cmake_minimum_required(VERSION 3.0)
project (arraysum)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(arraysum arraysum-example.c)
target_link_libraries(arraysum tapasco pthread platform tlkm)

install(TARGETS arraysum
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

