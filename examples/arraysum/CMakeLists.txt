cmake_minimum_required(VERSION 3.0)
project (arraysum)

find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

include_directories(../../kernel/arraysum)

add_executable(arraysum arraysum-example.c ../../kernel/arraysum/arraysum.c)
target_link_libraries(arraysum rt pthread tapasco platform atomic)

install(TARGETS arraysum
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
