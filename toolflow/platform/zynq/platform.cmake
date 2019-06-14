SET(PLATFORM "${CMAKE_CURRENT_LIST_DIR}")

target_sources(platform PRIVATE "${PLATFORM}/src/platform_zynq.c")
LIST(APPEND EXTRA_INCLUDES_PRIVATE "${PLATFORM}/include/")
