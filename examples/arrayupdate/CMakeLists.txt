cmake_minimum_required(VERSION 3.0)
project (arrayupdate)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(arrayupdate arrayupdate-example.c)
target_link_libraries(arrayupdate tapasco pthread platform tlkm)

install(TARGETS arrayupdate
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

