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
/** @file	tapasco_scheduler.c
 *  @brief	Primitive scheduler.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <unistd.h>
#include <assert.h>
#include <tapasco_scheduler.h>
#include <tapasco_pemgmt.h>
#include <tapasco_regs.h>
#include <tapasco_device.h>
#include <tapasco_logging.h>
#include <platform.h>

// TODO tapasco_scheduler needs refactoring

static inline
tapasco_res_t tapasco_transfer_to(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const j_id,
		tapasco_transfer_t *t,
		tapasco_slot_id_t s_id)
{
	LOG(LALL_SCHEDULER, "job %lu: executing transfer to with length %zd bytes",
			(unsigned long)j_id, (unsigned long)t->len);
	tapasco_res_t res = tapasco_device_alloc(dev_ctx, &t->handle, t->len,
			t->flags, s_id);
	if (res != TAPASCO_SUCCESS) {
		ERR("job %lu: memory allocation failed!", (unsigned long)j_id);
		return res;
	}
	res = tapasco_device_copy_to(dev_ctx, t->data, t->handle, t->len,
			t->flags, s_id);
	if (res != TAPASCO_SUCCESS) {
		ERR("job %lu: transfer failed - %zd bytes -> 0x%08x with flags %lu",
				(unsigned long)j_id, t->len,
				(unsigned long)t->handle,
				(unsigned long)t->flags);
	}
	return res;
}

static inline
tapasco_res_t tapasco_transfer_from(tapasco_dev_ctx_t *dev_ctx,
		tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		tapasco_transfer_t *t,
		tapasco_slot_id_t s_id)
{
	LOG(LALL_SCHEDULER, "job %lu: executing transfer from with length %zd bytes",
			(unsigned long)j_id, (unsigned long)t->len);
	tapasco_res_t res = tapasco_device_copy_from(dev_ctx, t->handle,
			t->data, t->len, t->flags, s_id);
	if (res != TAPASCO_SUCCESS) {
		ERR("job %lu: transfer failed - %zd bytes <- 0x%08x with flags %lu",
				(unsigned long)j_id, t->len,
				(unsigned long)t->handle,
				(unsigned long)t->flags);
	}
	tapasco_device_free(dev_ctx, t->handle, t->flags, s_id, t->len);
	return res;
}

static inline
tapasco_res_t tapasco_write_arg(tapasco_dev_ctx_t *dev_ctx,
		tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		tapasco_handle_t const h,
		size_t const a)
{
	int const is64 = tapasco_jobs_is_arg_64bit(jobs, j_id, a);
	if (is64) {
		uint64_t v = tapasco_jobs_get_arg64(jobs, j_id, a);
		LOG(LALL_SCHEDULER, "job %lu: writing 64b arg #%u = 0x%08lx to 0x%08x",
			(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
		if (platform_write_ctl(h, sizeof(v), &v,
				PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
			return TAPASCO_ERR_PLATFORM_FAILURE;
	} else {
		uint32_t v = tapasco_jobs_get_arg32(jobs, j_id, a);
		LOG(LALL_SCHEDULER, "job %lu: writing 32b arg #%u = 0x%08lx to 0x%08x",
			(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
		if (platform_write_ctl(h, sizeof(v), &v,
				PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
			return TAPASCO_ERR_PLATFORM_FAILURE;
	}
	return TAPASCO_SUCCESS;
}

static inline
tapasco_res_t tapasco_read_arg(tapasco_dev_ctx_t *dev_ctx,
		tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		tapasco_handle_t const h,
		size_t const a)
{
	int const is64 = tapasco_jobs_is_arg_64bit(jobs, j_id, a);
	if (is64) {
		uint64_t v = 0;
		if (platform_read_ctl(h, sizeof(v), &v,
				PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
			return TAPASCO_ERR_PLATFORM_FAILURE;
		LOG(LALL_SCHEDULER, "job %lu: reading 64b arg #%u = 0x%08lx from 0x%08x",
			(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
		tapasco_jobs_set_arg(jobs, j_id, a, sizeof(v), &v);
	} else {
		uint32_t v = 0;
		if (platform_read_ctl(h, sizeof(v), &v,
				PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
			return TAPASCO_ERR_PLATFORM_FAILURE;
		LOG(LALL_SCHEDULER, "job %lu: reading 32b arg #%u = 0x%08lx from 0x%08x",
			(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
		tapasco_jobs_set_arg(jobs, j_id, a, sizeof(v), &v);
	}
	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_scheduler_launch(
		tapasco_dev_ctx_t *dev_ctx,
		tapasco_jobs_t *jobs,
		tapasco_pemgmt_t *pemgmt,
		tapasco_job_id_t const j_id)
{
	tapasco_res_t result = TAPASCO_SUCCESS;
	tapasco_kernel_id_t const k_id = tapasco_jobs_get_kernel_id(jobs, j_id);
	tapasco_slot_id_t slot_id;

	LOG(LALL_SCHEDULER, "job %lu: launching for kernel %lu, acquiring PE ... ",
			(unsigned long)j_id, (unsigned long)k_id);

	while ((slot_id = tapasco_pemgmt_acquire(pemgmt, k_id)) < 0)
		usleep(250);

	LOG(LALL_SCHEDULER, "job %lu: got PE %lu",
			(unsigned long)j_id, (unsigned long)slot_id);

	assert(slot_id >= 0 && slot_id < TAPASCO_NUM_SLOTS);

	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_SCHEDULED);

	size_t const num_args = tapasco_jobs_arg_count(jobs, j_id);
	for (size_t a = 0; a < num_args; ++a) {
		tapasco_res_t r = TAPASCO_SUCCESS;
		tapasco_handle_t h = tapasco_regs_arg_register(dev_ctx,
				slot_id, a);
		tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(jobs,
				j_id, a);
		if (t->len > 0) {
			LOG(LALL_SCHEDULER, "job %lu: transferring %zd byte arg #%zd",
					(unsigned long)j_id, t->len, a);
			r = tapasco_transfer_to(dev_ctx, j_id, t, slot_id);
			if (r != TAPASCO_SUCCESS) { return r; }
			LOG(LALL_SCHEDULER, "job %lu: writing handle to arg #%zd (0x%08x)",
					(unsigned long)j_id, a, t->handle);
			if (platform_write_ctl(h, sizeof(t->handle), &t->handle,
					PLATFORM_CTL_FLAGS_NONE) !=
					PLATFORM_SUCCESS)
				return TAPASCO_ERR_PLATFORM_FAILURE;
		} else {
			tapasco_res_t r = tapasco_write_arg(dev_ctx, jobs, j_id,
					a, h);
			if (r != TAPASCO_SUCCESS) { return r; }
		}
	}

	// now write start command and wait until finished
	tapasco_handle_t const ctl = tapasco_regs_named_register(dev_ctx,
			slot_id, TAPASCO_REG_CTRL);

	LOG(LALL_SCHEDULER, "job %lu: launching and waiting ...",
			(unsigned long)j_id);

	uint32_t start_cmd = 1;
	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_RUNNING);
	if (platform_write_ctl_and_wait(ctl, sizeof(start_cmd), &start_cmd,
			slot_id, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_ERR_PLATFORM_FAILURE;

	LOG(LALL_SCHEDULER, "job %lu: returned from waiting",
			(unsigned long)j_id);

	uint64_t ret = 0;
	tapasco_handle_t const rh = tapasco_regs_named_register(dev_ctx,
			slot_id, TAPASCO_REG_RET);

	if (platform_read_ctl(rh, sizeof(ret), &ret,
			PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_ERR_PLATFORM_FAILURE;
	tapasco_jobs_set_return(jobs, j_id, sizeof(ret), &ret);
	LOG(LALL_SCHEDULER, "job %lu: read result value 0x%08lx",
			(unsigned long)j_id, (unsigned long)ret);

	// Read back values from all argument registers
	for (size_t a = 0; a < num_args; ++a) {
		tapasco_handle_t h = tapasco_regs_arg_register(dev_ctx,
				slot_id, a);
		tapasco_res_t r = TAPASCO_SUCCESS;
		tapasco_transfer_t *t = tapasco_jobs_get_arg_transfer(jobs,
				j_id, a);
		r = tapasco_read_arg(dev_ctx, jobs, j_id, h, a);
		if (r != TAPASCO_SUCCESS) { return r; }
		r = tapasco_transfer_from(dev_ctx, jobs, j_id, t, slot_id);
	}

	// ack the interrupt
	if (platform_write_ctl(tapasco_regs_named_register(dev_ctx, slot_id,
			TAPASCO_REG_IAR), sizeof(start_cmd), &start_cmd,
			PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_ERR_PLATFORM_FAILURE;

	// release the PE
	tapasco_pemgmt_release(pemgmt, slot_id);
	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_FINISHED);
	return result;
}
