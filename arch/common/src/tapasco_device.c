//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
//! @file	tapasco_device.c
//! @brief	Device context struct and helper methods.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! 
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <tapasco_device.h>
#include <tapasco_jobs.h>
#include <tapasco_regs.h>
#include <tapasco_scheduler.h>
#include <tapasco_logging.h>
#include <tapasco_local_mem.h>
#include <tapasco_perfc.h>
#include <platform.h>
#include <platform_errors.h>
#include <platform_info.h>

/** System setup function. */
static void setup_system(tapasco_devctx_t *devctx)
{
	// enable interrupts, globally and for each instance
	tapasco_pemgmt_setup_system(devctx, devctx->pemgmt);
}


tapasco_res_t tapasco_create_device(tapasco_ctx_t *ctx,
		tapasco_dev_id_t const dev_id,
		tapasco_devctx_t **pdevctx,
		tapasco_device_create_flag_t const flags)
{
	tapasco_devctx_t *p = (tapasco_devctx_t *)calloc(sizeof(struct tapasco_devctx), 1);
	if (! p) {
		ERR("could not allocate tapasco device context");
		return TAPASCO_ERR_OUT_OF_MEMORY;
	}

	assert(ctx->pctx);
	platform_access_t access;
	switch (flags) {
	case TAPASCO_DEVICE_CREATE_SHARED: 	access = PLATFORM_SHARED_ACCESS; break;
	case TAPASCO_DEVICE_CREATE_MONITOR: 	access = PLATFORM_MONITOR_ACCESS; break;
	default: 				access = PLATFORM_EXCLUSIVE_ACCESS; break;
	}

	platform_res_t pr = platform_create_device(ctx->pctx, dev_id, access, &p->pdctx);
	if (pr != PLATFORM_SUCCESS) {
		ERR("creating platform device failed, error: %s (%d)", platform_strerror(pr), pr);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	tapasco_res_t res = tapasco_pemgmt_init(p, &p->pemgmt);
	res = res == TAPASCO_SUCCESS ? tapasco_jobs_init(dev_id, &p->jobs) : res;
	res = res == TAPASCO_SUCCESS ? tapasco_local_mem_init(p, &p->lmem) : res;
	if (res != TAPASCO_SUCCESS) return res;
	p->pctx = ctx->pctx;
	p->id = dev_id;
	*pdevctx = p;
	ctx->devs[dev_id] = p;
	setup_system(p);

	LOG(LALL_DEVICE, "device %d created successfully", dev_id);
	return TAPASCO_SUCCESS;
}

void tapasco_destroy_device(tapasco_ctx_t *ctx, tapasco_devctx_t *devctx)
{
#ifndef NPERFC
	fprintf(stderr, "tapasco device #%02u performance counters:\n%s",
			devctx->id, tapasco_perfc_tostring(devctx->id));
#endif /* NPERFC */
	ctx->devs[devctx->id] = NULL;
	tapasco_local_mem_deinit(devctx->lmem);
	tapasco_jobs_deinit(devctx->jobs);
	tapasco_pemgmt_deinit(devctx->pemgmt);
	platform_destroy_device(ctx->pctx, devctx->pdctx);
	free(devctx);
}

tapasco_res_t tapasco_device_load_bitstream_from_file(tapasco_devctx_t *devctx,
		char const *filename,
		tapasco_load_bitstream_flag_t const flags)
{
	return TAPASCO_ERR_NOT_IMPLEMENTED;
}

tapasco_res_t tapasco_device_load_bitstream(tapasco_devctx_t *devctx, size_t const len,
		void const *data,
		tapasco_load_bitstream_flag_t const flags)
{
	return TAPASCO_ERR_NOT_IMPLEMENTED;
}

tapasco_res_t tapasco_device_acquire_job_id(tapasco_devctx_t *devctx,
		tapasco_job_id_t *j_id,
		tapasco_kernel_id_t const k_id,
		tapasco_device_acquire_job_id_flag_t flags)
{
	if (flags) return TAPASCO_ERR_NOT_IMPLEMENTED;
	*j_id = tapasco_jobs_acquire(devctx->jobs);
	if (*j_id > 0)
		tapasco_jobs_set_kernel_id(devctx->jobs, *j_id, k_id);
	return *j_id > 0 ? TAPASCO_SUCCESS : TAPASCO_ERR_UNKNOWN_ERROR;
}

void tapasco_device_release_job_id(tapasco_devctx_t *devctx,
		tapasco_job_id_t const job_id)
{
	tapasco_jobs_release(devctx->jobs, job_id);
}

tapasco_res_t tapasco_device_job_launch(tapasco_devctx_t *devctx,
		tapasco_job_id_t const j_id,
		tapasco_device_job_launch_flag_t const flags)
{
	tapasco_res_t const r = tapasco_scheduler_launch(devctx, j_id);
	if (r != TAPASCO_SUCCESS || (flags & TAPASCO_DEVICE_JOB_LAUNCH_NONBLOCKING)) {
		return r;
	} else {
		return tapasco_scheduler_finish_job(devctx, j_id);
	}
}

tapasco_res_t tapasco_device_job_get_arg(tapasco_devctx_t *devctx,
		tapasco_job_id_t const j_id,
		size_t arg_idx,
		size_t const arg_len,
		void *arg_value)
{
	return tapasco_jobs_get_arg(devctx->jobs, j_id, arg_idx, arg_len, arg_value);
}

tapasco_res_t tapasco_device_job_set_arg(tapasco_devctx_t *devctx,
		tapasco_job_id_t const j_id,
		size_t arg_idx,
		size_t const arg_len,
		void const *arg_value)
{
	return tapasco_jobs_set_arg(devctx->jobs, j_id, arg_idx, arg_len, arg_value);
}

tapasco_res_t tapasco_device_job_set_arg_transfer(tapasco_devctx_t *devctx,
		tapasco_job_id_t const job_id,
		size_t arg_idx,
		size_t const arg_len,
		void *arg_value,
		tapasco_device_alloc_flag_t const flags,
		tapasco_copy_direction_flag_t const dir_flags)
{
	return tapasco_jobs_set_arg_transfer(devctx->jobs, job_id, arg_idx,
			arg_len, arg_value, flags, dir_flags);
}

tapasco_res_t tapasco_device_job_get_return(tapasco_devctx_t *devctx,
		tapasco_job_id_t const j_id,
		size_t const ret_len,
		void *ret_value)
{
	return tapasco_jobs_get_return(devctx->jobs, j_id, ret_len, ret_value);
}

tapasco_res_t tapasco_device_has_capability(tapasco_devctx_t *devctx,
		tapasco_device_capability_t cap)
{
	if (devctx->info.magic_id != TAPASCO_MAGIC_ID) {
		platform_res_t r = platform_info(devctx->pdctx, &devctx->info);
		if (r != PLATFORM_SUCCESS) {
			ERR("failed to get device info: %s (%d)", platform_strerror(r), r);
			return TAPASCO_ERR_PLATFORM_FAILURE;
		}
	}
	return devctx->info.caps0 & cap;
}

tapasco_res_t tapasco_device_info(tapasco_devctx_t *devctx, platform_info_t *info)
{
	if (devctx->info.magic_id != TAPASCO_MAGIC_ID) {
		platform_res_t r = platform_info(devctx->pdctx, &devctx->info);
		if (r != PLATFORM_SUCCESS) {
			ERR("failed to get device info: %s (%d)", platform_strerror(r), r);
			return TAPASCO_ERR_PLATFORM_FAILURE;
		}
	}
	memcpy(info, &devctx->info, sizeof(devctx->info));
	return TAPASCO_SUCCESS;
}
