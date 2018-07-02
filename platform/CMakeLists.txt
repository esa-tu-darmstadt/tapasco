project(platform VERSION 1.0 LANGUAGES C CXX)

SET(PLATFORM_COMMON_SRC "common")

SET(SRCS  "${CMNDIR}/src/gen_queue.c"
          "${PLATFORM_COMMON_SRC}/src/platform_addr_map.c"
          "${PLATFORM_COMMON_SRC}/src/platform_devctx.c"             
          "${PLATFORM_COMMON_SRC}/src/platform_errors.c" 
          "${PLATFORM_COMMON_SRC}/src/platform_logging.c"  
          "${PLATFORM_COMMON_SRC}/src/platform_signaling.c"
          "${PLATFORM_COMMON_SRC}/src/platform_ctx.c"       
          "${PLATFORM_COMMON_SRC}/src/platform_device_operations.c"  
          "${PLATFORM_COMMON_SRC}/src/platform_info.c"    
          "${PLATFORM_COMMON_SRC}/src/platform_perfc.c"    
          "${PLATFORM_COMMON_SRC}/src/platform_version.c"
    )

include(pcie/platform.cmake)
include(zynq/platform.cmake)

add_library(platform ${SRCS})

target_include_directories(platform PUBLIC ${EXTRA_INCLUDES_PUBLIC} $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<INSTALL_INTERFACE:include> $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_COMMON_SRC}/include> $<INSTALL_INTERFACE:${PLATFORM_COMMON_SRC}/include> PRIVATE "${CMNDIR}/include" ${EXTRA_INCLUDES_PRIVATE})

target_link_libraries(platform tlkm pthread atomic)

install(TARGETS platform EXPORT TapascoPlatformConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})

install(EXPORT TapascoPlatformConfig DESTINATION share/Tapasco/cmake)

export(TARGETS platform FILE TapascoPlatformConfig.cmake)
