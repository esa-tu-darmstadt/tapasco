//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
#ifndef __MACHSUITE_HARNESS_H__
#define __MACHSUITE_HARNESS_H__

#ifdef MACHSUITE_BFS_QUEUE
	#include "bfs/queue/queue.h"
	#define main generate_main
	#include "bfs/queue/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_FFT_STRIDED
	#include "fft/strided/fft.h"
	#define main generate_main
	#include "fft/strided/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_FFT_TRANSPOSE
	#include "fft/transpose/fft.h"
	#define main generate_main
	#include "fft/transpose/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_GEMM_BLOCKED
	#include "gemm/blocked/bbgemm.h"
	#define main generate_main
	#include "gemm/blocked/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_GEMM_NCUBED
	#include "gemm/ncubed/gemm.h"
	#define main generate_main
	#include "gemm/ncubed/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_KMP_KMP
	#include "kmp/kmp/kmp.h"
	#define main generate_main
	#include "kmp/kmp/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_MD_GRID
	#include "md/grid/md.h"
	#define main generate_main
	#include "md/grid/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_MD_KNN
	#include "md/knn/md.h"
	#define main generate_main
	#include "md/knn/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_SORT_MERGE
	#include "sort/merge/merge.h"
	#define main generate_main
	#include "sort/merge/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_SORT_RADIX
	#include "sort/radix/radix.h"
	#define main generate_main
	#include "sort/radix/generate.c"
	#undef main
	#include "sort/radix/radix.c"
#endif

#ifdef MACHSUITE_SPMV_CRS
	#include "spmv/crs/crs.h"
	#define main generate_main
	#include "spmv/crs/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_SPMV_ELLPACK
	#include "spmv/ellpack/ellpack.h"
	#define main generate_main
	#include "spmv/ellpack/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_STENCIL_STENCIL2D
	#include "stencil/stencil2d/stencil.h"
	#define main generate_main
	#include "stencil/stencil2d/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_STENCIL_STENCIL3D
	#include "stencil/stencil3d/stencil3d.h"
	#define main generate_main
	#include "stencil/stencil3d/generate.c"
	#undef main
#endif

#ifdef MACHSUITE_VITERBI_VITERBI
	#include "viterbi/viterbi/viterbi.h"
	#define main generate_main
	#include "viterbi/viterbi/generate.c"
	#undef main
#endif

#endif /* __MACHSUITE_HARNESS_H__ */
