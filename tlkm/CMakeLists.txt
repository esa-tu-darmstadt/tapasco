cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project(tlkm VERSION 1.0 LANGUAGES C)

add_library(tlkm INTERFACE)

target_include_directories(tlkm INTERFACE $<INSTALL_INTERFACE:include/tapasco/tlkm>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/user>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/>)

install(TARGETS tlkm
        EXPORT TapascoTLKMConfig
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        )
install(FILES user/tlkm_access.h
              user/tlkm_device_ioctl_cmds.h
              user/tlkm_ioctl_cmds.h
              user/tlkm_platform.h
              user/tlkm_types.h
              DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tapasco/tlkm
        )

install(EXPORT TapascoTLKMConfig DESTINATION share/Tapasco/cmake)

export(TARGETS tlkm FILE TapascoTLKMConfig.cmake)
