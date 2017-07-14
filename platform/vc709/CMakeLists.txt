cmake_minimum_required(VERSION 2.6)
project(platform-vc709)
set(CMAKE_INSTALL_PREFIX "..")
set(CMAKE_SKIP_RPATH true)

if (NOT EXISTS "$ENV{TAPASCO_HOME}")
  message(FATAL_ERROR "Please set TAPASCO_HOME environment variable to root directory of Tapasco")
endif (NOT EXISTS "$ENV{TAPASCO_HOME}")

include ("$ENV{TAPASCO_HOME}/cmake/Tapasco.cmake")

set(SRCDIR "src")
set(C_COMPFLAGS "-g -O3 -Wall -Werror -std=gnu11")
set(CXX_COMPFLAGS "-g -O3 -Wall -Werror -std=c++11 -Wno-write-strings")
set(CMNDIR "../common")
set(GCMNDIR "${TAPASCO_HOME}/common")
set(FFLINKDIR "module")
set(BUDDYDIR "${SRCDIR}/buddy_allocator")
set(PLATFORM_LIBS_DIR "${TAPASCO_HOME}/platform/lib")
set(CMNSRCS "${CMNDIR}/src/platform_logging.c"
            "${CMNDIR}/src/platform_errors.c"
            "${GCMNDIR}/src/gen_queue.c"
            "${CMNDIR}/src/platform_version.c")
set(SRCS "${SRCDIR}/platform_vc709.cpp"
         "${BUDDYDIR}/buddy_allocator.cpp"
	 "${BUDDYDIR}/buddy_tree.cpp"
	 "${BUDDYDIR}/logger.cpp")

add_library(platform SHARED ${CMNSRCS} ${SRCS})
add_library(libplatform-static STATIC ${CMNSRCS} ${SRCS})

include_directories("." "include" "${CMNDIR}/include"  "${FFLINKDIR}/include" "${BUDDYDIR}" "${GCMNDIR}/include")

set_source_files_properties(${CMNSRCS} PROPERTIES COMPILE_FLAGS ${C_COMPFLAGS})
set_source_files_properties(${SRCS} PROPERTIES COMPILE_FLAGS ${CXX_COMPFLAGS})

target_link_libraries(platform pthread atomic)
target_link_libraries(libplatform-static pthread atomic)

set_target_properties(libplatform-static PROPERTIES OUTPUT_NAME platform)

install(TARGETS platform libplatform-static
        LIBRARY DESTINATION "lib/${TAPASCO_TARGET}"
        ARCHIVE DESTINATION "lib/${TAPASCO_TARGET}/static")

get_filename_component(LIBSDIR "lib" REALPATH)
add_custom_command(OUTPUT ${PLATFORM_LIBS_DIR}
                   COMMAND ln;-fs;${LIBSDIR};${PLATFORM_LIBS_DIR})
add_custom_target(install_libs ALL DEPENDS platform libplatform-static ${PLATFORM_LIBS_DIR})
