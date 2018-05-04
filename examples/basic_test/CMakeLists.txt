project(basic_test)

add_executable(basic_test basic_test.cpp)
target_link_libraries(basic_test rt pthread tapasco platform atomic)

install(TARGETS basic_test
        ARCHIVE  DESTINATION bin/
        LIBRARY  DESTINATION bin/
        RUNTIME  DESTINATION bin/)
