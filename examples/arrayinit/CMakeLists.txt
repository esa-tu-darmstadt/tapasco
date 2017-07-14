cmake_minimum_required(VERSION 2.6)
project(arrayinit)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

include_directories(../../kernel/arrayinit)

add_executable(arrayinit arrayinit-example.c ../../kernel/arrayinit/arrayinit.c)
target_link_libraries(arrayinit rt pthread tapasco platform atomic)
set_target_properties(arrayinit PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

add_executable(arrayinit-mt arrayinit-example-mt.c ../../kernel/arrayinit/arrayinit.c)
target_link_libraries(arrayinit-mt rt pthread tapasco platform atomic)
set_target_properties(arrayinit-mt PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label")

install(TARGETS arrayinit
        RUNTIME DESTINATION bin/${ARCH})
