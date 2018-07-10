project (tapasco-debug)

add_executable (tapasco-debug tapasco_debug.cpp)
target_link_libraries (tapasco-debug PRIVATE tapasco pthread atomic ncurses)

add_executable (tapasco-benchmark tapasco_benchmark.cpp ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.cpp)
target_include_directories(tapasco-benchmark PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/json11)
target_link_libraries (tapasco-benchmark PRIVATE tapasco pthread atomic ncurses)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.cpp ${CMAKE_CURRENT_BINARY_DIR}/json11/json11.hpp
  COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/json11
  COMMAND git clone https://github.com/dropbox/json11.git ${CMAKE_CURRENT_BINARY_DIR}/json11
  )

install (TARGETS tapasco-debug tapasco-benchmark
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})
