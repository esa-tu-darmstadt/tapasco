project(platform VERSION 1.0 LANGUAGES C CXX)

SET(PLATFORM "pcie" CACHE STRING "Please select the target platform.")

SET(PLATFORM_COMMON_SRC "common")

SET(SRCS "${PLATFORM_COMMON_SRC}/src/platform_logging.c"
         "${PLATFORM_COMMON_SRC}/src/platform_errors.c"
          "${CMNDIR}/src/gen_queue.c"
          "${PLATFORM_COMMON_SRC}/src/platform_version.c"
          "${PLATFORM_COMMON_SRC}/src/platform_addr_map.c"
          "${PLATFORM_COMMON_SRC}/src/platform_context.c"
          "${PLATFORM_COMMON_SRC}/src/platform_info.c"
          "${PLATFORM_COMMON_SRC}/src/platform_async.c"
    )

include(${PLATFORM}/platform.cmake)

add_library(platform ${SRCS})

target_include_directories(platform PUBLIC ${EXTRA_INCLUDES_PUBLIC} $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_COMMON_SRC}/include> $<INSTALL_INTERFACE:${PLATFORM_COMMON_SRC}/include> PRIVATE "${CMNDIR}/include" ${EXTRA_INCLUDES_PRIVATE})

target_link_libraries(platform pthread atomic)

install(TARGETS platform EXPORT TapascoPlatformConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})

install(EXPORT TapascoPlatformConfig DESTINATION share/Tapasco/cmake)

export(TARGETS platform FILE TapascoPlatformConfig.cmake)