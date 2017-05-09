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
//! @file	tpc_jobs.h
//! @brief	Defines a micro API for threadpool job management.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TPC_API_JOBS_H__
#define __TPC_API_JOBS_H__

#ifdef __cplusplus
	#include <cstdint>
	#include <cstdlib>
	#include <cstring>
	#include <cassert>
#else
	#include <stdint.h>
	#include <stdlib.h>
	#include <string.h>
	#include <assert.h>
#endif

#include <tpc_api.h>
#include "tpc_errors.h"

#define TPC_JOBS_Q_SZ						250
#define	TPC_JOB_MAX_ARGS					32

#ifdef __cplusplus
namespace rpr { namespace tpc { extern "C" {
#endif

/** @defgroup common_job common: job struct
 *  @{
 */
/** Possible states of a job. **/
typedef enum {
	/** job is available **/
	TPC_JOB_STATE_READY				= 0,
  	/** job id has been acquired, but not yet scheduled; accepts args in this state **/
	TPC_JOB_STATE_REQUESTED,
	/** job has been scheduled and is awaiting execution, no more changes in this state **/
	TPC_JOB_STATE_SCHEDULED,
	/** job is currently executing, no more changes in this state, return value instable **/
	TPC_JOB_STATE_RUNNING,
	/** job has finished, return value is valid **/
	TPC_JOB_STATE_FINISHED,
} tpc_job_state_t;

/**
 * Internal job structure to maintain information on an execution to be 
 * scheduled some time in the future.
 **/
typedef struct tpc_jobs tpc_jobs_t;

/** Initializes the internal jobs struct. */
tpc_res_t tpc_jobs_init(tpc_jobs_t **jobs);

/** Releases internal jobs struct and associated memory. */
void tpc_jobs_deinit(tpc_jobs_t *jobs);

/**
 * Returns the function id (== kernel id) for the given job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @return function id of the function this job shall run at.
 **/
tpc_func_id_t tpc_jobs_get_func_id(tpc_jobs_t const *jobs, tpc_job_id_t const j_id);

/**
 * Sets the function id (== kernel id for the given job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param f_id function id.
 **/
void tpc_jobs_set_func_id(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		tpc_func_id_t const f_id);

/**
 * Returns the current state of the given job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @return state of the job, see @tpc_job_state_t.
 **/
tpc_job_state_t tpc_jobs_get_state(tpc_jobs_t const *jobs,
		tpc_job_id_t const j_id);

/**
 * Sets the current state of the given job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param new_state state to set.
 * @return old state.
 **/
tpc_job_state_t tpc_jobs_set_state(tpc_jobs_t *jobs,
		tpc_job_id_t const j_id,
		tpc_job_state_t const new_state);

/**
 * Returns the return value(s) of job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param ret_len number of bytes to copy.
 * @param ret_value pointer to pre-allocated memory to copy data to.
 * @return TPC_SUCCESS, if return values could be copied and are valid.
 **/
tpc_res_t tpc_jobs_get_return(tpc_jobs_t const *jobs,
		tpc_job_id_t const j_id, size_t const ret_len,
		void *ret_value);

/**
 * Returns the number of currently prepared arguments in the given job.
 * @param jobs jobs context.
 * @parma j_id job id.
 * @return number of arguments that have been set.
 **/
uint32_t tpc_jobs_arg_count(tpc_jobs_t const *jobs, tpc_job_id_t const j_id);

/**
 * Returns the 32-bit value of an argument.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param arg_idx index of the argument to retrieve.
 * @return value as 32-bit unsigned integer.
 **/
uint32_t tpc_jobs_get_arg32(tpc_jobs_t const *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx);

/**
 * Returns the 64-bit value of an argument.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param arg_idx index of the argument to retrieve.
 * @return value as 64-bit unsigned integer.
 **/
uint64_t tpc_jobs_get_arg64(tpc_jobs_t const *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx);

/**
 * Returns the value of an argument in a job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param arg_idx index of the argument to retrieve.
 * @param arg_len size of argument in bytes.
 * @param arg_value pointer to value data.
 * @return TPC_SUCCESS, if value could be set.
 **/
tpc_res_t tpc_jobs_get_arg(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx, size_t const arg_len,
		void *arg_value);

/**
 * Sets the value of an argument in a job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param arg_idx index of the argument to retrieve.
 * @param arg_len size of argument in bytes.
 * @param arg_value pointer to value data.
 * @return TPC_SUCCESS, if value could be set.
 **/
tpc_res_t tpc_jobs_set_arg(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx, size_t const arg_len,
		void const *arg_value);

/**
 * Sets the return value of a job.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param ret_len size of return value in bytes.
 * @param ret_value pointer to return value data.
 * @return TPC_SUCCESS, if value could be set.
 **/
tpc_res_t tpc_jobs_set_return(tpc_jobs_t *jobs, tpc_job_id_t const j_id,
		size_t const ret_len, void const *ret_value);

/**
 * Helper: Returns true if the given argument is 64-bit value.
 * @param jobs jobs context.
 * @param j_id job id.
 * @param arg_idx index of the argument.
 * @return value != 0 if argument is 64bit, 0 otherwise.
 **/
int tpc_jobs_is_arg_64bit(tpc_jobs_t const *jobs, tpc_job_id_t const j_id,
		uint32_t const arg_idx);

/**
 * Reserves a job id for preparation.
 * @param jobs jobs context.
 * @return job id.
 **/
tpc_job_id_t tpc_jobs_acquire(tpc_jobs_t *jobs);

/**
 * Releases a previously acquired job id for re-use.
 * @param jobs jobs context.
 * @param j_id job id.
 **/
void tpc_jobs_release(tpc_jobs_t *jobs, tpc_job_id_t const j_id);

#ifdef __cplusplus
} /* extern "C" */ } /* namespace tpc */ } /* namespace rpr */
#endif

#endif /* __TPC_API_JOBS_H__ */


