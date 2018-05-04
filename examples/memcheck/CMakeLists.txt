project (memcheck)

add_executable(memcheck memcheck.c)
target_link_libraries(memcheck tapasco pthread platform)

add_executable(memcheck-mt memcheck-mt.c)
target_link_libraries(memcheck-mt pthread tapasco platform pthread)

install(TARGETS memcheck memcheck-mt
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

