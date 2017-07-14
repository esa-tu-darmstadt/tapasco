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
#include <tapasco_functions.h>
#include <tapasco_address_map.h>
#include <tapasco_device.h>
#include <tapasco_logging.h>
#include <platform.h>

tapasco_res_t tapasco_scheduler_launch(
		tapasco_dev_ctx_t *dev_ctx,
		tapasco_jobs_t *jobs,
		tapasco_functions_t *functions,
		tapasco_job_id_t const j_id)
{
	tapasco_res_t result = TAPASCO_SUCCESS;
	tapasco_func_id_t const f_id = tapasco_jobs_get_func_id(jobs, j_id);
	tapasco_func_slot_id_t slot_id;

	LOG(LALL_SCHEDULER, "job %lu: launching for function %lu, acquiring function ... ",
			(unsigned long)j_id, (unsigned long)f_id);

	while ((slot_id = tapasco_functions_acquire(functions, f_id)) < 0)
		usleep(250);

	LOG(LALL_SCHEDULER, "job %lu: got function %lu",
			(unsigned long)j_id, (unsigned long)f_id);

	assert(slot_id >= 0 && slot_id < TAPASCO_MAX_INSTANCES);

	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_SCHEDULED);
	// printf("job_id %d runs on slot_id %d\n", j_id, slot_id);

	uint32_t const num_args = tapasco_jobs_arg_count(jobs, j_id);
	for (uint32_t a = 0; a < num_args; ++a) {
		tapasco_handle_t h = tapasco_address_map_func_arg_register(
				dev_ctx,
				slot_id,
				a);

		int const is64 = tapasco_jobs_is_arg_64bit(jobs, j_id, a);
		if (is64) {
			uint64_t v = tapasco_jobs_get_arg64(jobs, j_id, a);
			LOG(LALL_SCHEDULER, "job %lu: writing 64b arg #%u = 0x%08lx to 0x%08x",
				(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
			if (platform_write_ctl(h, sizeof(v), &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
				return TAPASCO_FAILURE;
		} else {
			uint32_t v = tapasco_jobs_get_arg32(jobs, j_id, a);
			LOG(LALL_SCHEDULER, "job %lu: writing 32b arg #%u = 0x%08lx to 0x%08x",
				(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
			if (platform_write_ctl(h, sizeof(v), &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
				return TAPASCO_FAILURE;
		}
	}

	// now write start command and wait until finished
	tapasco_handle_t const ctl = tapasco_address_map_func_reg(
			dev_ctx, slot_id, TAPASCO_FUNC_REG_CONTROL);
	// printf("job %d stl register at 0x%08x\n", j_id, (unsigned int)ctl);

	LOG(LALL_SCHEDULER, "job %lu: launching and waiting ...", (unsigned long)j_id);

	uint32_t start_cmd = 1;
	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_RUNNING);
	if ( platform_write_ctl_and_wait(ctl, sizeof(start_cmd), &start_cmd,
			slot_id, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_FAILURE;

	LOG(LALL_SCHEDULER, "job %lu: returned from waiting", (unsigned long)j_id);

	uint64_t ret = 0;
	tapasco_handle_t const rh = tapasco_address_map_func_reg(dev_ctx, slot_id, TAPASCO_FUNC_REG_RETURN);

	if (platform_read_ctl(rh, sizeof(ret), &ret, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_FAILURE;
	tapasco_jobs_set_return(jobs, j_id, sizeof(ret), &ret);
	LOG(LALL_SCHEDULER, "job %lu: read result value 0x%08lx",
			(unsigned long)j_id, (unsigned long)ret);

	// ack the interrupt
	if (platform_write_ctl(tapasco_address_map_func_reg(dev_ctx, slot_id,
			TAPASCO_FUNC_REG_IAR), sizeof(start_cmd), &start_cmd,
			PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TAPASCO_FAILURE;

	// release the function
	tapasco_functions_release(functions, slot_id);

	tapasco_jobs_set_state(jobs, j_id, TAPASCO_JOB_STATE_FINISHED);

	return result;
}
