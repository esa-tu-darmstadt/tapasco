project(arrayinit)

include_directories(../../kernel/arrayinit)

add_executable(arrayinit arrayinit-example.c ../../kernel/arrayinit/arrayinit.c)
target_link_libraries(arrayinit rt pthread tapasco platform atomic)

install(TARGETS arrayinit
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
