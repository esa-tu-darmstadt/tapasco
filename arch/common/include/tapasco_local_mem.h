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
//! @file	tapasco_local_mem.h
//! @brief	Helper methods to manage PE-local memories.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! 
#ifndef TAPASCO_LOCAL_MEM_H__
#define TAPASCO_LOCAL_MEM_H__

#include <tapasco.h>
#include <tapasco_functions.h>
#include <tapasco_status.h>
#include <gen_mem.h>

typedef struct tapasco_local_mem tapasco_local_mem_t;

tapasco_res_t tapasco_local_mem_init(tapasco_status_t const *status,
		tapasco_local_mem_t **lmem);
void tapasco_local_mem_deinit(tapasco_local_mem_t *lmem);

tapasco_res_t tapasco_local_mem_alloc(tapasco_local_mem_t *lmem,
		tapasco_func_slot_id_t slot_id, size_t const sz,
		tapasco_handle_t *h);

void tapasco_local_mem_dealloc(tapasco_local_mem_t *lmem,
		tapasco_func_slot_id_t slot_id, tapasco_handle_t h, size_t sz);

size_t tapasco_local_mem_get_size(tapasco_local_mem_t *lmem,
		tapasco_func_slot_id_t slot_id);

addr_t tapasco_local_mem_get_base(tapasco_local_mem_t *lmem,
		tapasco_func_slot_id_t *slot_id,
		addr_t const elem);

#endif /* TAPASCO_LOCAL_MEM_H__ */
