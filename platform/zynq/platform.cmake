add_definitions(-DPLATFORM_API_TAPASCO_STATUS_BASE=0x77770000)

LIST(APPEND SRCS "${PLATFORM}/src/platform_zynq.c")

include_directories("." "include" "${CMNDIR}/include" "${GCMNDIR}/include")

SET(EXTRA_INCLUDES_PUBLIC "")
SET(EXTRA_INCLUDES_PRIVATE "${PLATFORM}/")
