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

tapasco_res_t tapasco_scheduler_launch(tapasco_dev_ctx_t *dev_ctx, tapasco_job_id_t const j_id)
{
	tapasco_jobs_t *jobs = tapasco_device_jobs(dev_ctx);
	tapasco_pemgmt_t *pemgmt = tapasco_device_pemgmt(dev_ctx);
	tapasco_kernel_id_t const k_id = tapasco_jobs_get_kernel_id(jobs, j_id);
	tapasco_slot_id_t slot_id;

	LOG(LALL_SCHEDULER, "job %lu: launching for kernel %lu, acquiring PE ... ",
			(ul)j_id, (ul)k_id);

	while ((slot_id = tapasco_pemgmt_acquire(pemgmt, k_id)) >= TAPASCO_NUM_SLOTS)
		usleep(250);

	LOG(LALL_SCHEDULER, "job %lu: got PE %lu", (ul)j_id, (ul)slot_id);

	assert(slot_id >= 0 && slot_id < TAPASCO_NUM_SLOTS);

	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_SCHEDULED);

	LOG(LALL_SCHEDULER, "job %lu: preparing slot #%lu ...", (ul)j_id, (ul)slot_id);
	tapasco_res_t r = tapasco_pemgmt_prepare_slot(dev_ctx, j_id, slot_id);

	if (r != TAPASCO_SUCCESS) {
		ERR("could not prepare slot #%lu for job #%lu: %s (%d)", (ul)slot_id, (ul)j_id,
				tapasco_strerror(r), r);
		return r;
	}

	LOG(LALL_SCHEDULER, "job %lu: starting PE in slot #%lu ...", (ul)j_id, (ul)slot_id);
	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_RUNNING);
	tapasco_jobs_set_slot(jobs, j_id, slot_id);
	r = tapasco_pemgmt_start(dev_ctx, slot_id);

	if (r != TAPASCO_SUCCESS) {
		ERR("could not start PE in slot #%lu: %s (%d)", (ul)slot_id, tapasco_strerror(r), r);
		return r;
	}

	return TAPASCO_SUCCESS;
}

inline
tapasco_res_t tapasco_device_job_collect(tapasco_dev_ctx_t *dev_ctx, tapasco_job_id_t const job_id)
{
	return tapasco_scheduler_finish_job(dev_ctx, job_id);
}


tapasco_res_t tapasco_scheduler_finish_job(tapasco_dev_ctx_t *dev_ctx,
		tapasco_job_id_t const j_id)
{
	tapasco_jobs_t *jobs = tapasco_device_jobs(dev_ctx);
	platform_ctx_t *pctx = tapasco_device_platform(dev_ctx);
	tapasco_slot_id_t slot_id = tapasco_jobs_get_slot(jobs, j_id);
	LOG(LALL_SCHEDULER, "job %lu:  waiting for slot #%lu ...", (ul)j_id, (ul)slot_id);
	platform_res_t pr = platform_wait_for_slot(pctx, slot_id);

	if (pr != PLATFORM_SUCCESS) {
		ERR("waiting for job #%lu failed: %s (%d)", (ul)j_id, platform_strerror(pr), pr);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	LOG(LALL_SCHEDULER, "job %lu: returned successfully from waiting", (ul)j_id);

	return tapasco_pemgmt_finish_job(dev_ctx, j_id);
}
