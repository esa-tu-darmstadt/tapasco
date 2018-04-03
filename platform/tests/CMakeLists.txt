cmake_minimum_required(VERSION 2.8)
project(libplatform-tests)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)

if ("$ENV{TAPASCO_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TAPASCO_HOME to root directory of Tapasco.")
endif ("$ENV{TAPASCO_HOME}" STREQUAL "")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

include_directories(${TAPASCO_INCDIRS})
link_directories(${TAPASCO_LINKDIRS} ${TAPASCO_STATICLINKDIRS})

add_executable(platform-stress-alloc platform_stress_alloc.c ${TAPASCO_PLATFORM_LIB})
set_target_properties(platform-stress-alloc PROPERTIES
		LINK_SEARCH_START_STATIC 1
		LINK_SEARCH_END_STATIC 1
		LINKER_FLAGS ${TAPASCO_LDFLAGS})
target_link_libraries(platform-stress-alloc atomic m pthread platform)

add_executable(platform-slots platform_slots.c ${TAPASCO_PLATFORM_LIB})
target_link_libraries(platform-slots pthread platform)

add_executable(iplatform iplatform.c)
target_link_libraries(iplatform pthread platform ncurses ${TAPASCO_PLATFORM_LIB})

set_target_properties(platform-stress-alloc platform-slots iplatform PROPERTIES COMPILE_FLAGS ${TAPASCO_CFLAGS})
install(TARGETS platform-stress-alloc platform-slots
        RUNTIME DESTINATION bin/${TAPASCO_TARGET})
