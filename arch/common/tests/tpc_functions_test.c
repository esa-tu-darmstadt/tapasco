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
//! @file	tpc_functions_test.c
//! @brief	Unit tests for functions micro API implementation.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <check.h>
#include <pthread.h>
#include <unistd.h>
#include <sched.h>
#include <tpc_functions.h>
#include "tpc_functions_test.h"

extern tpc_res_t tpc_status_set_id(int idx, tpc_func_id_t id);

/* Fakes a composition consisting of ascending function ids. */
static inline void composition_asc(void)
{
	for (int i = 0; i < TPC_MAX_INSTANCES; ++i)
		tpc_status_set_id(i, i+1);
}

/* Checks the function counting. */
START_TEST (tpc_functions_check_counts)
{
	composition_asc();

	tpc_functions_t *funcs = NULL;
	tpc_functions_init(&funcs);

	for (int i = 0; i < TPC_MAX_INSTANCES; ++i) {
		fail_if (tpc_functions_count(funcs, i + 1) != 1);
		tpc_func_slot_id_t slot_id = tpc_functions_acquire(funcs, i + 1);
		printf("f_id = %d -> slot_id = %d\n", i + 1, slot_id);
		fail_if (slot_id < 0);
		tpc_func_slot_id_t unavail = tpc_functions_acquire(funcs, i + 1);
		fail_if (unavail >= 0);
		tpc_functions_release(funcs, slot_id);
	}
	
	tpc_functions_deinit(funcs);
}
END_TEST

/* Acquire a random function id a hundred times and release. */
static void *run(void *fp)
{
	tpc_functions_t *funcs = (tpc_functions_t *)fp;
	for (int i = 0; i < 100; ++i) {
		tpc_func_id_t const f_id = (rand() % TPC_MAX_INSTANCES) + 1;
		tpc_func_slot_id_t slot_id;
		do {
			slot_id = tpc_functions_acquire(funcs, f_id);
			sched_yield();
		} while (slot_id < 0);
		tpc_functions_release(funcs, slot_id);
	}
	return NULL;
}

/* Spawns as many threads as host has cores, each starting run. */
START_TEST (tpc_functions_mt)
{
	size_t const nprocs = sysconf(_SC_NPROCESSORS_CONF);
	composition_asc();


	tpc_functions_t *funcs = NULL;
	tpc_functions_init(&funcs);

	pthread_t *threads = malloc(sizeof(pthread_t *) * nprocs);
	fail_if(! threads);

	printf("starting %zd threads ...\n", nprocs);
	for (int i = 0; i < nprocs; ++i)
		fail_if (pthread_create(&threads[i], NULL, run, funcs));

	// join all threads
	for (int i = 0; i < nprocs; ++i)
		fail_if (pthread_join(threads[i], NULL));

	free(threads);
	tpc_functions_deinit(funcs);
}
END_TEST

TCase *functions_testcase(void)
{
	TCase *tc_core = tcase_create("Functions");
	tcase_add_test(tc_core, tpc_functions_check_counts);
	tcase_add_test(tc_core, tpc_functions_mt);
	return tc_core;
}
