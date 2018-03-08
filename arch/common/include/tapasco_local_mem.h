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
#include <tapasco_pemgmt.h>
#include <platform_types.h>

/** Forward declaration of local memory management struct (opaque). */
typedef struct tapasco_local_mem tapasco_local_mem_t;

/**
 * Initialize a local memory management struct using status core information.
 * @param status pointer to status management struct
 * @param lmem output pointer to initialize
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_local_mem_init(tapasco_dev_ctx_t const *dev_ctx,
		tapasco_local_mem_t **lmem);
void tapasco_local_mem_deinit(tapasco_local_mem_t *lmem);

/**
 * Allocates local memory for PE in given slot and return the address of the
 * memory in the PE-local address space.
 * @param lmem local memory management struct
 * @param slot_id slot with PE to allocate local mem for
 * @param sz number of bytes to allocate (must be power of 2)
 * @param h output handle
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_local_mem_alloc(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t slot_id,
		size_t const sz,
		tapasco_handle_t *h);

/**
 * Deallocates local memory previously allocated with @tapasco_local_mem_alloc
 * for PE in given slot.
 * @param lmem local memory management struct
 * @param slot_id slot with PE to allocate local mem for
 * @param sz number of bytes to deallocate (must match allocation call)
 * @param h handle containing PE-local mem address
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
void tapasco_local_mem_dealloc(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t slot_id,
		tapasco_handle_t h,
		size_t sz);

/**
 * Returns the number of bytes of memory in given slot id.
 * @param lmem local memory management struct
 * @param slot_id slot to check for local memory
 * @return number of bytes > 0 if memory controller is in slot, 0 otherwise
 **/
size_t tapasco_local_mem_get_size(tapasco_local_mem_t *lmem,
		tapasco_slot_id_t slot_id);

/**
 * Returns the base address in PE-local memory space for memory at given slot.
 * @param lmem local memory management struct
 * @param slot_id output slot id with the corresponding memory controller
 * @param elem address in PE-local memory space to find the slot and base for.
 * @return return base address of memory controller managing elem
 **/
platform_ctl_addr_t tapasco_local_mem_get_slot_and_base(
		tapasco_local_mem_t *lmem,
		tapasco_slot_id_t *slot_id,
		platform_ctl_addr_t const elem);

#endif /* TAPASCO_LOCAL_MEM_H__ */
