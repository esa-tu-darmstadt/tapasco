//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TAPASCO).
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
 *  @file	tapasco_memory.c
 *  @brief	Default implementation of memory functions: Pass-through to
 *  		Platform implementation.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifdef __cplusplus
	#include <cstdint>
	#include <cstring>
#else
	#include <stdint.h>
	#include <string.h>
#endif
#include <platform.h>
#include <tapasco_memory.h>
#include <tapasco_logging.h>
#include <tapasco_errors.h>

tapasco_res_t tapasco_device_alloc(tapasco_dev_ctx_t *dev_ctx, tapasco_handle_t *h,
		size_t const len, tapasco_device_alloc_flag_t const flags)
{
	platform_mem_addr_t addr;
	platform_res_t r;
	if ((r = platform_alloc(len, &addr, PLATFORM_ALLOC_FLAGS_NONE)) == PLATFORM_SUCCESS) {
		LOG(LALL_MEM, "allocated %zd bytes at 0x%08x", len, addr);
		*h = addr;
		return TAPASCO_SUCCESS;
	}
	WRN("could not allocate %zd bytes of device memory: %s",
			len, platform_strerror(r));
	return TAPASCO_ERR_OUT_OF_MEMORY;
}

void tapasco_device_free(tapasco_dev_ctx_t *dev_ctx, tapasco_handle_t handle,
		tapasco_device_alloc_flag_t const flags)
{
	LOG(LALL_MEM, "freeing handle 0x%08x", (unsigned)handle);
	platform_dealloc(handle, PLATFORM_ALLOC_FLAGS_NONE);
}

tapasco_res_t tapasco_device_copy_to(tapasco_dev_ctx_t *dev_ctx, void const *src,
		tapasco_handle_t dst, size_t len,
		tapasco_device_copy_flag_t const flags)
{
	LOG(LALL_MEM, "dst = 0x%08x, len = %zd, flags = %d", (unsigned)dst, len, flags);
	if (flags & TAPASCO_DEVICE_COPY_NONBLOCKING)
		return TAPASCO_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags)
		return TAPASCO_ERR_NOT_IMPLEMENTED;
	return platform_write_mem(dst, len, src, PLATFORM_MEM_FLAGS_NONE) == PLATFORM_SUCCESS ?
			TAPASCO_SUCCESS : TAPASCO_FAILURE;
}

tapasco_res_t tapasco_device_copy_from(tapasco_dev_ctx_t *dev_ctx, tapasco_handle_t src,
		void *dst, size_t len,
		tapasco_device_copy_flag_t const flags)
{
	LOG(LALL_MEM, "src = 0x%08x, len = %zd, flags = %d", (unsigned)src, len, flags);
	if (flags & TAPASCO_DEVICE_COPY_NONBLOCKING)
		return TAPASCO_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags)
		return TAPASCO_ERR_NOT_IMPLEMENTED;
	return platform_read_mem(src, len, dst, PLATFORM_MEM_FLAGS_NONE) == PLATFORM_SUCCESS ?
			TAPASCO_SUCCESS : TAPASCO_FAILURE;
}
