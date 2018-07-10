cmake_minimum_required(VERSION 3.0)
project (basic_test)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(basic_test basic_test.cpp)
target_link_libraries(basic_test rt pthread tapasco platform atomic)

install(TARGETS basic_test
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
