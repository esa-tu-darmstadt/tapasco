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
/** @file	tpc_scheduler.c
 *  @brief	Primitive scheduler.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <unistd.h>
#include <assert.h>
#include <tpc_scheduler.h>
#include <tpc_functions.h>
#include <tpc_address_map.h>
#include <tpc_device.h>
#include <tpc_logging.h>
#include <platform_api.h>

tpc_res_t tpc_scheduler_launch(
		tpc_dev_ctx_t *dev_ctx,
		tpc_jobs_t *jobs,
		tpc_functions_t *functions,
		tpc_job_id_t const j_id)
{
	tpc_res_t result = TPC_SUCCESS;
	tpc_func_id_t const f_id = tpc_jobs_get_func_id(jobs, j_id);
	tpc_func_slot_id_t slot_id;

	LOG(LALL_SCHEDULER, "job %lu: launching for function %lu, acquiring function ... ",
			(unsigned long)j_id, (unsigned long)f_id);

	while ((slot_id = tpc_functions_acquire(functions, f_id)) < 0)
		usleep(250);

	LOG(LALL_SCHEDULER, "job %lu: got function %lu",
			(unsigned long)j_id, (unsigned long)f_id);

	assert(slot_id >= 0 && slot_id < TPC_MAX_INSTANCES);

	tpc_jobs_set_state(jobs, j_id, TPC_JOB_STATE_SCHEDULED);
	// printf("job_id %d runs on slot_id %d\n", j_id, slot_id);

	uint32_t const num_args = tpc_jobs_arg_count(jobs, j_id);
	for (uint32_t a = 0; a < num_args; ++a) {
		tpc_handle_t h = tpc_address_map_func_arg_register(
				dev_ctx,
				slot_id,
				a);

		int const is64 = tpc_jobs_is_arg_64bit(jobs, j_id, a);
		if (is64) {
			uint64_t v = tpc_jobs_get_arg64(jobs, j_id, a);
			LOG(LALL_SCHEDULER, "job %lu: writing 64b arg #%u = 0x%08lx to 0x%08x",
				(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
			if (platform_write_ctl(h, sizeof(v), &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
				return TPC_FAILURE;
		} else {
			uint32_t v = tpc_jobs_get_arg32(jobs, j_id, a);
			LOG(LALL_SCHEDULER, "job %lu: writing 32b arg #%u = 0x%08lx to 0x%08x",
				(unsigned long)j_id, a, (unsigned long)v, (unsigned)h);
			if (platform_write_ctl(h, sizeof(v), &v, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
				return TPC_FAILURE;
		}
	}

	// now write start command and wait until finished
	tpc_handle_t const ctl = tpc_address_map_func_reg(
			dev_ctx, slot_id, TPC_FUNC_REG_CONTROL);
	// printf("job %d stl register at 0x%08x\n", j_id, (unsigned int)ctl);

	LOG(LALL_SCHEDULER, "job %lu: launching and waiting ...", (unsigned long)j_id);

	uint32_t start_cmd = 1;
	tpc_jobs_set_state(jobs, j_id, TPC_JOB_STATE_RUNNING);
	if ( platform_write_ctl_and_wait(ctl, sizeof(start_cmd), &start_cmd,
			slot_id, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TPC_FAILURE;

	LOG(LALL_SCHEDULER, "job %lu: returned from waiting", (unsigned long)j_id);

	uint64_t ret = 0;
	tpc_handle_t const rh = tpc_address_map_func_reg(dev_ctx, slot_id, TPC_FUNC_REG_RETURN);

	if (platform_read_ctl(rh, sizeof(ret), &ret, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TPC_FAILURE;
	tpc_jobs_set_return(jobs, j_id, sizeof(ret), &ret);
	LOG(LALL_SCHEDULER, "job %lu: read result value 0x%08lx",
			(unsigned long)j_id, (unsigned long)ret);

	// ack the interrupt
	if (platform_write_ctl(tpc_address_map_func_reg(dev_ctx, slot_id,
			TPC_FUNC_REG_IAR), sizeof(start_cmd), &start_cmd,
			PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		return TPC_FAILURE;

	// release the function
	tpc_functions_release(functions, slot_id);

	tpc_jobs_set_state(jobs, j_id, TPC_JOB_STATE_FINISHED);

	return result;
}
