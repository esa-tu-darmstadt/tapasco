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
/**
 *  @file	tapasco_local_mem.c
 *  @brief	Helper methods to manage PE-local memories.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <tapasco_local_mem.h>
#include <tapasco_global.h>
#include <tapasco_errors.h>
#include <tapasco_logging.h>
#include <tapasco_device.h>
#include <gen_mem.h>
#include <platform.h>
#include <platform_info.h>
#include <stdlib.h>

typedef struct {
	addr_t base;
	addr_t high;
} address_space_t;

struct tapasco_local_mem {
	address_space_t as[PLATFORM_NUM_SLOTS];
	block_t *lmem[PLATFORM_NUM_SLOTS];
};

static inline
size_t get_slot_mem(tapasco_devctx_t *devctx, tapasco_slot_id_t const slot_id)
{
	if (devctx->info.magic_id != TAPASCO_MAGIC_ID) {
		platform_res_t r = platform_info(devctx->pdctx, &devctx->info);
		if (r != PLATFORM_SUCCESS) {
			ERR("failed to get device info: %s (%d)", platform_strerror(r), r);
			return TAPASCO_ERR_PLATFORM_FAILURE;
		}
	}
	return devctx->info.composition.memory[slot_id];
}

tapasco_res_t tapasco_local_mem_init(tapasco_devctx_t *devctx,
		tapasco_local_mem_t **lmem)
{
	LOG(LALL_MEM, "initialzing ...");
	*lmem = (tapasco_local_mem_t *)calloc(sizeof(tapasco_local_mem_t), 1);
	if (! *lmem) return TAPASCO_ERR_OUT_OF_MEMORY;
	addr_t base = 0;
	for (size_t idx = 0; idx < PLATFORM_NUM_SLOTS; ++idx) {
		size_t const sz = get_slot_mem(devctx, idx);
		LOG(LALL_MEM, "memory size for slot_id #%zd: %zd bytes", idx, sz);
		(*lmem)->lmem[idx] = sz > 0 ? gen_mem_create(base, sz) : NULL;
		(*lmem)->as[idx].base = base;
		(*lmem)->as[idx].high = base + sz;
		if (sz && !(*lmem)->lmem[idx]) return TAPASCO_ERR_OUT_OF_MEMORY;
		if (sz) base += sz; else base = 0;
	}
	return TAPASCO_SUCCESS;
}

void tapasco_local_mem_deinit(tapasco_local_mem_t *lmem)
{
	free(lmem);
	LOG(LALL_MEM, "destroyed");
}

tapasco_res_t tapasco_local_mem_alloc(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t slot_id, size_t const sz,
		tapasco_handle_t *h)
{
	*h = INVALID_ADDRESS;
	++slot_id;
	while (*h == INVALID_ADDRESS && lmem->lmem[slot_id]) {
		*h = gen_mem_malloc(&lmem->lmem[slot_id], sz);
		++slot_id;
	}
	LOG(LALL_MEM, "request to allocate %zd bytes for slot_id #%d -> 0x%08lx",
			sz, slot_id, (unsigned long)*h);
	return *h != INVALID_ADDRESS ? TAPASCO_SUCCESS : TAPASCO_ERR_OUT_OF_MEMORY;
}

void tapasco_local_mem_dealloc(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t slot_id, tapasco_handle_t h, size_t sz)
{
	LOG(LALL_MEM, "request to free %zd bytes at slot_id #%d:0x%08lx",
			sz, slot_id, (unsigned long)h);
	++slot_id;
	while (lmem->lmem[slot_id] && h > lmem->as[slot_id].high) slot_id++;
	if (lmem->lmem[slot_id]) gen_mem_free(&lmem->lmem[slot_id], h, sz);
}

inline
size_t tapasco_local_mem_get_size(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t const slot_id)
{
	return lmem->as[slot_id].high - lmem->as[slot_id].base;
}

inline
size_t tapasco_local_mem_get_free(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t const slot_id)
{
	return lmem->as[slot_id].high - gen_mem_next_base(lmem->lmem[slot_id]);
}

inline
tapasco_handle_t tapasco_local_mem_get_slot_and_base(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t *slot_id,
		addr_t const elem)
{
	while (elem > lmem->as[*slot_id].high) {
		LOG(LALL_MEM, "local mem high address of slot_id #%zd (0x%08lx)"
				" < elem address (0x%08lx)",
				*slot_id, (unsigned long)*slot_id,
				(unsigned long)elem);
		++(*slot_id);
	}
	return lmem->as[*slot_id].base;
}
