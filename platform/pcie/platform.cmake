set(BUDDYDIR "${PLATFORM}/src/buddy_allocator")

add_definitions(-DPLATFORM_API_TAPASCO_STATUS_BASE=0x800000)

LIST(APPEND SRCS  "${PLATFORM}/src/platform_pcie.cpp"
                  "${BUDDYDIR}/buddy_allocator.cpp"
	              "${BUDDYDIR}/buddy_tree.cpp"
	              "${BUDDYDIR}/logger.cpp")

SET(EXTRA_INCLUDES_PUBLIC "")
SET(EXTRA_INCLUDES_PRIVATE "${PLATFORM}/module/include" "${BUDDYDIR}")