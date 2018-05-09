//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
//! @file	gen_mem.h
//! @brief	Generic, header-only memory management library. Can manage
//!             address spaces with arbitrary size and base. Extremely light-
//!             weight and simplistic, should not be used for applications with
//!             frequent and short-lived allocations.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef GEN_MEM_H__
#define GEN_MEM_H__

#include <stdint.h>
#include <unistd.h>

typedef uint32_t addr_t;

#define INVALID_ADDRESS 			((addr_t)(-1))

typedef struct block {
	addr_t base;
	size_t range;
	struct block *next;
} block_t;

extern
block_t *gen_mem_create(addr_t const base, size_t const range);

extern
addr_t gen_mem_malloc(block_t **root, size_t const length);

extern
addr_t gen_mem_next_base(block_t *root);

extern
void gen_mem_free(block_t **root, addr_t const p, size_t const length);

#endif /* GEN_MEM_H__ */
