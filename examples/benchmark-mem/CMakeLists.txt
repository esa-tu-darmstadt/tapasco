project (benchmark-mem)

add_executable (benchmark-mem benchmark-mem.c)
target_link_libraries (benchmark-mem m rt pthread tapasco platform)

add_executable (benchmark-mem++ benchmark-mem.cpp)
target_link_libraries (benchmark-mem++ m rt pthread tapasco platform)

install (TARGETS benchmark-mem benchmark-mem++
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)

