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
//! @file	arrayupdate-example-mt.c
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the arrayupdate kernel.
//!             Multi-threaded Pthread variant.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <tapasco.h>
#include <assert.h>
#include <pthread.h>
#include "arrayupdate.h"

#define SZ							256
#define RUNS							25	

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;
static int *arr, *golden_arr;
static long runs = RUNS;

static void check(int const result)
{
	if (! result) {
		fprintf(stderr, "fatal error: %s\n", strerror(errno));
		exit(errno);
	}
}

static void check_tapasco(tapasco_res_t const result)
{
	if (result != TAPASCO_SUCCESS) {
		fprintf(stderr, "tapasco fatal error: %s\n", tapasco_strerror(result));
		exit(result);
	}
}

static void init_array(int *arr, size_t sz)
{
	for (size_t i = 0; i < sz; ++i)
		arr[i] = i + 1;
}

static unsigned int check_arrays(int *arr, int *golden_arr, size_t sz)
{
	unsigned int errs = 0;
	for (size_t i = 0; i < sz; ++i) {
		if (arr[i] != golden_arr[i]) {
			fprintf(stderr, "wrong data at %zd: %d, should be %d\n",
					i, arr[i], golden_arr[i]);
			++errs;
		}
	}
	return errs;
}

static void *runTest(void *p) {
	long run;
	unsigned int errs = 0;
	while ((run = __sync_sub_and_fetch(&runs, 1)) > 0) {
		// golden run
		arrayupdate(&golden_arr[SZ * run]);

		// allocate mem on device and copy array part
		tapasco_handle_t h;
		tapasco_device_alloc(dev, &h, SZ * sizeof(int), 0);
		check(h != 0);
		check_tapasco(tapasco_device_copy_to(dev, &arr[SZ * run], h,
				SZ * sizeof(int), TAPASCO_DEVICE_COPY_BLOCKING));

		// get a job id and set argument to handle
		tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, 12,
				TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING);
		printf("run %ld: j_id = %d\n", run, j_id);
		check(j_id > 0);
		check_tapasco(tapasco_device_job_set_arg(dev, j_id, 0, sizeof(h), &h));

		// shoot me to the moon!
		check_tapasco(tapasco_device_job_launch(dev, j_id,
				TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING));

		// get the result
		int32_t r = 0;
		check_tapasco(tapasco_device_job_get_return(dev, j_id, sizeof(r), &r));
		check_tapasco(tapasco_device_copy_from(dev, h, &arr[SZ * run],
				SZ * sizeof(int), 0));
		printf("TPC output for run %ld: %d\n", run, r);
		errs += check_arrays(&arr[SZ * run], &golden_arr[SZ * run], SZ);
		printf("\nRUN %ld %s\n", run, errs == 0 ?  "OK" : "NOT OK");
		tapasco_device_free(dev, h, 0);
		tapasco_device_release_job_id(dev, j_id);
	}
	return errs == 0 ? 0 : (void *)1;
}

int main(int argc, char **argv) {
	int errs = 0;

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	// check arrayupdate instance count
	printf("instance count: %d\n", tapasco_device_func_instance_count(dev, 12));
	assert(tapasco_device_func_instance_count(dev, 12));

	// init whole array to subsequent numbers
	arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(arr != NULL);
	init_array(arr, SZ * RUNS);

	golden_arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(golden_arr != NULL);
	init_array(golden_arr, SZ * RUNS);

	// init pthreads
	pthread_t threads[sysconf(_SC_NPROCESSORS_CONF)];

	for (long int run = 0; run < sysconf(_SC_NPROCESSORS_CONF); ++run) {
		pthread_create(&threads[run], NULL, runTest, (void *)run);
	}

	for (int run = 0; run < sysconf(_SC_NPROCESSORS_CONF); ++run) {
		void *p;
		pthread_join(threads[run], &p);
		errs += (long int)p;
	}

	if (! errs) 
		printf("SUCCESS\n");
	else
		fprintf(stderr, "FAILURE\n");

	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	free(golden_arr);
	free(arr);
	return errs;
}
