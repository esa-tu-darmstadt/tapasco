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
#include <platform_info.h>

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

/** Device register space address type (opaque). **/
typedef uint32_t platform_ctl_addr_t;

/** Device memory space address type (opaque). **/
typedef uint32_t platform_mem_addr_t;

/** Identifies a slot in the design, i.e., a Function. **/
typedef uint32_t platform_slot_id_t;

/** Special platform entities with fixed addresses. **/
typedef enum {
	/** TPC Status Core: bitstream information. **/
	PLATFORM_COMPONENT_STATUS 				= 1,
	/** Interrupt controller #0. **/
	PLATFORM_COMPONENT_INTC0,
	/** Interrupt controller #1. **/
	PLATFORM_COMPONENT_INTC1,
	/** Interrupt controller #2. **/
	PLATFORM_COMPONENT_INTC2,
	/** Interrupt controller #3. **/
	PLATFORM_COMPONENT_INTC3,
	/** ATS/PRI checker. **/
	PLATFORM_COMPONENT_ATSPRI,
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

/** @} **/

#endif /* PLATFORM_TYPES_H__ */
