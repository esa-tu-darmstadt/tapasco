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
	#include <cstdarg>
#else
	#include <stdint.h>
	#include <string.h>
	#include <stdarg.h>
#endif
#include <platform.h>
#include <tapasco_memory.h>
#include <tapasco_logging.h>
#include <tapasco_errors.h>
#include <tapasco_device.h>
#include <tapasco_status.h>
#include <tapasco_local_mem.h>
#include <platform.h>

static
tapasco_res_t tapasco_device_alloc_local(tapasco_dev_ctx_t *dev_ctx,
		tapasco_handle_t *h, size_t const len,
		tapasco_device_alloc_flag_t const flags,
		tapasco_func_slot_id_t slot_id)
{
	LOG(LALL_MEM, "allocating %zd bytes of pe-local memory for function #%lu",
			len, (unsigned long)slot_id);
	return tapasco_local_mem_alloc(tapasco_device_local_mem(dev_ctx),
			slot_id, len, h);
}

static
tapasco_res_t tapasco_device_free_local(tapasco_dev_ctx_t *dev_ctx,
		tapasco_handle_t h, size_t const len,
		tapasco_device_alloc_flag_t const flags,
		tapasco_func_slot_id_t slot_id)
{
	LOG(LALL_MEM, "freeing %zd bytes of pe-local memory for function #%lu",
			len, (unsigned long)slot_id);
	tapasco_local_mem_dealloc(tapasco_device_local_mem(dev_ctx), slot_id,
			len, h);
	return TAPASCO_SUCCESS;
}

static
tapasco_res_t tapasco_device_copy_to_local(tapasco_dev_ctx_t *dev_ctx,
		void const *src, tapasco_handle_t dst, size_t len,
		tapasco_device_copy_flag_t const flags,
		tapasco_func_slot_id_t slot_id)
{
	addr_t lbase = tapasco_local_mem_get_base(tapasco_device_local_mem(dev_ctx), &slot_id, dst);
	platform_ctl_addr_t a = platform_address_get_slot_base(slot_id, 0);
	LOG(LALL_MEM, "copying locally to 0x%08lx of slot_id #%lu, bus address: 0x%08lx",
			(unsigned long)dst, (unsigned long)slot_id, (unsigned long)a + (dst - lbase));
	a += (dst - lbase);
	uint32_t *lmem = (uint32_t *)src;
	tapasco_res_t res = TAPASCO_SUCCESS;
	for (size_t i = 0; res == TAPASCO_SUCCESS && i < len; i += sizeof(*lmem), a += sizeof(*lmem)) {
		res = platform_write_ctl(a, sizeof(*lmem), &lmem[i], flags);
	}
	return res;
}

static
tapasco_res_t tapasco_device_copy_from_local(tapasco_dev_ctx_t *dev_ctx,
		tapasco_handle_t src, void *dst, size_t len,
		tapasco_device_copy_flag_t const flags,
		tapasco_func_slot_id_t slot_id)
{
	addr_t lbase = tapasco_local_mem_get_base(tapasco_device_local_mem(dev_ctx), &slot_id, src);
	platform_ctl_addr_t a = platform_address_get_slot_base(slot_id, 0);
	LOG(LALL_MEM, "copying locally from 0x%08lx of slot_id #%lu, bus address: 0x%08lx",
			(unsigned long)src, (unsigned long)slot_id, (unsigned long)a + (src - lbase));
	a += (src - lbase);
	uint32_t *lmem = (uint32_t *)dst;
	tapasco_res_t res = TAPASCO_SUCCESS;
	for (size_t i = 0; res == TAPASCO_SUCCESS && i < len; i += sizeof(*lmem), a += sizeof(*lmem)) {
		res = platform_read_ctl(a, sizeof(*lmem), &lmem[i], flags);
	}
	return res;
}

tapasco_res_t tapasco_device_alloc(tapasco_dev_ctx_t *dev_ctx,
		tapasco_handle_t *h, size_t const len,
		tapasco_device_alloc_flag_t const flags,
		...)
{
	platform_mem_addr_t addr;
	platform_res_t r;
	if (flags & TAPASCO_DEVICE_ALLOC_FLAGS_PE_LOCAL) {
		va_list ap; va_start(ap, flags);
		tapasco_func_slot_id_t slot_id = va_arg(ap, tapasco_func_slot_id_t);
		va_end(ap);
		return tapasco_device_alloc_local(dev_ctx, h, len, flags, slot_id);
	}
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
		tapasco_device_alloc_flag_t const flags, ...)
{
	LOG(LALL_MEM, "freeing handle 0x%08x", (unsigned)handle);
	if (flags & TAPASCO_DEVICE_ALLOC_FLAGS_PE_LOCAL) {
		va_list ap; va_start(ap, flags);
		tapasco_func_slot_id_t slot_id = va_arg(ap, tapasco_func_slot_id_t);
		size_t len = va_arg(ap, size_t);
		va_end(ap);
		tapasco_device_free_local(dev_ctx, handle, len, flags, slot_id);
	}
	platform_dealloc(handle, PLATFORM_ALLOC_FLAGS_NONE);
}

tapasco_res_t tapasco_device_copy_to(tapasco_dev_ctx_t *dev_ctx, void const *src,
		tapasco_handle_t dst, size_t len,
		tapasco_device_copy_flag_t const flags, ...)
{
	LOG(LALL_MEM, "dst = 0x%08x, len = %zd, flags = %d", (unsigned)dst, len, flags);
	if (flags & TAPASCO_DEVICE_COPY_NONBLOCKING)
		return TAPASCO_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags & TAPASCO_DEVICE_COPY_PE_LOCAL) {
		va_list ap;
		va_start(ap, flags);
		tapasco_func_slot_id_t slot_id = va_arg(ap, tapasco_func_slot_id_t);
		va_end(ap);
		return tapasco_device_copy_to_local(dev_ctx, src, dst, len, flags, slot_id);
	}
	if (flags)
		return TAPASCO_ERR_NOT_IMPLEMENTED;
	return platform_write_mem(dst, len, src, PLATFORM_MEM_FLAGS_NONE) == PLATFORM_SUCCESS ?
			TAPASCO_SUCCESS : TAPASCO_FAILURE;
}

tapasco_res_t tapasco_device_copy_from(tapasco_dev_ctx_t *dev_ctx,
		tapasco_handle_t src, void *dst, size_t len,
		tapasco_device_copy_flag_t const flags,
		...)
{
	LOG(LALL_MEM, "src = 0x%08x, len = %zd, flags = %d", (unsigned)src, len, flags);
	if (flags & TAPASCO_DEVICE_COPY_NONBLOCKING)
		return TAPASCO_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags & TAPASCO_DEVICE_COPY_PE_LOCAL) {
		va_list ap;
		va_start(ap, flags);
		tapasco_func_slot_id_t slot_id = va_arg(ap, tapasco_func_slot_id_t);
		va_end(ap);
		return tapasco_device_copy_from_local(dev_ctx, src, dst, len, flags, slot_id);
	}
	if (flags)
		return TAPASCO_ERR_NOT_IMPLEMENTED;
	return platform_read_mem(src, len, dst, PLATFORM_MEM_FLAGS_NONE) == PLATFORM_SUCCESS ?
			TAPASCO_SUCCESS : TAPASCO_FAILURE;
}
