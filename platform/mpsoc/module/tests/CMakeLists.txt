cmake_minimum_required(VERSION 2.7)
project(platform-zynq-module-tests)
include_directories("..")

find_library(NCURSESLIB ncurses)

add_executable(stress-alloc stress-alloc.c)
target_link_libraries(stress-alloc pthread m)

add_executable(stress-ioctl stress-ioctl.c)
target_link_libraries(stress-ioctl pthread ncurses)
