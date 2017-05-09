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
//! @file 	tpc_jobs_test.c
//! @brief	Unit tests for jobs micro API implementations.
//! @authors 	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <check.h>
#include <tpc_jobs.h>
#include "tpc_jobs_test.h"

/* Acquires all job ids at once, and releases them again. */
START_TEST (tpc_jobs_acquire_all)
{
	int i;
	tpc_jobs_t *jobs = NULL;
	tpc_jobs_init(&jobs);

	tpc_job_id_t j_id[TPC_JOBS_Q_SZ];

	for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
		j_id[i] = tpc_jobs_acquire(jobs);
		fail_if(j_id[i] <= 0);
	}

	for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
		tpc_jobs_release(jobs, j_id[i]);
	}

	tpc_jobs_deinit(jobs);
}
END_TEST

/* Acquires a job id, sets all arguments, checks size and value (32/64bit). */
START_TEST (tpc_jobs_set_all_args)
{
	tpc_jobs_t *jobs = NULL;
	tpc_jobs_init(&jobs);

	tpc_job_id_t j_id = tpc_jobs_acquire(jobs);
	fail_if(j_id <= 0);

	printf("Acquired job id #%d, checking 32bit values ...\n", j_id);
	for (int i = 0; i < TPC_JOB_MAX_ARGS; ++i) {
		int32_t v = 42, o = 0;
		tpc_jobs_set_arg(jobs, j_id, i, sizeof(v), &v);
		fail_if(tpc_jobs_arg_count(jobs, j_id) != i + 1);
		o = tpc_jobs_get_arg32(jobs, j_id, i);
		printf("32bit, arg #%d: got value %d\n", i, o);
		fail_if(o != 42);
		fail_if(tpc_jobs_is_arg_64bit(jobs, j_id, i));
	}

	tpc_jobs_release(jobs, j_id);
	j_id = tpc_jobs_acquire(jobs);

	printf("Acquired job id #%d, checking 64bit values ...\n", j_id);
	for (int i = 0; i < TPC_JOB_MAX_ARGS; ++i) {
		int64_t v = INT64_MIN + 42, o = 0;
		tpc_jobs_set_arg(jobs, j_id, i, sizeof(v), &v);
		fail_if(tpc_jobs_arg_count(jobs, j_id) != i + 1);
		o = tpc_jobs_get_arg64(jobs, j_id, i);
		printf("64bit, arg #%d: got value %ld\n", i, o);
		fail_if(o != INT64_MIN + 42);
		fail_if(! tpc_jobs_is_arg_64bit(jobs, j_id, i));
	}

	tpc_jobs_release(jobs, j_id);
	tpc_jobs_deinit(jobs);
}
END_TEST

/* Acquires all job ids, sets and checks function id. */
START_TEST (tpc_jobs_set_func_ids)
{
	int i;
	tpc_jobs_t *jobs = NULL;
	tpc_jobs_init(&jobs);

	tpc_job_id_t j_id[TPC_JOBS_Q_SZ];
	for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
		j_id[i] = tpc_jobs_acquire(jobs);
		fail_if(j_id[i] <= 0);
		tpc_jobs_set_func_id(jobs, j_id[i], (tpc_func_id_t)(i % 10));
	}
	for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
		tpc_func_id_t f_id = tpc_jobs_get_func_id(jobs, j_id[i]);
		fail_if(f_id != (tpc_func_id_t)(i % 10));
		tpc_jobs_release(jobs, j_id[i]);
	}
	tpc_jobs_deinit(jobs);
}
END_TEST

/* Acquires all job ids, toggles job states. */
START_TEST (tpc_jobs_toggle_states)
{
	int i;
	tpc_job_state_t st;
	tpc_jobs_t *jobs = NULL;
	tpc_jobs_init(&jobs);

	tpc_job_id_t j_id[TPC_JOBS_Q_SZ];
	for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
		j_id[i] = tpc_jobs_acquire(jobs);
		fail_if(j_id[i] <= 0);
		st = tpc_jobs_get_state(jobs, j_id[i]);
		fail_if(st != TPC_JOB_STATE_REQUESTED);
	}
	for (st = TPC_JOB_STATE_READY; st <= TPC_JOB_STATE_FINISHED; ++st) {
		for (i = 0; i < TPC_JOBS_Q_SZ; ++i)
			tpc_jobs_set_state(jobs, j_id[i], st);
		for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
			tpc_job_state_t s = tpc_jobs_get_state(jobs, j_id[i]);
			fail_if(s != st);
		}
	}
	for (i = 0; i < TPC_JOBS_Q_SZ; ++i)
		tpc_jobs_release(jobs, j_id[i]);
	tpc_jobs_deinit(jobs);
}
END_TEST

/* Acquires all job ids, sets and checks return values (32/64). */
START_TEST (tpc_jobs_set_returns)
{
	int i;
	int64_t const v64 = INT64_MIN + 42;
	int32_t const v32 = INT32_MAX - 42;

	tpc_jobs_t *jobs = NULL;
	tpc_jobs_init(&jobs);

	tpc_job_id_t j_id[TPC_JOBS_Q_SZ];
	for (i = 0; i < TPC_JOBS_Q_SZ; ++i) {
		int32_t o32 = 0;
		int64_t o64 = 0;
		j_id[i] = tpc_jobs_acquire(jobs);
		fail_if(j_id[i] <= 0);

		fail_if(tpc_jobs_set_return(jobs, j_id[i], sizeof(v32), &v32) != TPC_SUCCESS);
		fail_if(tpc_jobs_get_return(jobs, j_id[i], sizeof(o32), &o32) != TPC_SUCCESS);
		fail_if(o32 != v32);

		fail_if(tpc_jobs_set_return(jobs, j_id[i], sizeof(v64), &v64) != TPC_SUCCESS);
		fail_if(tpc_jobs_get_return(jobs, j_id[i], sizeof(o64), &o64) != TPC_SUCCESS);
		fail_if(o64 != v64);
	}
	for (i = 0; i < TPC_JOBS_Q_SZ; ++i)
		tpc_jobs_release(jobs, j_id[i]);
	tpc_jobs_deinit(jobs);
}
END_TEST

TCase *jobs_testcase(void)
{
	TCase *tc_core = tcase_create("Core");

	tcase_add_test(tc_core, tpc_jobs_acquire_all);
	tcase_add_test(tc_core, tpc_jobs_set_all_args);
	tcase_add_test(tc_core, tpc_jobs_set_func_ids);
	tcase_add_test(tc_core, tpc_jobs_toggle_states);
	tcase_add_test(tc_core, tpc_jobs_set_returns);

	return tc_core;
}
