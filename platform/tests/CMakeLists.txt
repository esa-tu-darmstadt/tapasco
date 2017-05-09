cmake_minimum_required(VERSION 2.7)
project(libplatform-tests)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)
set(CMAKE_C_FLAGS_RELEASE "-DNDEBUG -O3 -flto")

if ("$ENV{TPC_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var TPC_HOME to root directory of ThreadPoolComposer.")
endif ("$ENV{TPC_HOME}" STREQUAL "")

if ("$ENV{TPC_PLATFORM}" STREQUAL "VC709")
  message(STATUS "Building for VC709 platform ...")
  set (CFLAGS "-g -Wall -Werror -std=gnu99 -DVC709")
else ("$ENV{TPC_PLATFORM}" STREQUAL "VC709")
  message(STATUS "Building for Zynq platform ...")
  set (CFLAGS "-g -Wall -Werror -std=gnu99")
endif ("$ENV{TPC_PLATFORM}" STREQUAL "VC709")

set(TPC_HOME "$ENV{TPC_HOME}")
set(ARCH "${CMAKE_SYSTEM_PROCESSOR}")
message ("arch = ${ARCH}")

include_directories(${TPC_HOME}/platform/common/include)
link_directories(${TPC_HOME}/platform/lib/${ARCH}/static)

add_executable(platform-stress-alloc platform_stress_alloc.c)
target_link_libraries(platform-stress-alloc m pthread platform atomic)

add_executable(platform-slots platform_slots.c)
target_link_libraries(platform-slots pthread platform atomic)

add_executable(iplatform iplatform.c)
target_link_libraries(iplatform pthread platform ncurses atomic)

set_target_properties(platform-stress-alloc platform-slots iplatform PROPERTIES COMPILE_FLAGS ${CFLAGS})
install(TARGETS platform-stress-alloc platform-slots
        RUNTIME DESTINATION bin/${ARCH})
