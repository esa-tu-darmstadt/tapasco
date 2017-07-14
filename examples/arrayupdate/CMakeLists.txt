cmake_minimum_required(VERSION 2.6)
project(arrayupdate)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

include_directories(../../kernel/arrayupdate)

add_executable(arrayupdate arrayupdate-example.c ../../kernel/arrayupdate/arrayupdate.c)
target_link_libraries(arrayupdate rt pthread tapasco platform atomic)
set_target_properties(arrayupdate PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

add_executable(arrayupdate-mt arrayupdate-example-mt.c ../../kernel/arrayupdate/arrayupdate.c)
target_link_libraries(arrayupdate-mt rt pthread tapasco platform atomic)
set_target_properties(arrayupdate-mt PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

install(TARGETS arrayupdate arrayupdate-mt
        RUNTIME DESTINATION bin/${ARCH})
