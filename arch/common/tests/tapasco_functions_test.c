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
//! @file	tapasco_functions_test.c
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
#include <tapasco_functions.h>
#include "tapasco_functions_test.h"

extern tapasco_res_t tapasco_status_set_id(int idx, tapasco_func_id_t id);

/* Fakes a composition consisting of ascending function ids. */
static inline void composition_asc(void)
{
	for (int i = 0; i < TAPASCO_MAX_INSTANCES; ++i)
		tapasco_status_set_id(i, i+1);
}

/* Checks the function counting. */
START_TEST (tapasco_functions_check_counts)
{
	composition_asc();

	tapasco_functions_t *funcs = NULL;
	tapasco_functions_init(&funcs);

	for (int i = 0; i < TAPASCO_MAX_INSTANCES; ++i) {
		fail_if (tapasco_functions_count(funcs, i + 1) != 1);
		tapasco_func_slot_id_t slot_id = tapasco_functions_acquire(funcs, i + 1);
		printf("f_id = %d -> slot_id = %d\n", i + 1, slot_id);
		fail_if (slot_id < 0);
		tapasco_func_slot_id_t unavail = tapasco_functions_acquire(funcs, i + 1);
		fail_if (unavail >= 0);
		tapasco_functions_release(funcs, slot_id);
	}

	tapasco_functions_deinit(funcs);
}
END_TEST

/* Acquire a random function id a hundred times and release. */
static void *run(void *fp)
{
	tapasco_functions_t *funcs = (tapasco_functions_t *)fp;
	for (int i = 0; i < 100; ++i) {
		tapasco_func_id_t const f_id = (rand() % TAPASCO_MAX_INSTANCES) + 1;
		tapasco_func_slot_id_t slot_id;
		do {
			slot_id = tapasco_functions_acquire(funcs, f_id);
			sched_yield();
		} while (slot_id < 0);
		tapasco_functions_release(funcs, slot_id);
	}
	return NULL;
}

/* Spawns as many threads as host has cores, each starting run. */
START_TEST (tapasco_functions_mt)
{
	size_t const nprocs = sysconf(_SC_NPROCESSORS_CONF);
	composition_asc();


	tapasco_functions_t *funcs = NULL;
	tapasco_functions_init(&funcs);

	pthread_t *threads = malloc(sizeof(pthread_t *) * nprocs);
	fail_if(! threads);

	printf("starting %zd threads ...\n", nprocs);
	for (int i = 0; i < nprocs; ++i)
		fail_if (pthread_create(&threads[i], NULL, run, funcs));

	// join all threads
	for (int i = 0; i < nprocs; ++i)
		fail_if (pthread_join(threads[i], NULL));

	free(threads);
	tapasco_functions_deinit(funcs);
}
END_TEST

TCase *functions_testcase(void)
{
	TCase *tc_core = tcase_create("Functions");
	tcase_add_test(tc_core, tapasco_functions_check_counts);
	tcase_add_test(tc_core, tapasco_functions_mt);
	return tc_core;
}
