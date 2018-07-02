cmake_minimum_required(VERSION 3.0)
project (memcheck)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(memcheck memcheck.c)
target_link_libraries(memcheck tapasco pthread platform tlkm)

add_executable(memcheck-mt memcheck-mt.c)
target_link_libraries(memcheck-mt pthread tapasco platform tlkm)

install(TARGETS memcheck memcheck-mt
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

