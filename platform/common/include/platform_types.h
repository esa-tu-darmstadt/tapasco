//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
#ifndef PLATFORM_TYPES_H__
#define PLATFORM_TYPES_H__

#include <stdint.h>
#include <stdlib.h>
#include <tlkm_access.h>
#include <tlkm_ioctl_cmds.h>

#define PE_LOCAL_FLAG						2

/** Platform result enum type. */
typedef enum {
	/** Indicates successful operation. **/
	PLATFORM_SUCCESS					= 1
} platform_binary_res_t;

/** Public result type. */
typedef ssize_t platform_res_t;

/** Platform context: opaque forward declaration. */
typedef struct platform_ctx platform_ctx_t;

/** Platform device context: opaque forward declaration. */
typedef struct platform_devctx platform_devctx_t;

/** Platform device id type. */
typedef uint32_t platform_dev_id_t;

/** Device register space address type (opaque). **/
typedef uint32_t platform_ctl_addr_t;

/** Device memory space address type (opaque). **/
typedef uint32_t platform_mem_addr_t;

/** Identifies a slot in the design, i.e., a Function. **/
typedef uint32_t platform_slot_id_t;

/** Type used to identify kernels. **/
typedef uint32_t platform_kernel_id_t;

/**
 * Device access types:
 * Exclusive is the default for applications, they can use the device without
 * any consideration of other users/processes. Shared access enables multiple
 * devices to share limited access, which rules out exclusive access. Monitor
 * access is used by monitoring applications (e.g., tapasco-debug) to access
 * the device passively during the execution of another program.
 **/
typedef enum {
	PLATFORM_EXCLUSIVE_ACCESS 		= TLKM_ACCESS_EXCLUSIVE,
	PLATFORM_SHARED_ACCESS			= TLKM_ACCESS_SHARED,
	PLATFORM_MONITOR_ACCESS			= TLKM_ACCESS_MONITOR,
} platform_access_t;

/**
 * Platform component identifiers.
 * NOTE: This will be parsed by a simple regex in Tcl, which uses the order of
 * appearance to determine the value of the constant; make sure not to change
 * the values by assigning explicitly, or start at something other than 0.
 **/
typedef enum {
	/** TaPaSCo Status Core: bitstream information. **/
	PLATFORM_COMPONENT_STATUS 				= 0,
	/** ATS/PRI checker. **/
	PLATFORM_COMPONENT_ATSPRI,
	/** Interrupt controller #0. **/
	PLATFORM_COMPONENT_INTC0,
	/** Interrupt controller #1. **/
	PLATFORM_COMPONENT_INTC1,
	/** Interrupt controller #2. **/
	PLATFORM_COMPONENT_INTC2,
	/** Interrupt controller #3. **/
	PLATFORM_COMPONENT_INTC3,
	/** MSI-X Interrupt controller #0. **/
	PLATFORM_COMPONENT_MSIX0,
	/** MSI-X Interrupt controller #1. **/
	PLATFORM_COMPONENT_MSIX1,
	/** MSI-X Interrupt controller #2. **/
	PLATFORM_COMPONENT_MSIX2,
	/** MSI-X Interrupt controller #3. **/
	PLATFORM_COMPONENT_MSIX3,
	/** DMA engine #0. **/
	PLATFORM_COMPONENT_DMA0,
	/** DMA engine #1. **/
	PLATFORM_COMPONENT_DMA1,
	/** DMA engine #2. **/
	PLATFORM_COMPONENT_DMA2,
	/** DMA engine #3. **/
	PLATFORM_COMPONENT_DMA3,
} platform_component_t;

typedef enum {
	/** no flags **/
	PLATFORM_ALLOC_FLAGS_NONE 				= 0,
	/** PE-local memory **/
	PLATFORM_ALLOC_FLAGS_PE_LOCAL           		= PE_LOCAL_FLAG,
} platform_alloc_flags_t;

typedef enum {
	/** no flags **/
	PLATFORM_CTL_FLAGS_NONE					= 0,
	/** raw mode: no range checks, no added offsets **/
	PLATFORM_CTL_FLAGS_RAW					= 1
} platform_ctl_flags_t;

typedef enum {
	/** no flags **/
	PLATFORM_MEM_FLAGS_NONE					= 0
} platform_mem_flags_t;

typedef struct tlkm_device_info platform_device_info_t;

#include <platform_info.h>
/** @} **/

#endif /* PLATFORM_TYPES_H__ */
