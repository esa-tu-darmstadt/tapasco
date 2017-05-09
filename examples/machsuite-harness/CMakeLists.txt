cmake_minimum_required (VERSION 2.7)
set (CMAKE_INSTALL_PREFIX "..")
include (../examples.cmake)

if ("$ENV{MACHSUITE_HOME}" STREQUAL "")
  message(FATAL_ERROR "Please set env var MACHSUITE_HOME to root directory of MachSuite.")
endif ("$ENV{MACHSUITE_HOME}" STREQUAL "")

set(MACHSUITE_HOME "$ENV{MACHSUITE_HOME}")
include_directories(${MACHSUITE_HOME})

set(ARCH "${CMAKE_SYSTEM_PROCESSOR}")

set(ALL_TARGETS bfsqueue fftstrided ffttranspose gemmblocked gemmncubed kmp mdgrid mdknn sortmerge sortradix spmvcrs spmvellpack stencil2d stencil3d viterbi)

# MachSuite benchmark: bfs/queue
add_executable(bfsqueue machsuite-harness.c)
set_target_properties(bfsqueue PROPERTIES
                               COMPILE_DEFINITIONS "MACHSUITE_BFS_QUEUE"
                               COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-variable"
		     )
target_link_libraries(bfsqueue rt pthread tapasco platform)

# MachSuite benchmark: fft/strided
add_executable(fftstrided machsuite-harness.c)
set_target_properties(fftstrided PROPERTIES
                                 COMPILE_DEFINITIONS "MACHSUITE_FFT_STRIDED"
                                 COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(fftstrided rt pthread tapasco platform m)

# MachSuite benchmark: fft/transpose
add_executable(ffttranspose machsuite-harness.c)
set_target_properties(ffttranspose PROPERTIES
                                   COMPILE_DEFINITIONS "MACHSUITE_FFT_TRANSPOSE"
                                   COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(ffttranspose rt pthread tapasco platform m)

# MachSuite benchmark: gemm/blocked
add_executable(gemmblocked machsuite-harness.c)
set_target_properties(gemmblocked PROPERTIES
                                  COMPILE_DEFINITIONS "MACHSUITE_GEMM_BLOCKED"
                                  COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(gemmblocked rt pthread tapasco platform)

# MachSuite benchmark: gemm/ncubed
add_executable(gemmncubed machsuite-harness.c)
set_target_properties(gemmncubed PROPERTIES
                                 COMPILE_DEFINITIONS "MACHSUITE_GEMM_NCUBED"
                                 COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(gemmncubed rt pthread tapasco platform)

# MachSuite benchmark: kmp/kmp
add_executable(kmp machsuite-harness.c)
set_target_properties(kmp PROPERTIES
                          COMPILE_DEFINITIONS "MACHSUITE_KMP_KMP"
                          COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-return-type"
		     )
target_link_libraries(kmp rt pthread tapasco platform)

# MachSuite benchmark: md/grid
add_executable(mdgrid machsuite-harness.c)
set_target_properties(mdgrid PROPERTIES
                             COMPILE_DEFINITIONS "MACHSUITE_MD_GRID"
                             COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-variable"
		     )
target_link_libraries(mdgrid rt pthread tapasco platform)

# MachSuite benchmark: md/knn
add_executable(mdknn machsuite-harness.c)
set_target_properties(mdknn PROPERTIES
                            COMPILE_DEFINITIONS "MACHSUITE_MD_KNN"
                            COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(mdknn rt pthread tapasco platform)

# MachSuite benchmark: sort/merge
add_executable(sortmerge machsuite-harness.c)
set_target_properties(sortmerge PROPERTIES
                                COMPILE_DEFINITIONS "MACHSUITE_SORT_MERGE"
                                COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(sortmerge rt pthread tapasco platform)

# MachSuite benchmark: sort/radix
add_executable(sortradix machsuite-harness.c)
set_target_properties(sortradix PROPERTIES
                                COMPILE_DEFINITIONS "MACHSUITE_SORT_RADIX"
                                COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-unused-label -Wno-unused-but-set-variable"
		     )
target_link_libraries(sortradix rt pthread tapasco platform)

# MachSuite benchmark: spmv/crs
add_executable(spmvcrs machsuite-harness.c)
set_target_properties(spmvcrs PROPERTIES
                              COMPILE_DEFINITIONS "MACHSUITE_SPMV_CRS"
                              COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(spmvcrs rt pthread tapasco platform)

# MachSuite benchmark: spmv/ellpack
add_executable(spmvellpack machsuite-harness.c)
set_target_properties(spmvellpack PROPERTIES
                                  COMPILE_DEFINITIONS "MACHSUITE_SPMV_ELLPACK"
                                  COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(spmvellpack rt pthread tapasco platform)

# MachSuite benchmark: stencil/stencil2d
add_executable(stencil2d machsuite-harness.c)
set_target_properties(stencil2d PROPERTIES
                                COMPILE_DEFINITIONS "MACHSUITE_STENCIL_STENCIL2D"
                                COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(stencil2d rt pthread tapasco platform)

# MachSuite benchmark: stencil/stencil3d
add_executable(stencil3d machsuite-harness.c)
set_target_properties(stencil3d PROPERTIES
                                COMPILE_DEFINITIONS "MACHSUITE_STENCIL_STENCIL3D"
                                COMPILE_FLAGS "-g -Wall -Werror -std=gnu99"
		     )
target_link_libraries(stencil3d rt pthread tapasco platform) 

# MachSuite benchmark: viterbi/viterbi
add_executable(viterbi machsuite-harness.c)
set_target_properties(viterbi PROPERTIES
                              COMPILE_DEFINITIONS "MACHSUITE_VITERBI_VITERBI"
                              COMPILE_FLAGS "-g -Wall -Werror -std=gnu99 -Wno-return-type"
		     )
target_link_libraries(viterbi rt pthread tapasco platform) 

install(TARGETS ${ALL_TARGETS}
        RUNTIME DESTINATION bin/${ARCH})
