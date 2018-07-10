set(PLATFORM "${CMAKE_CURRENT_LIST_DIR}")

target_sources(platform PRIVATE "${PLATFORM}/src/platform_pcie.c")
LIST(APPEND EXTRA_INCLUDES_PRIVATE "${PLATFORM}/include")
