cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)

project(platform VERSION 1.0 LANGUAGES C)

add_library(platform "common/src/platform_addr_map.c"
          "common/src/platform_devctx.c"
          "common/src/platform_errors.c"
          "common/src/platform_logging.c"
          "common/src/platform_signaling.c"
          "common/src/platform_ctx.c"
          "common/src/platform_device_operations.c"
          "common/src/platform_info.c"
          "common/src/platform_perfc.c"
          "common/src/platform_version.c"
          "common/src/platform_components.c"
          "common/nanopb/pb_common.c"
          "common/nanopb/pb_encode.c"
          "common/nanopb/pb_decode.c"
          "common/nanopb/status_core.pb.c"
          )

target_compile_definitions(platform PRIVATE -DNPERFC)
target_compile_definitions(platform PRIVATE -DLOG_USE_COLOR)
if(CMAKE_BUILD_TYPE MATCHES "Release" AND (CMAKE_SYSTEM_PROCESSOR MATCHES "arm" OR CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64"))
  message("Reducing optimization for nanopb on zynq plattform.")
  target_compile_options(platform PRIVATE -O2)
endif()

set_tapasco_defaults(platform)

set_property(TARGET platform PROPERTY PUBLIC_HEADER
                              include/platform_caps.h
                              include/platform_components.h
                              include/platform_devctx.h
                              include/platform_device_operations.h
                              include/platform_errors.h
                              include/platform_global.h
                              include/platform.h
                              include/platform_info.h
                              include/platform_types.h
                              common/include/gen_fixed_size_pool.h
                              common/include/platform_addr_map.h
                              common/include/platform_ctx.h
                              common/include/platform_devfiles.h
                              common/include/platform_logging.h
                              common/include/platform_perfc.h
                              common/include/platform_signaling.h
                              )

target_include_directories(platform PUBLIC $<INSTALL_INTERFACE:include/tapasco/platform>
                                           ${EXTRA_INCLUDES_PUBLIC}
                                           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
                                           PRIVATE ${EXTRA_INCLUDES_PRIVATE}
                                           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/common/include>
                                           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/common/nanopb>
                                      )

find_package (Threads)

target_link_libraries(platform PUBLIC tlkm PRIVATE ${CMAKE_THREAD_LIBS_INIT} tapasco-common)

install(TARGETS platform EXPORT TapascoPlatformConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/platform)

install(EXPORT TapascoPlatformConfig DESTINATION share/Tapasco/cmake)

export(TARGETS platform FILE TapascoPlatformConfig.cmake)
