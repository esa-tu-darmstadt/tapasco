cmake_minimum_required (VERSION 2.7)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

add_executable(memcheck memcheck.c)
set_target_properties(memcheck PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99")
target_link_libraries(memcheck tapasco pthread platform)

add_executable(memcheck-mt memcheck-mt.c)
set_target_properties(memcheck-mt PROPERTIES COMPILE_FLAGS "-g -Wall -Werror -std=gnu99")
target_link_libraries(memcheck-mt pthread tapasco platform pthread)

install(TARGETS memcheck memcheck-mt
        RUNTIME DESTINATION bin/${CMAKE_SYSTEM_PROCESSOR})

