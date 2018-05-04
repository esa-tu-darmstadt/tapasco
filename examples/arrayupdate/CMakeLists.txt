project(arrayupdate)

add_executable(arrayupdate arrayupdate-example.c ../../kernel/arrayupdate/arrayupdate.c)

target_include_directories(arrayupdate PRIVATE ../../kernel/arrayupdate)
target_link_libraries(arrayupdate rt pthread tapasco platform atomic)

install(TARGETS arrayupdate
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
