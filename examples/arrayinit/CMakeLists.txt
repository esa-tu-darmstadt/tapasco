cmake_minimum_required(VERSION 3.0)
project (arrayinit)

find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

include_directories(../../kernel/arrayinit)

add_executable(arrayinit arrayinit-example.c ../../kernel/arrayinit/arrayinit.c)
target_link_libraries(arrayinit rt pthread tapasco platform atomic)

install(TARGETS arrayinit
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
