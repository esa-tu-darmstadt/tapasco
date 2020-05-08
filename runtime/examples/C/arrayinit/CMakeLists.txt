cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include(${CMAKE_CURRENT_LIST_DIR}/../../../cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (arrayinit)

if(NOT TARGET tapasco)
    find_package(Tapasco REQUIRED)
endif()

find_package (Threads)

add_executable(arrayinit arrayinit-example.c)
set_tapasco_defaults(arrayinit)
target_link_libraries(arrayinit tapasco ${CMAKE_THREAD_LIBS_INIT})

install(TARGETS arrayinit
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

