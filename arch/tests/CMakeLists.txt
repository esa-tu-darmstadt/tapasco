project (tapasco-debug)

set (CMAKE_INSTALL_PREFIX "${TAPASCO_HOME}")

add_executable (tapasco-debug tapasco_debug.cpp ${CMNDIR}/src/gen_queue.c)
target_include_directories(tapasco-debug PRIVATE ${CMNDIR}/include)
target_link_libraries (tapasco-debug tapasco platform pthread atomic ncurses -static-libstdc++ -static-libgcc)

add_executable (tapasco-benchmark tapasco_benchmark.cpp json11.cpp  ${CMNDIR}/src/gen_queue.c)
target_include_directories(tapasco-benchmark PRIVATE ${CMNDIR}/include)
target_link_libraries (tapasco-benchmark tapasco platform pthread atomic ncurses -static-libstdc++ -static-libgcc)

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/json11.cpp ${CMAKE_CURRENT_SOURCE_DIR}/json11.hpp
  COMMAND rm -rf json11
  COMMAND git clone https://github.com/dropbox/json11.git
  COMMAND cp json11/json11.* ${CMAKE_CURRENT_SOURCE_DIR}
  )

install (TARGETS tapasco-debug tapasco-benchmark
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})
