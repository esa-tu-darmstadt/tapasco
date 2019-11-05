cmake_minimum_required(VERSION 3.0)
project (programSI5324)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(programSI5324 programSI5324.cpp)
target_link_libraries (programSI5324 PRIVATE tapasco platform pthread atomic ncurses)

install(TARGETS programSI5324
        RUNTIME DESTINATION bin/)

