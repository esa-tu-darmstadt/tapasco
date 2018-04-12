//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
/** @file 	platform.h
 *  @brief 	API for low-level FPGA integration. Provides basic methods to
 *  		interact with two different address spaces on the device: The
 *  		memory address space refers to device-local memories, the
 *  		register address space refers to the AXI (or similar) address
 *  		space in which IP core registers reside. Furthermore there are
 *  		methods to wait for a signal from the device (usually
 *  		interrupt-based).
 *  @authors 	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 *  @version 	1.6
 **/
#ifndef PLATFORM_API_H__
#define PLATFORM_API_H__

#include <platform_errors.h>
#include <platform_global.h>
#include <platform_types.h>
#include <platform_devctx.h>

/** @defgroup version Version Info
 *  @{
 **/

#define PLATFORM_API_VERSION				"1.6"

/**
 * Returns the version string of the library.
 * @return string with version, e.g. "1.1"
 **/
const char *const platform_version();

/**
 * Checks if runtime version matches header. Should be called at init time.
 * @return PLATFORM_SUCCESS if version matches, error code otherwise
 **/
platform_res_t platform_check_version(const char *const version);

/** @} **/


/** @defgroup platform_mgmt Auxiliary Functions
 *  @{
 **/

/**
 * Returns a pointer to a string describing the error code in res.
 * @param res error code
 * @return pointer to description of error
 **/
const char *const platform_strerror(platform_res_t res);

/** @} **/


/** @defgroup platform_mgmt Platform management
 *  @{
 **/

/**
 * Initialize platform.
 * Do not call directly, @see platform_init.
 * @param version version string of expected Platform API version
 * @param ctx pointer to platform context to initialize
 * @return PLATFORM_SUCCESS if ok, error code otherwise
 **/
platform_res_t _platform_init(const char *const version, platform_ctx_t **ctx);

/**
 * Initialize platform.
 * @return PLATFORM_SUCCESS if ok, error code otherwise
 **/
inline static platform_res_t platform_init(platform_ctx_t **ctx)
{
	return _platform_init(PLATFORM_API_VERSION, ctx);
}

/** Deinitializer. **/
void platform_deinit(platform_ctx_t *ctx);

/**
 * Enumerate available devices on current platform.
 * @param ctx Platform context
 * @param num_devices number of devices (out param)
 * @param devs pointer to array of device structs (out param)
 **/
platform_res_t platform_enum_devices(platform_ctx_t *ctx,
		size_t *num_devices,
		platform_device_info_t **devs);

/**
 * Retrieve info about the given device.
 * @param ctx Platform context
 * @param dev_id id of the device
 * @param info info structure (out param)
 * @return PLATFORM_SUCCESS, if successful, an error code otherwise.
 **/
platform_res_t platform_device_info(platform_ctx_t *ctx,
		platform_dev_id_t const dev_id,
		platform_device_info_t *info);
/**
 * Acquire the selected device and initialize the given device context.
 * @param ctx platform context
 * @param dev_id device id
 * @param mode device access type 
 * @param devctx device context to initialize (may be NULL)
 * @return PLATFORM_SUCCESS, if successful, an error code otherwise.
 **/
platform_res_t platform_create_device(platform_ctx_t *ctx, 
		platform_dev_id_t const dev_id,
		platform_access_t const mode,
		platform_devctx_t **pdctx);

/**
 * Destroy the given device context and release the selected device.
 * @param ctx platform context
 * @param pdctx device context to destroy
 **/
void platform_destroy_device(platform_ctx_t *ctx, platform_devctx_t *pdctx);

/**
 * Destroy the given device context and release the selected device.
 * @param ctx platform context
 * @param dev_id device id
 **/
void platform_destroy_device_by_id(platform_ctx_t *ctx, platform_dev_id_t const dev_id);

/** Retrieves an info struct from the hardware. **/
platform_res_t platform_info(platform_devctx_t const *ctx, platform_info_t *info);

/** @} **/

/** @defgroup platform Platform device functions
 *  @{
 **/

/**
 * Allocates a device memory block of size len.
 * @param ctx Platform context
 * @param len Size in bytes.
 * @param addr Address of memory (out).
 * @return PLATFORM_SUCCESS, if allocation succeeded.
 **/
static inline
platform_res_t platform_alloc(platform_devctx_t *ctx,
		size_t const len,
		platform_mem_addr_t *addr,
		platform_alloc_flags_t const flags)
{
	assert(ctx);
	assert(ctx->dops.alloc);
	return ctx->dops.alloc(ctx, len, addr, flags);
}

/**
 * Deallocates a block of device memory.
 * @param ctx Platform context
 * @param addr Address of memory.
 **/
static inline
platform_res_t platform_dealloc(platform_devctx_t *ctx,
		platform_mem_addr_t const addr,
		platform_alloc_flags_t const flags)
{
	assert(ctx);
	assert(ctx->dops.dealloc);
	return ctx->dops.dealloc(ctx, addr, flags);
}

/**
 * Reads the device memory at the given address.
 * @param ctx Platform context
 * @param start_addr Device memory space address to start reading from.
 * @param len Number of bytes to read.
 * @param data Preallocated memory to read into.
 * @return PLATFORM_SUCCESS if read was valid, an error code otherwise.
 **/
static inline
platform_res_t platform_read_mem(platform_devctx_t const *ctx,
		platform_mem_addr_t const addr,
		size_t const len,
		void *data,
		platform_mem_flags_t const flags)
{
	assert(ctx);
	assert(ctx->dops.read_mem);
	return ctx->dops.read_mem(ctx, addr, len, data, flags);
}

/**
 * Writes data to device memory at the given address.
 * @param ctx Platform context
 * @param start_addr Device memory space address to start writing to.
 * @param len Number of bytes to write.
 * @param data Data to write.
 * @return PLATFORM_SUCCESS if write succeeded, an error code otherwise.
 **/
static inline
platform_res_t platform_write_mem(platform_devctx_t const *ctx,
		platform_mem_addr_t const addr,
		size_t const len,
		void const *data,
		platform_mem_flags_t const flags)
{
	assert(ctx);
	assert(ctx->dops.write_mem);
	return ctx->dops.write_mem(ctx, addr, len, data, flags);
}

/**
 * Reads the device register space at the given address.
 * @param ctx Platform context
 * @param start_addr Device register space address to start reading from.
 * @param no_of_bytes Number of bytes to read.
 * @param data Preallocated memory to read into.
 * @return PLATFORM_SUCCESS if read was valid, an error code otherwise.
 **/
static inline
platform_res_t platform_read_ctl(platform_devctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const len,
		void *data,
		platform_ctl_flags_t const flags)
{
	assert(ctx);
	assert(ctx->dops.read_ctl);
	return ctx->dops.read_ctl(ctx, addr, len, data, flags);
}

/**
 * Writes device register space at the given address.
 * @param ctx Platform context
 * @param start_addr Device register space address to start writing to.
 * @param no_of_bytes Number of bytes to write.
 * @param data Pointer to block of no_of_bytes bytes of data to write.
 * @return PLATFORM_SUCCESS if write succeeded, an error code otherwise.
 **/
static inline
platform_res_t platform_write_ctl(platform_devctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const len,
		void const *data,
		platform_ctl_flags_t const flags)
{
	assert(ctx);
	assert(ctx->dops.write_ctl);
	return ctx->dops.write_ctl(ctx, addr, len, data, flags);
}

/**
 * Puts the calling thread to sleep until an interrupt is received from
 * the given slot.
 * @param ctx Platform context
 * @param slot id to wait for
 * @return PLATFORM_SUCCESS if interrupt occurred, an error code if
 * not possible (platform-dependent).
 **/
platform_res_t platform_wait_for_slot(platform_devctx_t *ctx,
		const platform_slot_id_t slot);

/** @} **/

/** @defgroup Address Map
 *  @{
 **/

/**
 * Returns the base address for the given slot id.
 * @param ctx Platform context
 * @param slot_id Slot identifier
 * @param addr Address var (output)
 * @return Slot bus address
 **/
platform_res_t platform_address_get_slot_base(platform_devctx_t const *ctx,
		platform_slot_id_t const slot_id,
		platform_ctl_addr_t *addr);

/**
 * Returns the base address for the given platform infrastructure component.
 * @param ctx Platform context
 * @param comp_id Component identifier
 * @param addr Address var (output)
 * @return Component bus address, or 0
 **/
platform_res_t platform_address_get_component_base(platform_devctx_t const *ctx,
		platform_component_t const comp_id,
		platform_ctl_addr_t *addr);
/** @} **/

#endif /* PLATFORM_API_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
