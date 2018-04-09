//! @file 	tapasco.h
//! @brief	Tapasco API for hardware threadpool integration.
//!		Low-level API to interface hardware accelerators programmed with
//!		Tapasco support.
//! @authors 	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @authors 	D. de la Chevallerie, TU Darmstadt (dc@esa.cs.tu-darmstadt.de)
//! @version 	1.6
//! @copyright  Copyright 2014-2018 J. Korinth, TU Darmstadt
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
//!
#ifndef TAPASCO_H__
#define TAPASCO_H__

#ifdef __cplusplus
#include <cstdlib>
#else
#include <stdlib.h>
#endif /* __cplusplus */

#include <tapasco_errors.h>
#include <tapasco_global.h>
#include <tapasco_types.h>
#include <tapasco_context.h>
#include <platform.h>
#include <platform_info.h>
#include <platform_caps.h>

#define TAPASCO_VERSION_MAJOR(v) 				((v) >> 16)
#define TAPASCO_VERSION_MINOR(v) 				((v) & 0xFFFF)

/** @defgroup version Version Info
 *  @{
 **/

#define TAPASCO_API_VERSION					"1.6"

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
 * Enumerates the device in the system.
 * @param ctx pointer to global context.
 * @param num_devices pointer to variable, will be set (output)
 * @param devs pointer to an array of info structs, which will
 *             be filled during enumeration; may be NULL, if
 *             not NULL must be large enough to hold
 *             PLATFORM_MAX_DEVS instances.
 * @return TAPASCO_SUCCESS if successful, an error code otherwise.
 **/
static inline
tapasco_res_t tapasco_enum_devices(tapasco_ctx_t *ctx,
		size_t *num_devices,
		platform_device_info_t **devs)
{
	return platform_enum_devices(ctx->pctx, num_devices, devs) == PLATFORM_SUCCESS ?
			TAPASCO_SUCCESS : (tapasco_res_t)TAPASCO_ERR_PLATFORM_FAILURE;
}

/**
 * Device init; called once for exclusive acceess to given device.
 * @param ctx pointer to global context
 * @param dev_id device id
 * @param pdev_ctx pointer to device context pointer (will be set
 *                 on success)
 * @param flags device creation flags
 * @return TAPASCO_SUCCESS if sucessful, an error code otherwise
 **/
tapasco_res_t tapasco_create_device(tapasco_ctx_t *ctx,
		tapasco_dev_id_t const dev_id,
		tapasco_devctx_t **pdev_ctx,
		tapasco_device_create_flag_t const flags);

/**
 * Device deinit: called once for each valid tapasco_devctx_t to release
 * exclusive access to the device and perform clean-up tasks.
 * @param ctx global context
 * @param dev_ctx device context
 **/
void tapasco_destroy_device(tapasco_ctx_t *ctx, tapasco_devctx_t *dev_ctx);

/**
 * Retrieves an info struct containing all available information about the
 * currently loaded bitstream.
 * @param dev_ctx device context
 * @param info struct to fill with data
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_info(tapasco_devctx_t *dev_ctx, platform_info_t *info);

/**
 * Returns the number of instances of kernel k_id in the currently loaded
 * bitstream.
 * @param dev_ctx device context
 * @param k_id kernel id
 * @return number of instances > 0 if kernel is instantiated in the bitstream,
 *         0 if kernel is unavailable
 **/
size_t tapasco_device_kernel_pe_count(tapasco_devctx_t *dev_ctx,
		tapasco_kernel_id_t const k_id);

/**
 * Checks if the specified capability is available in the current bitstream.
 * @param dev_ctx device context
 * @param cap capability
 * @return TAPASCO_SUCCESS, if available, an error code otherwise
 **/
tapasco_res_t tapasco_device_has_capability(tapasco_devctx_t *dev_ctx,
		tapasco_device_capability_t cap);

/**
 * Get the processing element op. frequency of the currently loaded bitstream.
 * @param dev_ctx device context
 * @param freq output frequency var
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_design_clk(tapasco_devctx_t *dev_ctx,
		uint32_t *freq);

/**
 * Get the host interface frequency of the currently loaded bitstream.
 * @param dev_ctx device context
 * @param freq output frequency var
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_host_clk(tapasco_devctx_t *dev_ctx,
		uint32_t *freq);

/**
 * Get the memory interface frequency of the currently loaded bitstream.
 * @param dev_ctx device context
 * @param freq output frequency var
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_mem_clk(tapasco_devctx_t *dev_ctx,
		uint32_t *freq);

/**
 * Get the Vivado version with which the currently loaded bitstream was built.
 * @param dev_ctx device context
 * @param version output version var
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_get_vivado_version(tapasco_devctx_t* dev_ctx,
		uint32_t *version);

/**
 * Get the TaPaSCo version with which the currently loaded bitstream was built.
 * @param dev_ctx device context
 * @param version output version var
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_get_tapasco_version(tapasco_devctx_t *dev_ctx,
		uint32_t *version);

/**
 * Get the epoch timestamp of the time when the currently loaded bitstream was
 * built.
 * @param dev_ctx device context
 * @param timestampt output version var
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_get_compose_ts(tapasco_devctx_t *dev_ctx,
		uint32_t *ts);

/**
 * Loads the bitstream from the given file to the device.
 * @param dev_ctx device context
 * @param filename bitstream file name
 * @param flags bitstream loading flags
 * @return TAPASCO_SUCCESS if sucessful, an error code otherwise
 **/
tapasco_res_t tapasco_device_load_bitstream_from_file(
		tapasco_devctx_t *dev_ctx,
		char const *filename,
		tapasco_load_bitstream_flag_t const flags);

/**
 * Loads a bitstream to the given device.
 * @param dev_ctx device context
 * @param len size in bytes
 * @param data pointer to bitstream data
 * @param flags bitstream loading flags
 * @return TAPASCO_SUCCESS if sucessful, an error code otherwise
 **/
tapasco_res_t tapasco_device_load_bitstream(tapasco_devctx_t *dev_ctx,
		size_t const len,
		void const *data,
		tapasco_load_bitstream_flag_t const flags);

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
tapasco_res_t tapasco_device_alloc(tapasco_devctx_t *dev_ctx,
		tapasco_handle_t *handle,
		size_t const len,
		tapasco_device_alloc_flag_t const flags,
		...);

/**
 * Frees a previously allocated chunk of device memory.
 * @param dev_ctx device context
 * @param handle memory chunk handle returned by @see tapasco_alloc
 * @param flags device memory allocation flags
 **/
void tapasco_device_free(tapasco_devctx_t *dev_ctx,
		tapasco_handle_t handle,
		tapasco_device_alloc_flag_t const flags,
		...);

/**
 * Copys memory from main memory to the FPGA device.
 * @param dev_ctx device context
 * @param src source address
 * @param dst destination device handle (prev. alloc'ed with tapasco_alloc)
 * @param len number of bytes to copy
 * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
 * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_copy_to(tapasco_devctx_t *dev_ctx,
		void const *src,
		tapasco_handle_t dst,
		size_t len,
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
		tapasco_handle_t src,
		void *dst,
		size_t len,
		tapasco_device_copy_flag_t const flags,
		...);

/** @} **/


/** @defgroup exec Execution Control
 *  @{
 **/

/**
 * Obtains a job context to associate kernel parameters with, i.e., that can
 * be used in @see tapasco_set_arg calls to set kernel arguments.
 * Note: May block until job context is available.
 * @param dev_ctx device context
 * @param j_id pointer to job_id var
 * @param k_id kernel id
 * @param flags or'ed flags for the call,
 *        @see tapasco_device_acquire_job_id_flag_t for options
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_acquire_job_id(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t *j_id,
		tapasco_kernel_id_t const k_id,
		tapasco_device_acquire_job_id_flag_t flags);

/**
 * Releases a job id obtained via @see tapasco_acquire_job_id. Does not affect
 * related handles alloc'ed via tapasco_alloc, which must be release separately,
 * only release return value(s) of job.
 * @param dev_ctx device context
 * @param job_id job id to release
 **/
void tapasco_device_release_job_id(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id);

/**
 * Launches the given job and releases its id (does not affect alloc'ed handles,
 * means only that kernel arguments can no longer be set using this id).
 * @param dev_ctx device context
 * @param job_id job id
 * @param flags launch flags, e.g., TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING
 * @return TAPASCO_SUCCESS if execution was successful and results can be
 *         retrieved, an error code otherwise
 **/
tapasco_res_t tapasco_device_job_launch(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id,
		tapasco_device_job_launch_flag_t const flags);

/**
 * Waits for the given job and returns after it has finished.
 * @param dev_ctx device context
 * @param job_id job id
 * @return TAPASCO_SUCCESS, if execution finished successfully an error code
           otherwise.
 **/
tapasco_res_t tapasco_device_job_collect(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id);

/**
 * Sets the arg_idx'th argument of kernel k_id to arg_value.
 * @param dev_ctx device context
 * @param job_id job id
 * @param arg_idx argument number
 * @param arg_len length of arg_value in bytes (must be power of 4)
 * @param arg_value data to set argument to.
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_job_set_arg(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id, size_t arg_idx,
		size_t const arg_len, void const *arg_value);

/**
 * Sets the arg_idx'th argument of kernel k_id to trigger an automatic
 * transfer to and from memory allocated internally. Copies data from arg_value
 * to a newly allocated buffer before execution of the job, and copies data from
 * the buffer back to arg_value after its end.
 * Use flags to control memory location, e.g., pe-local memory.
 * @param dev_ctx device context
 * @param job_id job id
 * @param arg_idx argument number
 * @param arg_len length of arg_value in bytes (must be power of 4)
 * @param arg_value data to set argument to.
 * @param flags allocation flags, see @tapasco_device_alloc_flag_t.
 * @param flags copy direction flags, see @tapasco_copy_direction_flag_t.
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_job_set_arg_transfer(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id, size_t arg_idx,
		size_t const arg_len, void *arg_value,
		tapasco_device_alloc_flag_t const flags,
		tapasco_copy_direction_flag_t const dir_flags);

/**
 * Gets the value of the arg_idx'th argument of kernel k_id.
 * @param dev_ctx device context
 * @param job_id job id
 * @param arg_idx argument number
 * @param arg_len length of arg_value in bytes (must be power of 4)
 * @param arg_value data to store argument in.
 * @return TAPASCO_SUCCESS if successful, an error code otherwise
 **/
tapasco_res_t tapasco_device_job_get_arg(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id, size_t arg_idx,
		size_t const arg_len, void *arg_value);
/**
 * Retrieves the return value of job with the given id to ret_value.
 * @param dev_ctx device context
 * @param job_id job id
 * @param ret_len size of return value in bytes (must be power of 4)
 * @param ret_value pointer to mem to write return value to
 * @return TAPASCO_SUCCESS if sucessful, an error code otherwise
 **/
tapasco_res_t tapasco_device_job_get_return(tapasco_devctx_t *dev_ctx,
		tapasco_job_id_t const job_id, size_t const ret_len,
		void *ret_value);

/** @} **/


#endif /* TAPASCO_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
