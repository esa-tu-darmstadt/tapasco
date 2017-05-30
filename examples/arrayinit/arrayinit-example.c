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
//! @file	arrayinit-example.c
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the arrayinit kernel.
//!             Single-threaded variant.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <tapasco.h>
#include <assert.h>
#include "arrayinit.h"

#define SZ							256
#define RUNS							25

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;

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
		arr[i] = -1;
}

static unsigned int check_array(int *arr, size_t sz)
{
	unsigned int errs = 0;
	for (size_t i = 0; i < sz; ++i) {
		if (arr[i] != i) {
			fprintf(stderr, "wrong data at %zd: %d\n", i, arr[i]);
			++errs;
		}
	}
	return errs;
}

int main(int argc, char **argv)
{
	int errs = 0;

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	// check arrayinit instance count
	printf("instance count: %d\n", tapasco_device_func_instance_count(dev, 11));
	assert(tapasco_device_func_instance_count(dev, 11));

	// init whole array to subsequent numbers
	int *arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(arr != NULL);
	init_array(arr, SZ * RUNS);

	for (int run = 0; run < RUNS; ++run) {
		// allocate mem on device and copy array part
		tapasco_handle_t h;
		check_tapasco(tapasco_device_alloc(dev, &h, SZ * sizeof(int), 0));
		check(h != 0);

		// get a job id and set argument to handle
		tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, 11,
				TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING);
		check(j_id > 0);
		check_tapasco(tapasco_device_job_set_arg(dev, j_id, 0, sizeof(h), &h));

		// shoot me to the moon!
		check_tapasco(tapasco_device_job_launch(dev, j_id,
				TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING));

		// get the result
		check_tapasco(tapasco_device_copy_from(dev, h, &arr[SZ * run],
				SZ * sizeof(int), TAPASCO_DEVICE_COPY_BLOCKING));
		unsigned int errs = check_array(&arr[SZ * run], SZ);
		printf("\nRUN %d %s\n", run, errs == 0 ? "OK" : "NOT OK");
		tapasco_device_free(dev, h, 0);
		tapasco_device_release_job_id(dev, j_id);
	}

	if (! errs) 
		printf("SUCCESS\n");
	else
		fprintf(stderr, "FAILURE\n");

	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	free(arr);
	return errs;
}
