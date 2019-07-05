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
#include <assert.h>
#include <platform.h>
#include <platform_info.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <tapasco_device.h>
#include <tapasco_errors.h>
#include <tapasco_local_mem.h>
#include <tapasco_logging.h>
#include <tapasco_memory.h>

static tapasco_res_t tapasco_device_alloc_local(
    tapasco_devctx_t *devctx, tapasco_handle_t *h, size_t const len,
    tapasco_device_alloc_flag_t const flags, tapasco_slot_id_t slot_id) {
  LOG(LALL_MEM, "allocating %zd bytes of pe-local memory for slot #" PRIslot,
      len, slot_id);
  return tapasco_local_mem_alloc(devctx->lmem, slot_id, len, h);
}

static tapasco_res_t tapasco_device_free_local(
    tapasco_devctx_t *devctx, tapasco_handle_t h, size_t const len,
    tapasco_device_alloc_flag_t const flags, tapasco_slot_id_t slot_id) {
  LOG(LALL_MEM, "freeing %zd bytes of pe-local memory for slot #" PRIslot, len,
      slot_id);
  tapasco_local_mem_dealloc(devctx->lmem, slot_id, len, h);
  return TAPASCO_SUCCESS;
}

static platform_ctl_addr_t get_slot_base(tapasco_devctx_t *devctx,
                                         tapasco_slot_id_t slot_id) {
  assert(devctx->info.magic_id == TAPASCO_MAGIC_ID);
  return devctx->info.base.arch[slot_id];
}

tapasco_res_t tapasco_device_copy_to_local(
    tapasco_devctx_t *devctx, void const *src, tapasco_handle_t dst, size_t len,
    tapasco_device_copy_flag_t const flags, tapasco_slot_id_t slot_id) {
  platform_devctx_t *p = devctx->pdctx;

  tapasco_slot_id_t lmem_slot_id = tapasco_local_mem_get_slot(devctx, slot_id);

  uintptr_t ptr_a_calc = (uintptr_t)device_regspace_arch_ptr(p) +
                         ((uintptr_t)get_slot_base(devctx, lmem_slot_id) -
                          (uintptr_t)device_regspace_arch_base(p)) +
                         (uintptr_t)dst;
  volatile uint64_t *a = (volatile uint64_t *)ptr_a_calc;

  LOG(LALL_MEM,
      "copying %zd bytes locally to " PRIhandle " of slot_id #" PRIslot
      " from 0x%llx",
      len, dst, lmem_slot_id, (uint64_t)a);

  uint64_t *src_ptr = (uint64_t *)src;
  for (size_t i = 0; i < len; i += sizeof(uint64_t)) {
    *a = *src_ptr;
    ++a;
    ++src_ptr;
  }
  return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_device_copy_from_local(
    tapasco_devctx_t *devctx, tapasco_handle_t src, void *dst, size_t len,
    tapasco_device_copy_flag_t const flags, tapasco_slot_id_t slot_id) {
  platform_devctx_t *p = devctx->pdctx;

  tapasco_slot_id_t lmem_slot_id = tapasco_local_mem_get_slot(devctx, slot_id);

  uintptr_t ptr_a_calc = (uintptr_t)device_regspace_arch_ptr(p) +
                         ((uintptr_t)get_slot_base(devctx, lmem_slot_id) -
                          (uintptr_t)device_regspace_arch_base(p)) +
                         (uintptr_t)dst;
  volatile uint64_t *a = (volatile uint64_t *)ptr_a_calc;
  LOG(LALL_MEM,
      "copying %zd bytes locally from " PRIhandle " of slot_id #" PRIslot
      " from 0x%llx",
      len, dst, lmem_slot_id, (uint64_t)a);

  uint64_t *dst_ptr = (uint64_t *)dst;
  for (size_t i = 0; i < len; i += sizeof(uint64_t)) {
    *dst_ptr = *a;
    ++a;
    ++dst_ptr;
  }
  return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_device_alloc(tapasco_devctx_t *devctx,
                                   tapasco_handle_t *h, size_t const len,
                                   tapasco_device_alloc_flag_t const flags,
                                   ...) {
  platform_devctx_t *p = devctx->pdctx;
  platform_mem_addr_t addr;
  platform_res_t r;
  if (flags & TAPASCO_DEVICE_ALLOC_FLAGS_PE_LOCAL) {
    va_list ap;
    va_start(ap, flags);
    tapasco_slot_id_t s_id = va_arg(ap, tapasco_slot_id_t);
    va_end(ap);
    return tapasco_device_alloc_local(devctx, h, len, flags, s_id);
  }
  r = platform_alloc(p, len, &addr, PLATFORM_ALLOC_FLAGS_NONE);
  if (r == PLATFORM_SUCCESS) {
    LOG(LALL_MEM, "allocated %zd bytes at " PRImem, len, addr);
    *h = addr;
    return TAPASCO_SUCCESS;
  }
  WRN("could not allocate %zd bytes of device memory: %s (" PRIres ")", len,
      platform_strerror(r), r);
  return TAPASCO_ERR_OUT_OF_MEMORY;
}

void tapasco_device_free(tapasco_devctx_t *devctx, tapasco_handle_t handle,
                         tapasco_device_alloc_flag_t const flags, ...) {
  platform_devctx_t *p = devctx->pdctx;
  LOG(LALL_MEM, "freeing handle " PRIhandle, handle);
  if (flags & TAPASCO_DEVICE_ALLOC_FLAGS_PE_LOCAL) {
    va_list ap;
    va_start(ap, flags);
    tapasco_slot_id_t slot_id = va_arg(ap, tapasco_slot_id_t);
    size_t len = va_arg(ap, size_t);
    va_end(ap);
    tapasco_device_free_local(devctx, handle, len, flags, slot_id);
  }
  platform_dealloc(p, handle, PLATFORM_ALLOC_FLAGS_NONE);
}

tapasco_res_t tapasco_device_copy_to(tapasco_devctx_t *devctx, void const *src,
                                     tapasco_handle_t dst, size_t len,
                                     tapasco_device_copy_flag_t const flags,
                                     ...) {
  platform_devctx_t *p = devctx->pdctx;
  LOG(LALL_MEM, "dst = " PRIhandle ", len = %zd, flags = " PRIflags, dst, len,
      (CSTflags)flags);
  if (flags & TAPASCO_DEVICE_COPY_NONBLOCKING)
    return TAPASCO_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
  if (flags & TAPASCO_DEVICE_COPY_PE_LOCAL) {
    va_list ap;
    va_start(ap, flags);
    tapasco_slot_id_t slot_id = va_arg(ap, tapasco_slot_id_t);
    va_end(ap);
    return tapasco_device_copy_to_local(devctx, src, dst, len, flags, slot_id);
  }
  if (flags)
    return TAPASCO_ERR_NOT_IMPLEMENTED;
  return platform_write_mem(p, dst, len, src, PLATFORM_MEM_FLAGS_NONE) ==
                 PLATFORM_SUCCESS
             ? TAPASCO_SUCCESS
             : TAPASCO_ERR_PLATFORM_FAILURE;
}

tapasco_res_t tapasco_device_copy_from(tapasco_devctx_t *devctx,
                                       tapasco_handle_t src, void *dst,
                                       size_t len,
                                       tapasco_device_copy_flag_t const flags,
                                       ...) {
  platform_devctx_t *p = devctx->pdctx;
  LOG(LALL_MEM, "src = " PRIhandle ", len = %zd, flags = " PRIflags, src, len,
      (CSTflags)flags);
  if (flags & TAPASCO_DEVICE_COPY_NONBLOCKING)
    return TAPASCO_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
  if (flags & TAPASCO_DEVICE_COPY_PE_LOCAL) {
    va_list ap;
    va_start(ap, flags);
    tapasco_slot_id_t slot_id = va_arg(ap, tapasco_slot_id_t);
    va_end(ap);
    return tapasco_device_copy_from_local(devctx, src, dst, len, flags,
                                          slot_id);
  }
  if (flags)
    return TAPASCO_ERR_NOT_IMPLEMENTED;
  return platform_read_mem(p, src, len, dst, PLATFORM_MEM_FLAGS_NONE) ==
                 PLATFORM_SUCCESS
             ? TAPASCO_SUCCESS
             : TAPASCO_ERR_PLATFORM_FAILURE;
}
