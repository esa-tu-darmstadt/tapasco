//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
/**
 *  @file	tapasco_jobs.c
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <tapasco_jobs.h>
#include <gen_fixed_size_pool.h>

#define JOB_ID_OFFSET					1000

struct tapasco_job {
	/** job id */
	tapasco_job_id_t id;
	/** function id this job will be scheduled on **/
	tapasco_kernel_id_t k_id;
	/** current state of the job **/
	tapasco_job_state_t state;
	/** argument array (max 64bit, max 32 args at the moment **/
	union {
		uint32_t v32;
		uint64_t v64;
	} args[TAPASCO_JOB_MAX_ARGS];
	/** argument count **/
	size_t args_len;
	/** argument sizes **/
	size_t args_sz;
	/** direct return value of job, when finished **/
	union {
		uint64_t ret32;
		uint64_t ret64;
	} ret;
	/** transfer array (max. 32 transfers) **/
	tapasco_transfer_t transfers[TAPASCO_JOB_MAX_ARGS];
	/** slot id this job is scheduled on **/
	tapasco_slot_id_t slot;
};
typedef struct tapasco_job tapasco_job_t;

/******************************************************************************/
inline static void init_job(tapasco_job_t *job, int i)
{
	memset(job, 0, sizeof(*job));
	job->id = i + JOB_ID_OFFSET;
	job->args_len = 0;
	job->args_sz = 0;
	job->state = TAPASCO_JOB_STATE_READY;
}

MAKE_FIXED_SIZE_POOL(tapasco_jobs, TAPASCO_JOBS_Q_SZ, tapasco_job_t, init_job)

struct tapasco_jobs {
	struct tapasco_jobs_fsp_t q;
};

tapasco_res_t tapasco_jobs_init(tapasco_jobs_t **jobs)
{
	*jobs = (tapasco_jobs_t *)malloc(sizeof(tapasco_jobs_t));
	if (! jobs) return TAPASCO_ERR_OUT_OF_MEMORY;
	tapasco_jobs_fsp_init(&(*jobs)->q);
	return TAPASCO_SUCCESS;
}

void tapasco_jobs_deinit(tapasco_jobs_t *jobs)
{
	free(jobs);
}


inline
tapasco_kernel_id_t tapasco_jobs_get_kernel_id(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id)
{
	return jobs->q.elems[j_id - JOB_ID_OFFSET].k_id;
}

inline
void tapasco_jobs_set_kernel_id(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		tapasco_kernel_id_t const k_id)
{
	assert(jobs);
	jobs->q.elems[j_id - JOB_ID_OFFSET].k_id = k_id;
}

inline
tapasco_job_state_t tapasco_jobs_get_state(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id)
{
	return jobs->q.elems[j_id - JOB_ID_OFFSET].state;
}

inline
tapasco_job_state_t tapasco_jobs_set_state(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		tapasco_job_state_t const new_state)
{
	assert(jobs);
	return jobs->q.elems[j_id - JOB_ID_OFFSET].state = new_state;
}

inline
tapasco_res_t tapasco_jobs_get_return(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id,
		size_t const ret_len,
		void *ret_value)
{
	assert(jobs);
	switch (ret_len) {
	case sizeof(uint32_t): *(uint32_t *)ret_value =
			jobs->q.elems[j_id - JOB_ID_OFFSET].ret.ret32; break;
	case sizeof(uint64_t): *(uint64_t *)ret_value =
			jobs->q.elems[j_id - JOB_ID_OFFSET].ret.ret64; break;
	default: return TAPASCO_ERR_INVALID_ARG_SIZE;
	}
	return TAPASCO_SUCCESS;
}

inline
size_t tapasco_jobs_arg_count(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id)
{
	assert(jobs);
	return jobs->q.elems[j_id - JOB_ID_OFFSET].args_len;
}

inline
uint32_t tapasco_jobs_get_arg32(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx)
{
	assert(jobs);
	assert(! tapasco_jobs_is_arg_64bit(jobs, j_id, arg_idx));
	assert(arg_idx < jobs->q.elems[j_id - JOB_ID_OFFSET].args_len);
	return jobs->q.elems[j_id - JOB_ID_OFFSET].args[arg_idx].v32;
}

inline
uint64_t tapasco_jobs_get_arg64(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx)
{
	assert(jobs);
	assert(tapasco_jobs_is_arg_64bit(jobs, j_id, arg_idx));
	assert(arg_idx < jobs->q.elems[j_id - JOB_ID_OFFSET].args_len);
	return jobs->q.elems[j_id - JOB_ID_OFFSET].args[arg_idx].v64;
}

tapasco_transfer_t *tapasco_jobs_get_arg_transfer(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx)
{
	assert(jobs);
	assert(arg_idx < jobs->q.elems[j_id - JOB_ID_OFFSET].args_len);
	return &jobs->q.elems[j_id - JOB_ID_OFFSET].transfers[arg_idx];
}

inline
tapasco_res_t tapasco_jobs_get_arg(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx,
		size_t const arg_len,
		void *arg_value)
{
	assert(jobs);
#ifndef NDEBUG
	if (arg_len != sizeof(uint32_t) && arg_len != sizeof(uint64_t))
		return TAPASCO_ERR_INVALID_ARG_SIZE;
	if (arg_idx >= TAPASCO_JOB_MAX_ARGS)
		return TAPASCO_ERR_INVALID_ARG_INDEX;
	if (j_id - JOB_ID_OFFSET > TAPASCO_JOBS_Q_SZ)
		return TAPASCO_ERR_JOB_ID_NOT_FOUND;
#endif
	memcpy(arg_value, &jobs->q.elems[j_id - JOB_ID_OFFSET].args[arg_idx], arg_len);
	return TAPASCO_SUCCESS;
}

inline
tapasco_res_t tapasco_jobs_set_arg(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx,
		size_t const arg_len,
		void const *arg_value)
{
	assert(jobs);
#ifndef NDEBUG
	if (arg_len != sizeof(uint32_t) && arg_len != sizeof(uint64_t))
		return TAPASCO_ERR_INVALID_ARG_SIZE;
	if (arg_idx >= TAPASCO_JOB_MAX_ARGS)
		return TAPASCO_ERR_INVALID_ARG_INDEX;
	if (j_id - JOB_ID_OFFSET > TAPASCO_JOBS_Q_SZ)
		return TAPASCO_ERR_JOB_ID_NOT_FOUND;
#endif
	if (arg_len == sizeof(uint32_t)) {
		const uint32_t v = *(uint32_t const *)arg_value;
		// printf("tapasco_jobs_set_arg: v = %d\n", v);
		jobs->q.elems[j_id - JOB_ID_OFFSET].args[arg_idx].v32 = v;
		jobs->q.elems[j_id - JOB_ID_OFFSET].args_sz &= ~(1 << arg_idx);
	} else {
		const uint64_t v = *(uint64_t const *)arg_value;
		// printf("tapasco_jobs_set_arg: v = %ld\n", v);
		jobs->q.elems[j_id - JOB_ID_OFFSET].args[arg_idx].v64 = v;
		jobs->q.elems[j_id - JOB_ID_OFFSET].args_sz |= 1 << arg_idx;
	}
	if (jobs->q.elems[j_id - JOB_ID_OFFSET].args_len < arg_idx + 1)
		jobs->q.elems[j_id - JOB_ID_OFFSET].args_len = arg_idx + 1;
	return TAPASCO_SUCCESS;
}

inline
tapasco_res_t tapasco_jobs_set_arg_transfer(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx,
		size_t const arg_len,
		void *arg_value,
		tapasco_device_alloc_flag_t const flags,
		tapasco_copy_direction_flag_t const dir_flags)
{
	assert(jobs);
#ifndef NDEBUG
	if (arg_idx >= TAPASCO_JOB_MAX_ARGS)
		return TAPASCO_ERR_INVALID_ARG_INDEX;
	if (j_id - JOB_ID_OFFSET > TAPASCO_JOBS_Q_SZ)
		return TAPASCO_ERR_JOB_ID_NOT_FOUND;
#endif
	jobs->q.elems[j_id - JOB_ID_OFFSET].transfers[arg_idx].len   = arg_len;
	jobs->q.elems[j_id - JOB_ID_OFFSET].transfers[arg_idx].data  = arg_value;
	jobs->q.elems[j_id - JOB_ID_OFFSET].transfers[arg_idx].flags = flags;
	jobs->q.elems[j_id - JOB_ID_OFFSET].transfers[arg_idx].dir_flags = dir_flags;
	if (jobs->q.elems[j_id - JOB_ID_OFFSET].args_len < arg_idx + 1)
		jobs->q.elems[j_id - JOB_ID_OFFSET].args_len = arg_idx + 1;
	return TAPASCO_SUCCESS;
}

inline
tapasco_res_t tapasco_jobs_set_return(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		size_t const ret_len,
		void const *ret_value)
{
	assert(jobs);
#ifndef NDEBUG
	if (ret_len != sizeof(uint32_t) && ret_len != sizeof(uint64_t))
		return TAPASCO_ERR_INVALID_ARG_SIZE;
	if (j_id - JOB_ID_OFFSET > TAPASCO_JOBS_Q_SZ)
		return TAPASCO_ERR_JOB_ID_NOT_FOUND;
#endif
	if (ret_len == sizeof(uint32_t)) {
		const uint32_t v = *(uint32_t const *)ret_value;
		jobs->q.elems[j_id - JOB_ID_OFFSET].ret.ret32 = v;
	} else {
		const uint64_t v = *(uint64_t const *)ret_value;
		jobs->q.elems[j_id - JOB_ID_OFFSET].ret.ret64 = v;
	}
	return TAPASCO_SUCCESS;
}

inline
int tapasco_jobs_is_arg_64bit(tapasco_jobs_t const *jobs,
		tapasco_job_id_t const j_id,
		size_t const arg_idx)
{
	assert(jobs);
	assert(arg_idx < TAPASCO_JOB_MAX_ARGS);
	return ((1 << arg_idx) & jobs->q.elems[j_id - JOB_ID_OFFSET].args_sz) > 0;
}

tapasco_slot_id_t tapasco_jobs_get_slot(tapasco_jobs_t const *jobs, tapasco_job_id_t const j_id)
{
	assert(jobs);
	assert(j_id - JOB_ID_OFFSET < TAPASCO_JOBS_Q_SZ);
	return jobs->q.elems[j_id - JOB_ID_OFFSET].slot;
}

void tapasco_jobs_set_slot(tapasco_jobs_t *jobs,
		tapasco_job_id_t const j_id,
		tapasco_slot_id_t const slot_id)
{
	assert(jobs);
	assert(j_id - JOB_ID_OFFSET < TAPASCO_JOBS_Q_SZ);
	jobs->q.elems[j_id - JOB_ID_OFFSET].slot = slot_id;
}

inline
tapasco_job_id_t tapasco_jobs_acquire(tapasco_jobs_t *jobs)
{
	assert(jobs);
	tapasco_job_id_t j_id = tapasco_jobs_fsp_get(&jobs->q);
	if (j_id != INVALID_IDX)
		jobs->q.elems[j_id].state = TAPASCO_JOB_STATE_REQUESTED;
	return j_id != INVALID_IDX ? jobs->q.elems[j_id].id : 0;
}

inline
void tapasco_jobs_release(tapasco_jobs_t *jobs, tapasco_job_id_t const j_id)
{
	assert(jobs);
	memset(&jobs->q.elems[j_id - JOB_ID_OFFSET], 0, sizeof(tapasco_job_t));
	jobs->q.elems[j_id - JOB_ID_OFFSET].state = TAPASCO_JOB_STATE_READY;
	tapasco_jobs_fsp_put(&jobs->q, j_id - JOB_ID_OFFSET);
}
