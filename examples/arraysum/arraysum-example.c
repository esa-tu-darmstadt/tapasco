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
//! @file	arraysum-example.c
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the arraysum kernel.
//!             Single-threaded variant.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <tapasco.h>
#include <assert.h>
#include "arraysum.h"

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
		fprintf(stderr, "fpga fatal error: %s\n", tapasco_strerror(result));
		exit(result);
	}
}

static void init_array(int *arr, size_t sz)
{
	for (size_t i = 0; i < sz; ++i)
		arr[i] = i;
}

int main(int argc, char **argv)
{
	int errs = 0;
	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	// check arraysum instance count
	printf("instance count: %d\n", tapasco_device_func_instance_count(dev, 10));
	assert(tapasco_device_func_instance_count(dev, 10));

	// init whole array to subsequent numbers
	int *arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(arr != NULL);
	init_array(arr, SZ * RUNS);

	for (int run = 0; run < RUNS; ++run) {
		int const golden = arraysum(&arr[run * SZ]);
		printf("Golden output for run %d: %d\n", run, golden);
		// allocate mem on device and copy array part
		tapasco_handle_t h;
		check_tapasco(tapasco_device_alloc(dev, &h, SZ * sizeof(int),
				TAPASCO_DEVICE_ALLOC_FLAGS_NONE));
		printf("h = 0x%08lx\n", (unsigned long)h);
		check(h != 0);
		check_tapasco(tapasco_device_copy_to(dev, &arr[SZ * run], h,
				SZ * sizeof(int), TAPASCO_DEVICE_COPY_BLOCKING));

		// get a job id and set argument to handle
		tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, 10,
				TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING);
		check(j_id > 0);
		check_tapasco(tapasco_device_job_set_arg(dev, j_id, 0, sizeof(h), &h));

		// shoot me to the moon!
		check_tapasco(tapasco_device_job_launch(dev, j_id,
				TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING));

		// get the result
		int32_t r = 0;
		check_tapasco(tapasco_device_job_get_return(dev, j_id, sizeof(r), &r));
		printf("FPGA output for run %d: %d\n", run, r);
		printf("\nRUN %d %s\n", run, r == golden ? "OK" : "NOT OK");
		tapasco_device_free(dev, h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
		tapasco_device_release_job_id(dev, j_id);
	}

	if (! errs) 
		printf("SUCCESS\n");
	else
		fprintf(stderr, "FAILURE\n");

	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	free(arr);
	return errs;
}
