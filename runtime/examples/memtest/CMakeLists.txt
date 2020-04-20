cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (memtest)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

add_executable(memtest memtest.cpp)
set_tapasco_defaults(memtest)
target_link_libraries(memtest PRIVATE tapasco tlkm platform tapasco-common)

install(TARGETS memtest
        ARCHIVE  DESTINATION share/Tapasco/bin/
        LIBRARY  DESTINATION share/Tapasco/bin/
        RUNTIME  DESTINATION share/Tapasco/bin/)

add_executable(memtest_parallel memtest_parallel.cpp)
set_tapasco_defaults(memtest_parallel)
target_link_libraries(memtest_parallel PRIVATE tapasco tlkm platform tapasco-common)

install(TARGETS memtest_parallel
	ARCHIVE DESTINATION share/Tapasco/bin/
	LIBRARY DESTINATION share/Tapasco/bin/
	RUNTIME DESTINATION share/Tapasco/bin/)
