//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
//! @file 	tapasco.h
//! @brief	Tapasco API for hardware threadpool integration.
//!		Low-level API to interface hardware accelerators programmed with
//!		Tapasco support.
//! @authors 	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
#ifndef TAPASCO_TYPES_H__
#define TAPASCO_TYPES_H__

#include <stdint.h>
#include <stdlib.h>
#include <platform_caps.h>

#define PE_LOCAL_FLAG					2

/** General purpose result type **/
typedef enum {
	/** Indicates successful operation. **/
	TAPASCO_SUCCESS					= 1
} tapasco_binary_res_t;

/** Public result type. */
typedef ssize_t tapasco_res_t;

/** TaPaSCo context; opaque forward decl. **/
typedef struct tapasco_ctx tapasco_ctx_t;

/** Device context; opaque forward decl. **/
typedef struct tapasco_dev_ctx tapasco_dev_ctx_t;

/** Unique identifier for FPGA device (currently only one). **/
typedef uint32_t tapasco_dev_id_t;

/** Unique identifier for a kernel; can be instantiated in multiple PEs. */
typedef uint32_t tapasco_kernel_id_t;

/** Virtual slot identifier. */
typedef uint32_t tapasco_slot_id_t;

/** Identifies jobs, i.e,, sets of arguments for a kernel execution. **/
typedef uint32_t tapasco_job_id_t;

/** Device memory location handle (opaque). **/
typedef uint32_t tapasco_handle_t;

/** default value for no flags **/
#define NONE						0

/** Flags for device creation (implementation defined). **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_CREATE_FLAGS_NONE 		= NONE
} tapasco_device_create_flag_t;

/** Flags for memory allocation (implementation defined). **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_ALLOC_FLAGS_NONE 		= NONE,
	/** PE-local, i.e., only accessible from scheduled PE **/
	TAPASCO_DEVICE_ALLOC_FLAGS_PE_LOCAL             = PE_LOCAL_FLAG,
} tapasco_device_alloc_flag_t;

/** Flags for bitstream loading (implementation defined). **/
typedef enum {
	/** no flags **/
	TAPASCO_LOAD_BITSTREAM_FLAGS_NONE 		= NONE,
} tapasco_load_bitstream_flag_t;

/** Flags for calls to tapasco_device_copy_to and tapasco_device_copy_from. **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_COPY_FLAGS_NONE			= NONE,
	/** wait until transfer is finished (default) **/
	TAPASCO_DEVICE_COPY_BLOCKING			= NONE,
	/** return immediately after transfer was scheduled **/
	TAPASCO_DEVICE_COPY_NONBLOCKING			= 1,
	/** copy to local memory **/
	TAPASCO_DEVICE_COPY_PE_LOCAL            	= PE_LOCAL_FLAG
} tapasco_device_copy_flag_t;

/** Flags for calls to tapasco_device_acquire_job_id. **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_ACQUIRE_JOB_ID_FLAGS_NONE	= NONE,
	/** wait until id becomes available (default) **/
	TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING		= NONE,
	/** fail if id is not immediately available, do not wait **/
	TAPASCO_DEVICE_ACQUIRE_JOB_ID_NONBLOCKING	= 1,
} tapasco_device_acquire_job_id_flag_t;

/** Flags for calls to tapasco_device_job_launch. **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_JOB_LAUNCH_FLAGS_NONE		= NONE,
	/** launch and wait until job is finished (default) **/
	TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING		= NONE,
	/** return immediately after job is scheduled **/
	TAPASCO_DEVICE_JOB_LAUNCH_NONBLOCKING		= 1,
} tapasco_device_job_launch_flag_t;

/** Flags for memory transfer directions. **/
typedef enum {
        /** Copy to the device before launch. */
	TAPASCO_COPY_DIRECTION_TO			= 1,
	/** Allocate and copy from the device after launch. */
	TAPASCO_COPY_DIRECTION_FROM			= 2,
	/** Allocate, copy to before and back after launch. */
	TAPASCO_COPY_DIRECTION_BOTH			= 3
} tapasco_copy_direction_flag_t;

#define COPY_TO					(TAPASCO_COPY_DIRECTION_TO)
#define COPY_FROM				(TAPASCO_COPY_DIRECTION_FROM)
#define COPY_BOTH				(TAPASCO_COPY_DIRECTION_BOTH)

/** Capabilities: Optional device capabilities. **/
typedef platform_capabilities_0_t tapasco_device_capability_t;

#endif /* TAPASCO_TYPES_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
