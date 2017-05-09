//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	tpc_device.c
//! @brief	Zynq Platform device struct and helper methods.
//!		Makes extensive use of the arch/common code snippets to
//!		implement the various TPC API calls.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
//! @todo Remove stdio and debug output.
#include <stdio.h>
#include <tpc_device.h>
#include <tpc_jobs.h>
#include <tpc_address_map.h>
#include <tpc_scheduler.h>
#include <tpc_logging.h>
#include <platform_api.h>
#include <platform_errors.h>

/** Internal device struct implementation. */
struct tpc_dev_ctx {
	tpc_functions_t *functions;
	tpc_jobs_t *jobs;
	tpc_ctx_t *ctx;
	tpc_dev_id_t id;
};

/** Interrupt handler callback. */
void irq_handler(int const event);

/** System setup function. */
static void setup_system(tpc_dev_ctx_t *dev_ctx)
{
	// enable interrupts, globally and for each instance
	tpc_functions_setup_system(dev_ctx, dev_ctx->functions);
}

/******************************************************************************/
/* TPC API implementation. */

tpc_res_t tpc_create_device(tpc_ctx_t *ctx, tpc_dev_id_t const dev_id,
		tpc_dev_ctx_t **pdev_ctx,
		tpc_device_create_flag_t const flags)
{
	tpc_dev_ctx_t *p = (tpc_dev_ctx_t *)malloc(sizeof(struct tpc_dev_ctx));
	if (p) {
		tpc_res_t res = tpc_functions_init(&p->functions);
		res = res == TPC_SUCCESS ? tpc_jobs_init(&p->jobs) : res;
		if (res != TPC_SUCCESS) return res;
		p->ctx = ctx;
		p->id = dev_id;
		*pdev_ctx = p;
		setup_system(p);
		platform_register_irq_callback(irq_handler);
		LOG(LALL_DEVICE, "device %d created successfully", dev_id);
		return TPC_SUCCESS;
	}
	return TPC_FAILURE;
}

void tpc_destroy_device(tpc_ctx_t *ctx, tpc_dev_ctx_t *dev_ctx)
{
	platform_stop(0);
	tpc_jobs_deinit(dev_ctx->jobs);
	tpc_functions_deinit(dev_ctx->functions);
	free(dev_ctx);
}

uint32_t tpc_device_func_instance_count(tpc_dev_ctx_t *dev_ctx,
		tpc_func_id_t const func_id)
{
	assert(dev_ctx);
	//! @todo Remove this when custom AXI regset IP core is available.
	return tpc_functions_count(dev_ctx->functions, func_id);
}	

tpc_res_t tpc_device_load_bitstream_from_file(tpc_dev_ctx_t *dev_ctx,
		char const *filename,
		tpc_load_bitstream_flag_t const flags)
{
	return TPC_ERR_NOT_IMPLEMENTED;
}

tpc_res_t tpc_device_load_bitstream(tpc_dev_ctx_t *dev_ctx, size_t const len,
		void const *data,
		tpc_load_bitstream_flag_t const flags)
{
	return TPC_ERR_NOT_IMPLEMENTED;
}

tpc_res_t tpc_device_alloc(tpc_dev_ctx_t *dev_ctx, tpc_handle_t *h,
		size_t const len, tpc_device_alloc_flag_t const flags)
{
	platform_mem_addr_t addr;
	platform_res_t r;
	if ((r = platform_alloc(len, &addr, PLATFORM_ALLOC_FLAGS_NONE)) == PLATFORM_SUCCESS) {
		LOG(LALL_MEM, "allocated %zd bytes at 0x%08x", len, addr);
		*h = addr;
		return TPC_SUCCESS;
	}
	WRN("could not allocate %zd bytes of device memory: %s",
			len, platform_strerror(r));
	return TPC_ERR_OUT_OF_MEMORY;
}

void tpc_device_free(tpc_dev_ctx_t *dev_ctx, tpc_handle_t handle,
		tpc_device_alloc_flag_t const flags)
{
	LOG(LALL_MEM, "freeing handle 0x%08x", (unsigned)handle);
	platform_dealloc(handle, PLATFORM_ALLOC_FLAGS_NONE);
}

tpc_res_t tpc_device_copy_to(tpc_dev_ctx_t *dev_ctx, void const *src,
		tpc_handle_t dst, size_t len,
		tpc_device_copy_flag_t const flags)
{
	LOG(LALL_MEM, "dst = 0x%08x, len = %zd, flags = %d", (unsigned)dst, len, flags);
	if (flags & TPC_DEVICE_COPY_NONBLOCKING)
		return TPC_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags)
		return TPC_ERR_NOT_IMPLEMENTED;
	return platform_write_mem(dst, len, src, PLATFORM_MEM_FLAGS_NONE) == PLATFORM_SUCCESS ?
			TPC_SUCCESS : TPC_FAILURE;
}

tpc_res_t tpc_device_copy_from(tpc_dev_ctx_t *dev_ctx, tpc_handle_t src,
		void *dst, size_t len,
		tpc_device_copy_flag_t const flags)
{
	LOG(LALL_MEM, "src = 0x%08x, len = %zd, flags = %d", (unsigned)src, len, flags);
	if (flags & TPC_DEVICE_COPY_NONBLOCKING)
		return TPC_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags)
		return TPC_ERR_NOT_IMPLEMENTED;
	return platform_read_mem(src, len, dst, PLATFORM_MEM_FLAGS_NONE) == PLATFORM_SUCCESS ?
			TPC_SUCCESS : TPC_FAILURE;
}

tpc_job_id_t tpc_device_acquire_job_id(tpc_dev_ctx_t *dev_ctx,
		tpc_func_id_t const func_id,
		tpc_device_acquire_job_id_flag_t flags)
{
	if (flags) return TPC_ERR_NOT_IMPLEMENTED;
	tpc_job_id_t j_id = tpc_jobs_acquire(dev_ctx->jobs);
	if (j_id > 0) tpc_jobs_set_func_id(dev_ctx->jobs, j_id, func_id);
	return j_id;
}

void tpc_device_release_job_id(tpc_dev_ctx_t *dev_ctx,
		tpc_job_id_t const job_id)
{
	tpc_jobs_release(dev_ctx->jobs, job_id);
}

tpc_res_t tpc_device_job_launch(tpc_dev_ctx_t *dev_ctx,
		tpc_job_id_t const j_id,
		tpc_device_job_launch_flag_t const flags)
{
	if (flags & TPC_DEVICE_JOB_LAUNCH_NONBLOCKING)
		return TPC_ERR_NONBLOCKING_MODE_NOT_SUPPORTED;
	if (flags) return TPC_ERR_NOT_IMPLEMENTED;
	return tpc_scheduler_launch(dev_ctx, dev_ctx->jobs, dev_ctx->functions, j_id);
}

tpc_res_t tpc_device_job_get_arg(tpc_dev_ctx_t *dev_ctx,
		tpc_job_id_t const j_id, uint32_t arg_idx,
		size_t const arg_len, void *arg_value)
{
	return tpc_jobs_get_arg(dev_ctx->jobs, j_id, arg_idx, arg_len, arg_value);
}

tpc_res_t tpc_device_job_set_arg(tpc_dev_ctx_t *dev_ctx,
		tpc_job_id_t const j_id, uint32_t arg_idx,
		size_t const arg_len, void const *arg_value)
{
	return tpc_jobs_set_arg(dev_ctx->jobs, j_id, arg_idx, arg_len, arg_value);
}

tpc_res_t tpc_device_job_get_return(tpc_dev_ctx_t *dev_ctx,
		tpc_job_id_t const j_id, size_t const ret_len,
		void *ret_value)
{
	return tpc_jobs_get_return(dev_ctx->jobs, j_id, ret_len, ret_value);
}

void irq_handler(int const event)
{
	LOG(LALL_IRQ, "IRQ event #%d", event);
}

