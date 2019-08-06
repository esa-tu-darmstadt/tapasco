//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
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
//! @file	tapasco_memory.h
//! @brief	Common TaPaSCo API implementation fragment:
//!		Provides standard API to allocate and free memory.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_MEMORY_H__
#define TAPASCO_MEMORY_H__

#include <tapasco_types.h>

/**
 * Allocates a chunk of len bytes on the device.
 * @param dev_ctx device context
 * @param h output parameter to write the handle to
 * @param len size in bytes
 * @param flags device memory allocation flags
 * @return TAPASCO_SUCCESS if successful, error code otherwise
 **/
tapasco_res_t tapasco_device_alloc(tapasco_devctx_t *dev_ctx,
                                   tapasco_handle_t *handle, size_t const len,
                                   tapasco_device_alloc_flag_t const flags,
                                   ...);

/**
 * Frees a previously allocated chunk of device memory.
 * @param dev_ctx device context
 * @param handle memory chunk handle returned by @see tapasco_alloc
 * @param flags device memory allocation flags
 **/
void tapasco_device_free(tapasco_devctx_t *dev_ctx, tapasco_handle_t handle, size_t len,
                         tapasco_device_alloc_flag_t const flags, ...);

/**
 * Copys memory from main memory to the FPGA device.
 * @param dev_ctx device context
 * @param src source address
 * @param dst destination device handle (prev. alloc'ed with tapasco_alloc)
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_copy_to(tapasco_devctx_t *dev_ctx, void const *src,
                                     tapasco_handle_t dst, size_t len,
                                     tapasco_device_copy_flag_t const flags,
                                     ...);

/**
 * Copys memory from FPGA device memory to main memory.
 * @param dev_ctx device context
 * @param src source device handle (prev. alloc'ed with tapasco_alloc)
 * @param dst destination address
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_copy_from(tapasco_devctx_t *dev_ctx,
                                       tapasco_handle_t src, void *dst,
                                       size_t len,
                                       tapasco_device_copy_flag_t const flags,
                                       ...);

/**
 * Copys data from main memory to PE-local memory in the given slot.
 * @param dev_ctx device context
 * @param src source data pointer
 * @param dst destination device handle
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @param slot_id PE-local memory slot
 * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
 **/
tapasco_res_t
tapasco_device_copy_to_local(tapasco_devctx_t *dev_ctx, void const *src,
                             tapasco_handle_t dst, size_t len,
                             tapasco_device_copy_flag_t const flags,
                             tapasco_slot_id_t slot_id);

/**
 * Copys data from PE-local memory in the given slot to main memory.
 * @param dev_ctx device context
 * @param src source device handle
 * @param dst destination data pointer
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @param slot_id PE-local memory slot
 * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_copy_from_local(
    tapasco_devctx_t *dev_ctx, tapasco_handle_t src, void *dst, size_t len,
    tapasco_device_copy_flag_t const flags, tapasco_slot_id_t slot_id);

#endif /* TAPASCO_MEMORY_H__ */
