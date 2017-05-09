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
/**
 *  @file	tpc_jobs.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
// #include <stdio.h>
#include <assert.h>
#include <tpc_jobs.h>
#include "gen_fixed_size_pool.h"

struct tpc_job {
	/** job id */
	tpc_job_id_t id;
	/** function id this job will be scheduled on **/
	tpc_func_id_t f_id;
	/** current state of the job **/
	tpc_job_state_t state;
	/** argument array (max 64bit, max 32 args at the moment **/
	union {
		uint32_t v32;
		uint64_t v64;
	} args[TPC_JOB_MAX_ARGS];
	/** argument count **/
	uint32_t args_len;
	/** argument sizes **/
	uint32_t args_sz;
	/** direct return value of job, when finished **/
	union {
		uint64_t ret32;
		uint64_t ret64;
	} ret;
};
typedef struct tpc_job tpc_job_t;

/******************************************************************************/
inline static void init_job(tpc_job_t *job, int i) {
	job->id = i + 1000;
	job->args_len = 0;
	job->args_sz = 0;
	job->state = TPC_JOB_STATE_READY;
}

MAKE_FIXED_SIZE_POOL(tpc_jobs, TPC_JOBS_Q_SZ, tpc_job_t, init_job)

struct tpc_jobs {
	struct tpc_jobs_fsp_t q;
};

tpc_res_t tpc_jobs_init(tpc_jobs_t **jobs) {
	*jobs = (tpc_jobs_t *)malloc(sizeof(tpc_jobs_t));
	if (! jobs) return TPC_ERR_OUT_OF_MEMORY;
	tpc_jobs_fsp_init(&(*jobs)->q);
	return TPC_SUCCESS;
}

void tpc_jobs_deinit(tpc_jobs_t *jobs) {
	free(jobs);
}


inline tpc_func_id_t tpc_jobs_get_func_id(tpc_jobs_t const *jobs,
		tpc_job_id_t const j_id) {
	return jobs->q.elems[j_id - 1000].f_id;
}

inline void tpc_jobs_set_func_id(tpc_jobs_t *jobs,
		tpc_job_id_t const j_id, tpc_func_id_t const f_id) {
	assert(jobs);
	jobs->q.elems[j_id - 1000].f_id = f_id;
}

inline tpc_job_state_t tpc_jobs_get_state(tpc_jobs_t const *jobs,
		tpc_job_id_t const j_id) {
	return jobs->q.elems[j_id - 1000].state;
}

inline tpc_job_state_t tpc_jobs_set_state(tpc_jobs_t *jobs,
		tpc_job_id_t const j_id,
		tpc_job_state_t const new_state) {
	assert(jobs);
	/*printf("job id %d in state %d being set to state %d\n",
		jobs->q[j_id - 1000]->id, jobs->q[j_id - 1000]->state,
		new_state);*/
	return jobs->q.elems[j_id - 1000].state = new_state;
}

inline tpc_res_t tpc_jobs_get_return(tpc_jobs_t const *jobs,
		tpc_job_id_t const j_id, size_t const ret_len,
		void *ret_value) {
	assert(jobs);
	switch (ret_len) {
	case 4: *(uint32_t *)ret_value = jobs->q.elems[j_id - 1000].ret.ret32; break;
	case 8: *(uint64_t *)ret_value = jobs->q.elems[j_id - 1000].ret.ret64; break;
	default: return TPC_ERR_INVALID_ARG_SIZE;
	}
	return TPC_SUCCESS;
}

inline uint32_t tpc_jobs_arg_count(tpc_jobs_t const *jobs, tpc_job_id_t const j_id) {
	assert(jobs);
	return jobs->q.elems[j_id - 1000].args_len;
}

inline uint32_t tpc_jobs_get_arg32(tpc_jobs_t const *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx) {
	assert(jobs);
	assert(! tpc_jobs_is_arg_64bit(jobs, j_id, arg_idx));
	assert(arg_idx < jobs->q.elems[j_id - 1000].args_len);
	return jobs->q.elems[j_id - 1000].args[arg_idx].v32;
}

inline uint64_t tpc_jobs_get_arg64(tpc_jobs_t const *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx) {
	assert(jobs);
	assert(tpc_jobs_is_arg_64bit(jobs, j_id, arg_idx));
	assert(arg_idx < jobs->q.elems[j_id - 1000].args_len);
	return jobs->q.elems[j_id - 1000].args[arg_idx].v64;
}

inline tpc_res_t tpc_jobs_get_arg(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx, size_t const arg_len, void *arg_value) {
	assert(jobs);
	/*printf("tpc_jobs_set_arg: j_id = %d, arg_idx = %d, arg_len = %zd\n",
			j_id, arg_idx, arg_len);*/
#ifndef NDEBUG
	if (arg_len != 4 && arg_len != 8)
		return TPC_ERR_INVALID_ARG_SIZE;
	if (arg_idx >= TPC_JOB_MAX_ARGS)
		return TPC_ERR_INVALID_ARG_INDEX;
	if (j_id - 1000 > TPC_JOBS_Q_SZ)
		return TPC_ERR_JOB_ID_NOT_FOUND;
#endif
	memcpy(arg_value, &jobs->q.elems[j_id - 1000].args[arg_idx], arg_len);
	return TPC_SUCCESS;
}

inline tpc_res_t tpc_jobs_set_arg(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx, size_t const arg_len, void const *arg_value) {
	assert(jobs);
	/*printf("tpc_jobs_set_arg: j_id = %d, arg_idx = %d, arg_len = %zd\n",
			j_id, arg_idx, arg_len);*/
#ifndef NDEBUG
	if (arg_len != 4 && arg_len != 8)
		return TPC_ERR_INVALID_ARG_SIZE;
	if (arg_idx >= TPC_JOB_MAX_ARGS)
		return TPC_ERR_INVALID_ARG_INDEX;
	if (j_id - 1000 > TPC_JOBS_Q_SZ)
		return TPC_ERR_JOB_ID_NOT_FOUND;
#endif
	if (arg_len == 4) {
		const uint32_t v = *(uint32_t const *)arg_value;
		// printf("tpc_jobs_set_arg: v = %d\n", v);
		jobs->q.elems[j_id - 1000].args[arg_idx].v32 = v;
		jobs->q.elems[j_id - 1000].args_sz &= ~(1 << arg_idx);
	} else {
		const uint64_t v = *(uint64_t const *)arg_value;
		// printf("tpc_jobs_set_arg: v = %ld\n", v);
		jobs->q.elems[j_id - 1000].args[arg_idx].v64 = v;
		jobs->q.elems[j_id - 1000].args_sz |= 1 << arg_idx;
	}
	if (jobs->q.elems[j_id - 1000].args_len < arg_idx + 1)
		jobs->q.elems[j_id - 1000].args_len = arg_idx + 1;
	return TPC_SUCCESS;
}

inline tpc_res_t tpc_jobs_set_return(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		size_t const ret_len, void const *ret_value) {
	assert(jobs);
#ifndef NDEBUG
	if (ret_len != 4 && ret_len != 8)
		return TPC_ERR_INVALID_ARG_SIZE;
	if (j_id - 1000 > TPC_JOBS_Q_SZ)
		return TPC_ERR_JOB_ID_NOT_FOUND;
#endif
	if (ret_len == 4) {
		const uint32_t v = *(uint32_t const *)ret_value;
		jobs->q.elems[j_id - 1000].ret.ret32 = v;
	} else {
		const uint64_t v = *(uint64_t const *)ret_value;
		jobs->q.elems[j_id - 1000].ret.ret64 = v;
	}
	return TPC_SUCCESS;
}

inline int tpc_jobs_is_arg_64bit(tpc_jobs_t const *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx) {
	assert(jobs);
	assert(arg_idx < TPC_JOB_MAX_ARGS);
	return ((1 << arg_idx) & jobs->q.elems[j_id - 1000].args_sz) > 0;
}

inline tpc_job_id_t tpc_jobs_acquire(tpc_jobs_t *jobs) {
	assert(jobs);
	tpc_job_id_t j_id = tpc_jobs_fsp_get(&jobs->q);
	if (j_id != INVALID_IDX) jobs->q.elems[j_id].state = TPC_JOB_STATE_REQUESTED;
	// printf("j_id = %u -> id = %d\n", j_id, j_id == INVALID_IDX ? -1 : jobs->q.elems[j_id].id);
	return j_id != INVALID_IDX ? jobs->q.elems[j_id].id : 0;
}

inline void tpc_jobs_release(tpc_jobs_t *jobs, tpc_job_id_t const j_id) {
	assert(jobs);
	jobs->q.elems[j_id - 1000].args_len = 0;
	jobs->q.elems[j_id - 1000].state = TPC_JOB_STATE_READY;
	tpc_jobs_fsp_put(&jobs->q, j_id - 1000);
}
