//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
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
 *  @version 	1.2
 *  @copyright	Copyright 2014, 2015 J. Korinth
 *
 *		This file is part of Tapasco (TPC).
 *
 *  		Tapasco is free software: you can redistribute it
 *		and/or modify it under the terms of the GNU Lesser General
 *		Public License as published by the Free Software Foundation,
 *		either version 3 of the License, or (at your option) any later
 *		version.
 *
 *  		Tapasco is distributed in the hope that it will be
 *		useful, but WITHOUT ANY WARRANTY; without even the implied
 *		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *		See the GNU Lesser General Public License for more details.
 *
 *  		You should have received a copy of the GNU Lesser General Public
 *		License along with Tapasco.  If not, see
 *		<http://www.gnu.org/licenses/>.
 *  @details	### Change Log ###
 *		- **06/2016: Version 1.3 (jk)**
 *		  + added 'raw' mode for read/write to bypass address filters
 *  		  + added special address for the ATS/PRI checker
 *		- **05/2017: Version 1.2.2
 *		  + renamed to platform.h
 *		- **02/2016: Version 1.2.1 (jk)**
 *  		  + added special address for the interrupt controllers, so that
 *  		    they can be accessed in a standard way using Platform API
 *		- **02/2016: Version 1.2 (jk)**
 *  		  + removed 'rpr' namespace for C++ inclusion
 *		- **10/2015: Version 1.1 (jk)**
 *  		  + added API version constant and automatic checks to guarantee
 *  		    that the user is using the right header for the lib
 *  		    (necessary due to incompatible changes between versions)
 *  		  + added consistent flags to all calls for future use
 *		- **10/2014: Version 1.0 (jk)**
 *  		  + initial prototype version
 **/
#ifndef PLATFORM_API_H__
#define PLATFORM_API_H__

#include <platform_errors.h>

#ifdef __cplusplus
namespace tapasco { namespace platform { extern "C" {
#include <cstdint>
#else
#include <stdint.h>
#include <stdlib.h>
#endif

/** @defgroup platform_types Platform types
 *  @{
 **/

/** Platform result enum type. */
typedef enum {
	PLATFORM_SUCCESS = 0,
	PLATFORM_FAILURE
} platform_binary_res_t;

/** Public result type. */
typedef ssize_t platform_res_t;

/** Get error string for error code. */
const char *const platform_strerror(platform_res_t res);

/** Device register space address type (opaque). **/
typedef uint32_t platform_ctl_addr_t;

/** Device memory space address type (opaque). **/
typedef uint32_t platform_mem_addr_t;

/** Identifies a slot in the design, i.e., a Function. **/
typedef unsigned long platform_slot_id_t;

/** Identifies a region in a slot, e.g., an AXI slave. **/
typedef unsigned long platform_slot_region_id_t;

/** Callback function for interrupts. **/
typedef void (*platform_irq_callback_t)(int);

/** Special platform entities with fixed addresses. **/
typedef enum {
	/** TPC Status Core: bitstream information. **/
	PLATFORM_SPECIAL_CTL_STATUS 		= 1,
	/** Interrupt controller #0. **/
	PLATFORM_SPECIAL_CTL_INTC0,
	/** Interrupt controller #1. **/
	PLATFORM_SPECIAL_CTL_INTC1,
	/** Interrupt controller #2. **/
	PLATFORM_SPECIAL_CTL_INTC2,
	/** Interrupt controller #3. **/
	PLATFORM_SPECIAL_CTL_INTC3,
	/** ATS/PRI checker. **/
	PLATFORM_SPECIAL_CTL_ATSPRI,
} platform_special_ctl_t;

typedef enum {
	/** no flags **/
	PLATFORM_ALLOC_FLAGS_NONE 		= 0
} platform_alloc_flags_t;

typedef enum {
	/** no flags **/
	PLATFORM_CTL_FLAGS_NONE			= 0,
	PLATFORM_CTL_FLAGS_RAW			= 1
} platform_ctl_flags_t;

typedef enum {
	/** no flags **/
	PLATFORM_MEM_FLAGS_NONE			= 0
} platform_mem_flags_t;

/** @} **/


/** @defgroup version Version Info
 *  @{
 **/

#define PLATFORM_API_VERSION				"1.3"

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


/** @defgroup platform_mgmt Platform management
 *  @{
 **/

/**
 * Initialize platform.
 * Do not call directly, @see platform_init.
 * @param version version string of expected Platform API version
 * @return PLATFORM_SUCCESS if ok, error code otherwise
 **/
platform_res_t _platform_init(const char *const version);

/**
 * Initialize platform.
 * @return PLATFORM_SUCCESS if ok, error code otherwise
 **/
inline static platform_res_t platform_init()
{
	return _platform_init(PLATFORM_API_VERSION);
}

/** Deinitializer. **/
extern void platform_deinit(void);

/** @} **/


/** @defgroup addressing Addressing functions
 *  @{
 **/

/**
 * Returns the base address of a given region in a slot.
 * @param slot_id The slot to be queried.
 * @param region_id The region to be used.
 * @return Address.
 **/
extern platform_ctl_addr_t platform_address_get_slot_base(
		platform_slot_id_t const slot_id,
		platform_slot_region_id_t const region_id);

/**
 * Returns the base address of a special platform entity.
 * @param ent The special platform entity.
 * @return Address.
 **/
extern platform_ctl_addr_t platform_address_get_special_base(
		platform_special_ctl_t const ent);

/* @} */


/** @defgroup platform Platform functions
 *  @{
 **/

/**
 * Allocates a device memory block of size len.
 * @param len Size in bytes.
 * @param addr Address of memory (out).
 * @return PLATFORM_SUCCESS, if allocation succeeded.
 **/
extern platform_res_t platform_alloc(
		size_t const len,
		platform_mem_addr_t *addr,
		platform_alloc_flags_t const flags);

/**
 * Deallocates a block of device memory.
 * @param addr Address of memory.
 **/
extern platform_res_t platform_dealloc(platform_mem_addr_t const addr,
		platform_alloc_flags_t const flags);

/**
 * Reads the device memory at the given address.
 * @param start_addr Device memory space address to start reading from.
 * @param no_of_bytes Number of bytes to read.
 * @param data Preallocated memory to read into.
 * @return PLATFORM_SUCCESS if read was valid, an error code otherwise.
 **/
extern platform_res_t platform_read_mem(
		platform_mem_addr_t const start_addr,
		size_t const no_of_bytes,
		void *data,
		platform_mem_flags_t const flags);

/**
 * Writes data to device memory at the given address.
 * @param start_addr Device memory space address to start writing to.
 * @param no_of_bytes Number of bytes to write.
 * @param data Data to write.
 * @return PLATFORM_SUCCESS if write succeeded, an error code otherwise.
 **/
extern platform_res_t platform_write_mem(
		platform_mem_addr_t const start_addr,
		size_t const no_of_bytes,
		void const*data,
		platform_mem_flags_t const flags);

/**
 * Reads the device register space at the given address.
 * @param start_addr Device register space address to start reading from.
 * @param no_of_bytes Number of bytes to read.
 * @param data Preallocated memory to read into.
 * @return PLATFORM_SUCCESS if read was valid, an error code otherwise.
 **/
extern platform_res_t platform_read_ctl(
		platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes,
		void *data,
		platform_ctl_flags_t const flags);

/**
 * Writes device register space at the given address.
 * @param start_addr Device register space address to start writing to.
 * @param no_of_bytes Number of bytes to write.
 * @param data Pointer to block of no_of_bytes bytes of data to write.
 * @return PLATFORM_SUCCESS if write succeeded, an error code otherwise.
 **/
extern platform_res_t platform_write_ctl(
		platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes,
		void const*data,
		platform_ctl_flags_t const flags);

/**
 * Writes device register space at the given address and then waits for an
 * interrupt from the device (sleep); checks r_addr upon interrupt and 
 * returns if r_mask has bits set, or repeats sleep otherwise.
 * @param w_addr Device register space address to write.
 * @param w_no_of_bytes Number of bytes to write.
 * @param w_data Data to write.
 * @param event Event # to wait for.
 * @return PLATFORM_SUCCESS if successful, an error code otherwise.
 **/
extern platform_res_t platform_write_ctl_and_wait(
		platform_ctl_addr_t const w_addr,
		size_t const w_no_of_bytes,
		void const *w_data,
		uint32_t const event,
		platform_ctl_flags_t const flags);

/**
 * Puts the calling thread to sleep until an interrupt is received.
 * @param inst Deprecated, use any value.
 * @return PLATFORM_SUCCESS if interrupt occurred, an error code if
 * not possible (platform-dependent).
 **/
extern platform_res_t platform_wait_for_irq(const uint32_t inst);

/**
 * Registers the given interrupt callback function. It will be called
 * with the corr. event number, whenever an interrupt occurs.
 * Note: cb should be reentrant.
 * @param cb Callback function.
 **/
extern platform_res_t platform_register_irq_callback(platform_irq_callback_t cb);

/** @} **/


/** @defgroup platform_sim Optional platform functions for simulation
 *  @{
 **/

/**
 * Send stop command to the platform.
 * Implementation-defined behaviour; may do nothing at all.
 * @return PLATFORM_SUCCESS if successful, PLATFORM_FAILURE otherwise.
 **/
extern platform_res_t platform_stop(const int result);

/**
 * Returns the current time at the platform.
 * Implementation-defined behaviour; only really useful in simulation.
 * @param time Output var for timestamp (often in cycles).
 * @return PLATFORM_SUCESS if valid, PLATFORM_FAILURE otherwise.
 **/
extern platform_res_t platform_get_time(int64_t *time);

/**
 * Advances the simulation by given number of cycles.
 * @param cycles Number of cycles to advance simulation time by.
 * @return PLATFORM_SUCCESS if possible, PLATFORM_FAILURE otherwise.
 **/
extern platform_res_t platform_wait_cycles(const int cycles);

/** @} **/


#ifdef __cplusplus
} /* extern "C" */ } /* namespace platform */ } /* namespace tapasco */
#endif

#endif /* PLATFORM_API_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
