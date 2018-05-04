cmake_minimum_required(VERSION 3.0)
project (arrayupdate)

find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(arrayupdate arrayupdate-example.c ../../kernel/arrayupdate/arrayupdate.c)

target_include_directories(arrayupdate PRIVATE ../../kernel/arrayupdate)
target_link_libraries(arrayupdate rt pthread tapasco platform atomic)

install(TARGETS arrayupdate
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
