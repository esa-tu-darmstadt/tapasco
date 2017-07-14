//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
//! @authors 	D. de la Chevallerie, TU Darmstadt (dc@esa.cs.tu-darmstadt.de)
//! @version 	1.2.1
//! @copyright  Copyright 2014, 2015 J. Korinth, TU Darmstadt
//!
//!		This file is part of Tapasco (TAPASCO).
//!
//!  		Tapasco is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		Tapasco is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with Tapasco.  If not, see
//!		<http://www.gnu.org/licenses/>.
//! @details	### Change Log ###
//!		- Version 1.3 (jk)
//!		  + added device capabilities
//!		- Version 1.2.1 (jk)
//!		  + renamed to 'tapasco.h'
//!		- Version 1.2 (jk)
//!		  + removed 'rpr' namespace
//!		- Version 1.1 (jk)
//!		  + added API version constant and automatic checks to guarantee
//!		    that the user is using the right header for the lib
//!		    (necessary due to incompatible changes between versions)
//!		  + added consistent flags to all calls for future use
//!		- Version 1.0 (jk, dc) 
//!		  + initial prototype version
//!
//! @todo 	device enumeration?
//!
#ifndef TAPASCO_H__
#define TAPASCO_H__

#ifdef __cplusplus
#include <cstdint>
#include <cstdlib>
#include <cstring>
namespace tapasco { extern "C" {
#else
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#endif /* __cplusplus */

/** @defgroup types Types
 *  @{
 **/

/** General purpose result type **/
typedef enum {
	/** Indicates unspecific failure, should not be used. **/
	TAPASCO_FAILURE = 0,
	/** Indicates successful operation. **/
	TAPASCO_SUCCESS
} tapasco_res_t;

/** FPGA context; opaque forward decl. **/
typedef struct tapasco_ctx tapasco_ctx_t;

/** Device context; opaque forward decl. **/
typedef struct tapasco_dev_ctx tapasco_dev_ctx_t;

/** Identifies a FPGA device (currently only one). **/
typedef uint32_t tapasco_dev_id_t;

/**
 * Identifies a 'processing element' on the device, i.e., a rpr::kernel
 * occurrence.
 * Note: A function can have more than one instantiation in a bitstream.
 **/
typedef uint32_t tapasco_func_id_t;

/** Identifies jobs, i.e,, sets of arguments for a kernel execution. **/
typedef uint32_t tapasco_job_id_t;

/** Device memory location handle (opaque). **/
typedef uint32_t tapasco_handle_t;

/** Flags for device creation (implementation defined). **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_CREATE_FLAGS_NONE 		= 0
} tapasco_device_create_flag_t;

/** Flags for memory allocation (implementation defined). **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_ALLOC_FLAGS_NONE 		= 0
} tapasco_device_alloc_flag_t;

/** Flags for bitstream loading (implementation defined). **/
typedef enum {
	/** no flags **/
	TAPASCO_LOAD_BITSTREAM_FLAGS_NONE 		= 0
} tapasco_load_bitstream_flag_t;

/** Flags for calls to tapasco_device_copy_to and tapasco_device_copy_from. **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_COPY_FLAGS_NONE		= 0,
	/** wait until transfer is finished (default) **/
	TAPASCO_DEVICE_COPY_BLOCKING		= 0,
	/** return immediately after transfer was scheduled **/
	TAPASCO_DEVICE_COPY_NONBLOCKING		= 1,
} tapasco_device_copy_flag_t;

/** Flags for calls to tapasco_device_acquire_job_id. **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_ACQUIRE_JOB_ID_FLAGS_NONE	= 0,
	/** wait until id becomes available (default) **/
	TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING	= 0,
	/** fail if id is not immediately available, do not wait **/
	TAPASCO_DEVICE_ACQUIRE_JOB_ID_NONBLOCKING	= 1,
} tapasco_device_acquire_job_id_flag_t;

/** Flags for calls to tapasco_device_job_launch. **/
typedef enum {
	/** no flags **/
	TAPASCO_DEVICE_JOB_LAUNCH_FLAGS_NONE	= 0,
	/** launch and wait until job is finished (default) **/
	TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING		= 0,
	/** return immediately after job is scheduled **/
	TAPASCO_DEVICE_JOB_LAUNCH_NONBLOCKING	= 1,
} tapasco_device_job_launch_flag_t;

/** Capabilities: Optional device capabilities. **/
typedef enum {
	/** PCIe devices: Adress Translation Services and Page Request Interface
	 *  support activated. **/
	TAPASCO_DEVICE_CAP_ATSPRI			= 1,
	/** PCIe devices: interactive ATS check core is present. **/
	TAPASCO_DEVICE_CAP_ATSCHECK			= 2,
} tapasco_device_capability_t;

/** @} **/


/** @defgroup version Version Info
 *  @{
 **/

#define TAPASCO_API_VERSION					"1.3"

/**
 * Returns the version string of the library.
 * @return string with version, e.g. "1.1"
 **/
const char *const tapasco_version();

/**
 * Checks if runtime version matches header. Should be called at init time.
 * @return TAPASCO_SUCCESS if version matches, an error code otherwise
 **/
tapasco_res_t tapasco_check_version(const char *const version);

/** @} **/


/** @defgroup aux Auxiliary Functions
 *  @{
 **/

/**
 * Returns a pointer to a string describing the error code in res.
 * @param res error code
 * @return pointer to description of error
 **/
const char *const tapasco_strerror(tapasco_res_t const res);

/** @} **/


/** @defgroup devmgmt Device Management
 *  @{
 **/

/**
 * Global initialization: Setup a context for management of threadpool devices.
 * Should not be called directly; @see tapasco_init.
 * @param version version string of expected TAPASCO API version
 * @param pctx pointer to context pointer (will be set on success)
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t _tapasco_init(const char *const version, tapasco_ctx_t **pctx);

/**
 * Global initialization: Setup a context for management of threadpool devices.
 * @param pctx pointer to context pointer (will be set on success)
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
inline static tapasco_res_t tapasco_init(tapasco_ctx_t **pctx)
{
	return _tapasco_init(TAPASCO_API_VERSION, pctx);
}

/**
 * Global destructor: perform global clean-up before exiting.
 * @param ctx pointer to global context
 **/
void tapasco_deinit(tapasco_ctx_t *ctx);

/**
 * Device init; called once for exclusive acceess to given device.
 * @param ctx pointer to global context
 * @param dev_id device id
 * @param pdev_ctx pointer to device context pointer (will be set
 *                 on success)
 * @param flags device creation flags
 * @return TAPASCO_SUCCESS if sucessful, an error code otherwise
 **/
tapasco_res_t tapasco_create_device(tapasco_ctx_t *ctx, tapasco_dev_id_t const dev_id,
		tapasco_dev_ctx_t **pdev_ctx, tapasco_device_create_flag_t const flags);

/**
 * Device deinit: called once for each valid tapasco_dev_ctx_t to release exclusive
 * access to the device and perform clean-up tasks.
 * @param ctx global context
 * @param dev_ctx device context
 **/
void tapasco_destroy_device(tapasco_ctx_t *ctx, tapasco_dev_ctx_t *dev_ctx);

/**
 * Returns the number of instances of function func_id in the currently
 * loaded bitstream.
 * @param dev_ctx device context
 * @param func_id function id
 * @return number of instances > 0 if function is instantiated in the bitstream,
 *         0 if function is unavailable
 **/
uint32_t tapasco_device_func_instance_count(tapasco_dev_ctx_t *dev_ctx,
		tapasco_func_id_t const func_id);

/**
 * Loads the bitstream from the given file to the device.
 * @param dev_ctx device context
 * @param filename bitstream file name
 * @param flags bitstream loading flags
 * @return TAPASCO_SUCCESS if sucessful, TAPASCO_FAILURE otherwise
 **/
tapasco_res_t tapasco_device_load_bitstream_from_file(tapasco_dev_ctx_t *dev_ctx,
		char const *filename, tapasco_load_bitstream_flag_t const flags);

/**
 * Loads a bitstream to the given device.
 * @param dev_ctx device context
 * @param len size in bytes
 * @param data pointer to bitstream data
 * @param flags bitstream loading flags
 * @return TAPASCO_SUCCESS if sucessful, TAPASCO_FAILURE otherwise
 **/
tapasco_res_t tapasco_device_load_bitstream(tapasco_dev_ctx_t *dev_ctx, size_t const len,
		void const *data, tapasco_load_bitstream_flag_t const flags);

/** @} **/


/** @defgroup data Data Management and Transfer
 *  @{
 **/

/**
 * Allocates a chunk of len bytes on the device.
 * @param dev_ctx device context
 * @param h output parameter to write the handle to
 * @param len size in bytes
 * @param flags device memory allocation flags
 * @return TAPASCO_SUCCESS if successful, error code otherwise
 **/
tapasco_res_t tapasco_device_alloc(tapasco_dev_ctx_t *dev_ctx, tapasco_handle_t *handle,
		size_t const len, tapasco_device_alloc_flag_t const flags);

/**
 * Frees a previously allocated chunk of device memory.
 * @param dev_ctx device context
 * @param handle memory chunk handle returned by @see tapasco_alloc
 * @param flags device memory allocation flags
 **/
void tapasco_device_free(tapasco_dev_ctx_t *dev_ctx, tapasco_handle_t handle,
		tapasco_device_alloc_flag_t const flags);

/**
 * Copys memory from main memory to the FPGA device.
 * @param dev_ctx device context
 * @param src source address
 * @param dst destination device handle (prev. alloc'ed with tapasco_alloc)
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @return TAPASCO_SUCCESS if copy was successful, TAPASCO_FAILURE otherwise
 **/
tapasco_res_t tapasco_device_copy_to(tapasco_dev_ctx_t *dev_ctx, void const *src,
		tapasco_handle_t dst, size_t len,
		tapasco_device_copy_flag_t const flags);

/**
 * Copys memory from FPGA device memory to main memory.
 * @param dev_ctx device context
 * @param src source device handle (prev. alloc'ed with tapasco_alloc)
 * @param dst destination address
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @return TAPASCO_SUCCESS if copy was successful, TAPASCO_FAILURE otherwise
 **/
tapasco_res_t tapasco_device_copy_from(tapasco_dev_ctx_t *dev_ctx, tapasco_handle_t src,
		void *dst, size_t len, tapasco_device_copy_flag_t const flags);

/** @} **/


/** @defgroup exec Execution Control
 *  @{
 **/

/**
 * Obtains a job context to associate function parameters with, i.e., that can
 * be used in @see tapasco_set_arg calls to set kernel arguments.
 * Note: May block until job context is available.
 * @param dev_ctx device context
 * @param func_id function id
 * @param flags or'ed flags for the call, @see tapasco_device_acquire_job_id_flag_t
 * 	  for options
 * @return job id > 0 if successful, 0 otherwise
 **/
tapasco_job_id_t tapasco_device_acquire_job_id(tapasco_dev_ctx_t *dev_ctx,
		tapasco_func_id_t const func_id,
		tapasco_device_acquire_job_id_flag_t flags);

/**
 * Releases a job id obtained via @see tapasco_acquire_job_id. Does not affect
 * related handles alloc'ed via tapasco_alloc, which must be release separately,
 * only release return value(s) of job.
 * @param dev_ctx device context
 * @param job_id job id to release
 **/
void tapasco_device_release_job_id(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const job_id);

/**
 * Launches the given job and releases its id (does not affect alloc'ed handles,
 * means only that kernel arguments can no longer be set using this id).
 * Blocks caller execution until kernel has finished.
 * @param dev_ctx device context
 * @param job_id job id
 * @param flags launch flags, e.g., TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING
 * @return TAPASCO_SUCCESS if execution was successful and results can be
 *         retrieved, TAPASCO_FAILURE otherwise.
 **/
tapasco_res_t tapasco_device_job_launch(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const job_id,
		tapasco_device_job_launch_flag_t const flags);

/**
 * Sets the arg_idx'th argument of function func_id to arg_value.
 * @param dev_ctx device context
 * @param job_id job id
 * @param arg_idx argument number
 * @param arg_len length of arg_value in bytes (must be power of 4)
 * @param arg_value data to set argument to.
 * @return TAPASCO_SUCCESS if successful, TAPASCO_FAILURE otherwise.
 **/
tapasco_res_t tapasco_device_job_set_arg(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const job_id, uint32_t arg_idx,
		size_t const arg_len, void const *arg_value);

/**
 * Gets the value of the arg_idx'th argument of function func_id.
 * @param dev_ctx device context
 * @param job_id job id
 * @param arg_idx argument number
 * @param arg_len length of arg_value in bytes (must be power of 4)
 * @param arg_value data to store argument in.
 * @return TAPASCO_SUCCESS if successful, TAPASCO_FAILURE otherwise.
 **/
tapasco_res_t tapasco_device_job_get_arg(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const job_id, uint32_t arg_idx,
		size_t const arg_len, void *arg_value);
/**
 * Retrieves the return value of job with the given id to ret_value.
 * @param dev_ctx device context
 * @param job_id job id
 * @param ret_len size of return value in bytes (must be power of 4)
 * @param ret_value pointer to mem to write return value to
 * @return TAPASCO_SUCCESS if sucessful, TAPASCO_FAILURE otherwise.
 **/
tapasco_res_t tapasco_device_job_get_return(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const job_id, size_t const ret_len,
		void *ret_value);

/** @} **/


/** @defgroup caps Device capability query
 *  @{
 **/

/**
 * Checks if the specified capability is available in the current bitstream.
 * @param dev_ctx device context
 * @param cap capability
 * @return TAPASCO_SUCCESS, if available, TAPASCO_FAILURE otherwise.
 **/
tapasco_res_t tapasco_device_has_capability(tapasco_dev_ctx_t *dev_ctx,
		tapasco_device_capability_t cap);

/** @} **/

#ifdef __cplusplus
} /* extern "C" */ } /* namespace tapasco */
#endif /* __cplusplus */

#endif /* TAPASCO_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
