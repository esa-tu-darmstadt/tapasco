/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef PLATFORM_TYPES_H__
#define PLATFORM_TYPES_H__

#include "platform_components.h"
#include <stdint.h>
#include <stdlib.h>
#include <sys/types.h>
#include <tlkm_access.h>
#include <tlkm_ioctl_cmds.h>

#define PE_LOCAL_FLAG 2

typedef uint64_t u64;
typedef uint32_t u32;
typedef int64_t s64;
typedef int32_t s32;

/** Platform result enum type. */
typedef enum {
  /** Indicates successful operation. **/
  PLATFORM_SUCCESS = 1
} platform_binary_res_t;

/** Public result type. */
typedef ssize_t platform_res_t;
#define PRIres "%zd"

/** Platform context: opaque forward declaration. */
typedef struct platform_ctx platform_ctx_t;

/** Platform device context: opaque forward declaration. */
typedef struct platform_devctx platform_devctx_t;

/** Platform device id type. */
typedef uint32_t platform_dev_id_t;
#define PRIdev "%02u"

/** Device register space address type (opaque). **/
typedef uint32_t platform_ctl_addr_t;
#define PRIctl "%#08x"

/** Device memory space address type (opaque). **/
typedef uint64_t platform_mem_addr_t;
#define PRImem "%#08x"

/** Identifies a slot in the design, i.e., a Function. **/
typedef uint32_t platform_slot_id_t;
#define PRIslot "%03u"

/** Type used to identify kernels. **/
typedef uint32_t platform_kernel_id_t;
#define PRIkernel "%u"

#define CSTflags unsigned long
#define PRIflags "%#08lx"

/**
 * Device access types:
 * Exclusive is the default for applications, they can use the device without
 * any consideration of other users/processes. Shared access enables multiple
 * devices to share limited access, which rules out exclusive access. Monitor
 * access is used by monitoring applications (e.g., tapasco-debug) to access
 * the device passively during the execution of another program.
 **/
typedef enum {
  PLATFORM_EXCLUSIVE_ACCESS = TLKM_ACCESS_EXCLUSIVE,
  PLATFORM_SHARED_ACCESS = TLKM_ACCESS_SHARED,
  PLATFORM_MONITOR_ACCESS = TLKM_ACCESS_MONITOR,
} platform_access_t;

typedef enum {
  /** no flags **/
  PLATFORM_ALLOC_FLAGS_NONE = 0,
  /** PE-local memory **/
  PLATFORM_ALLOC_FLAGS_PE_LOCAL = PE_LOCAL_FLAG,
} platform_alloc_flags_t;

typedef enum {
  /** no flags **/
  PLATFORM_CTL_FLAGS_NONE = 0,
  /** raw mode: no range checks, no added offsets **/
  PLATFORM_CTL_FLAGS_RAW = 1
} platform_ctl_flags_t;

typedef enum {
  /** no flags **/
  PLATFORM_MEM_FLAGS_NONE = 0
} platform_mem_flags_t;

typedef struct tlkm_device_info platform_device_info_t;

#include <platform_info.h>
/** @} **/

#endif /* PLATFORM_TYPES_H__ */
