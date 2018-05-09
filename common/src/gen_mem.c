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
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include "gen_mem.h"

#ifdef GEN_MEM_DEBUG
#define GEN_MEM_LOG(...)	printf(__VA_ARGS__)
#else
#define GEN_MEM_LOG(...)
#endif

block_t *gen_mem_create(addr_t const base, size_t const range)
{
	assert(base % sizeof(addr_t) == 0 || "base address in gen_mem_create must be aligned with word size");
	assert(range % sizeof(addr_t) == 0 || "range in gen_mem_create must be aligned with word size");
	block_t *b = (block_t *)malloc(sizeof(*b));
	assert(b || "gen_mem_create ran out of memory!");
	if (! b) return b;
	b->base  = base;
	b->range = range;
	b->next  = NULL;
	return b;
}

addr_t gen_mem_next_base(block_t *root)
{
	assert(root || "argument to gen_mem_next_base may not be NULL");
	block_t *nxt = root;
	while (nxt != NULL && nxt->range == 0) {
		nxt = nxt->next;
	}
	if (! nxt) return INVALID_ADDRESS;
	return nxt->base;
}

addr_t gen_mem_malloc(block_t **root, size_t const length)
{
	assert(root || "argument to gen_mem_malloc may not be NULL");
	assert(length > 0 || "length must be > 0");
	block_t *prv = *root, *nxt = *root;
	while (nxt != NULL && nxt->range < length) {
		prv = nxt;
		nxt = nxt->next;
	}
	if (! nxt) return INVALID_ADDRESS;
	addr_t const base = nxt->base;
	nxt->base  += length;
	nxt->range -= length;
	GEN_MEM_LOG("alloc'ed 0x%08lx - 0x%08lx\n", (unsigned long)base,
			base + length);
	if (nxt->range == 0 && nxt != *root) {
		prv->next = nxt->next;
		free(nxt);
	}
	return base;
}

void gen_mem_free(block_t **root, addr_t const p, size_t const l)
{
	assert(root || "argument to gen_mem_free may not be NULL");
	GEN_MEM_LOG("freeing 0x%08lx - 0x%08lx\n", (unsigned long)p, p + l);
	block_t *prv = *root, *nxt = *root;
	while (nxt != NULL && nxt->base + nxt->range <= p) {
		prv = nxt;
		nxt = nxt->next;
	}
	GEN_MEM_LOG("prv: 0x%08lx - 0x%08lx\n", (unsigned long)prv->base, prv->base + prv->range);
	GEN_MEM_LOG("nxt: 0x%08lx - 0x%08lx\n", (unsigned long)nxt->base, nxt->base + nxt->range);
	size_t const length = nxt->range;
	if (prv->base + prv->range == p) {
		prv->range += length;
		if (prv->next && prv->base + prv->range == prv->next->base) {
			block_t *del = prv->next;
			prv->range += del->range;
			prv->next   = del->next;
			free(del);
		}
		GEN_MEM_LOG("merging prv\n");
		return;
	}
	if (nxt != NULL && p + length == nxt->base) {
		nxt->base  -= length;
		nxt->range += length;
		GEN_MEM_LOG("merging nxt\n");
		return;
	}
	GEN_MEM_LOG("inserting new\n");
	block_t *nb = (block_t*)malloc(sizeof(*nb));
	assert(nb || "gen_mem_create ran out of memory!");
	nb->base  = p;
	nb->range = length;
	if (p + length < prv->base) {
		GEN_MEM_LOG("inserting before\n");
		nb->next = prv;
		*root = *root == prv ? nb : *root;
	} else {
		GEN_MEM_LOG("inserting after\n");
		nb->next = prv->next;
		prv->next = nb;
	}
}
