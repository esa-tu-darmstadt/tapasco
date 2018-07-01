cmake_minimum_required(VERSION 3.0)
project (benchmark-cd)

find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(benchmark-cd benchmark-cd.c)
target_link_libraries(benchmark-cd rt pthread tapasco platform)

install(TARGETS benchmark-cd
        RUNTIME DESTINATION bin/)
