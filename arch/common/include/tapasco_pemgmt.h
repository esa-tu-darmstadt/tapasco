//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
//! @file	tapasco_pemgmt.h
//! @brief	Defines a micro API to access the pes available in a 
//!             hardware threadpool, perform enumeration, locking etc.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_PEMGMT_H__
#define TAPASCO_PEMGMT_H__

#include <tapasco_types.h>
#include <tapasco_global.h>
#include <tapasco_status.h>

/** Implementation defined functions struct. (opaque) */
typedef struct tapasco_pemgmt tapasco_pemgmt_t;

/**
 * Initializes a function struct by populating with current data from device.
 * @param status pointer to internal status core struct.
 * @param pes pointer to internal functions struct pointer.
 * @return TAPASCO_SUCCESS if successful.
 **/
tapasco_res_t tapasco_pemgmt_init(const tapasco_status_t *status,
		tapasco_pemgmt_t **pes);

/**
 * Releases the given function struct an allocated memory.
 * @param pes pointer to internal functions struct.
 **/
void tapasco_pemgmt_deinit(tapasco_pemgmt_t *pes);

/**
 * Supporting function: Perform initial setup of the system, e.g., activate 
 * interrupts at each kernel instance, etc.
 * @param dev_ctx device context.
 * @param ctx functions context.
 **/
void tapasco_pemgmt_setup_system(tapasco_dev_ctx_t *dev_ctx,
		tapasco_pemgmt_t *ctx);

/**
 * Reserves a slot containing an instance of the given function (if possible).
 * @param ctx functions context.
 * @param k_id function identifier.
 * @return slot_id >= 0 if successful, < 0 otherwise.
 **/
tapasco_slot_id_t tapasco_pemgmt_acquire(tapasco_pemgmt_t *ctx,
		tapasco_kernel_id_t const k_id);

/**
 * Releases a previously acquired slot.
 * @param ctx functions context.
 * @param s_id slot identifier.
 */
void tapasco_pemgmt_release(tapasco_pemgmt_t *ctx,
		tapasco_slot_id_t const s_id);

/**
 * Returns the number of available instances of the kernel with the given
 * function identifier.
 * @param ctx functions context.
 * @param k_id function identifier.
 * @param Number of processing elements currently configured (0 if none).
 **/
size_t tapasco_pemgmt_count(tapasco_pemgmt_t const *ctx,
		tapasco_kernel_id_t const k_id);

#endif /* TAPASCO_PEMGMT_H__ */
