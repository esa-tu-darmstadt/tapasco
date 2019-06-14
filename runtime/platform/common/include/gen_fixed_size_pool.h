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
/*
This file is part of gen_fixed_size_pool.

(C) Copyright 2015 Jens Korinth

gen_fixed_size_pool is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

gen_fixed_size_pool is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with gen_fixed_size_pool.  If not, see <http://www.gnu.org/licenses/>.
*/

//! @file	gen_fixed_size_pool.h
//! @brief	Generic, header-only, lock-free implementation of a fixed size
//!		pool of things based on statically allocated array.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __GEN_FIXED_SIZE_POOL_H__
#define __GEN_FIXED_SIZE_POOL_H__

#ifdef USE_ASSERTIONS
#ifndef __cplusplus
#include <assert.h>
#else
#include <cassert>
#endif
#else /* !USE_ASSERTIONS */
#define assert(...)
#endif

/** Index type: external id of pool element. */
typedef uint32_t fsp_idx_t;
#define INVALID_IDX					((fsp_idx_t)(-1))

// define a pool: PRE = prefix, SZ = size, T = type, IF = initializer function
#define MAKE_FIXED_SIZE_POOL(PRE, SZ, T, IF) \
struct PRE##_fsp_t { \
	T elems[SZ]; \
	int locked[SZ]; \
	int refcnt[SZ]; \
	fsp_idx_t curr; \
}; \
\
static inline void PRE##_fsp_init(struct PRE##_fsp_t *fsp) \
{ \
	int i; \
	for (i = 0; i < SZ; ++i) { \
		fsp->locked[i] = 0; \
		__atomic_clear(&fsp->locked[i], __ATOMIC_SEQ_CST); \
		fsp->refcnt[i] = 0; \
		IF(&fsp->elems[i], i); \
	} \
	fsp->curr = 0; \
} \
\
static inline fsp_idx_t PRE##_fsp_get(struct PRE##_fsp_t *fsp) \
{ \
	fsp_idx_t ret; \
	do { ret = __atomic_fetch_add(&fsp->curr, 1, __ATOMIC_SEQ_CST); } \
	while (ret < SZ && __atomic_test_and_set(&fsp->locked[ret], __ATOMIC_SEQ_CST)); \
	if (ret < SZ) { \
		assert(__atomic_add_fetch(&fsp->refcnt[ret], 1, __ATOMIC_SEQ_CST) < 2); \
		return ret; \
	} \
	return INVALID_IDX; \
} \
\
static inline void PRE##_fsp_put(struct PRE##_fsp_t *fsp, fsp_idx_t const idx) \
{ \
	if (idx < SZ) { \
		fsp_idx_t old; \
		__atomic_sub_fetch(&fsp->refcnt[idx], 1, __ATOMIC_SEQ_CST); \
		__atomic_clear(&fsp->locked[idx], __ATOMIC_SEQ_CST); \
		do { old = fsp->curr; } \
		while (! __atomic_compare_exchange_n(&fsp->curr, &old, \
					idx < old ? idx : old, 0, \
					__ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)); \
	} \
} \

#endif /* __GEN_FIXED_SIZE_POOL_H__ */
