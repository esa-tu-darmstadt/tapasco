cmake_minimum_required(VERSION 3.0)
project (arrayinit)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(arrayinit arrayinit-example.c)
target_link_libraries(arrayinit tapasco pthread platform tlkm)

install(TARGETS arrayinit
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

