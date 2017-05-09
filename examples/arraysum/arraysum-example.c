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
#include <tpc_api.h>
#include <assert.h>
#include "arraysum.h"

#define SZ							256
#define RUNS							25

static tpc_ctx_t *ctx;
static tpc_dev_ctx_t *dev;

static void check(int const result)
{
	if (! result) {
		fprintf(stderr, "fatal error: %s\n", strerror(errno));
		exit(errno);
	}
}

static void check_tpc(tpc_res_t const result)
{
	if (result != TPC_SUCCESS) {
		fprintf(stderr, "fpga fatal error: %s\n", tpc_strerror(result));
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
	check_tpc(tpc_init(&ctx));
	check_tpc(tpc_create_device(ctx, 0, &dev, 0));
	// check arraysum instance count
	printf("instance count: %d\n", tpc_device_func_instance_count(dev, 10));
	assert(tpc_device_func_instance_count(dev, 10));

	// init whole array to subsequent numbers
	int *arr = (int *)malloc(SZ * RUNS * sizeof(int));
	check(arr != NULL);
	init_array(arr, SZ * RUNS);

	for (int run = 0; run < RUNS; ++run) {
		int const golden = arraysum(&arr[run * SZ]);
		printf("Golden output for run %d: %d\n", run, golden);
		// allocate mem on device and copy array part
		tpc_handle_t h;
		check_tpc(tpc_device_alloc(dev, &h, SZ * sizeof(int),
				TPC_DEVICE_ALLOC_FLAGS_NONE));
		printf("h = 0x%08lx\n", (unsigned long)h);
		check(h != 0);
		check_tpc(tpc_device_copy_to(dev, &arr[SZ * run], h,
				SZ * sizeof(int), TPC_DEVICE_COPY_BLOCKING));

		// get a job id and set argument to handle
		tpc_job_id_t j_id = tpc_device_acquire_job_id(dev, 10,
				TPC_DEVICE_ACQUIRE_JOB_ID_BLOCKING);
		check(j_id > 0);
		check_tpc(tpc_device_job_set_arg(dev, j_id, 0, sizeof(h), &h));

		// shoot me to the moon!
		check_tpc(tpc_device_job_launch(dev, j_id,
				TPC_DEVICE_JOB_LAUNCH_BLOCKING));

		// get the result
		int32_t r = 0;
		check_tpc(tpc_device_job_get_return(dev, j_id, sizeof(r), &r));
		printf("FPGA output for run %d: %d\n", run, r);
		printf("\nRUN %d %s\n", run, r == golden ? "OK" : "NOT OK");
		tpc_device_free(dev, h, TPC_DEVICE_ALLOC_FLAGS_NONE);
		tpc_device_release_job_id(dev, j_id);
	}

	if (! errs) 
		printf("SUCCESS\n");
	else
		fprintf(stderr, "FAILURE\n");

	tpc_destroy_device(ctx, dev);
	tpc_deinit(ctx);
	free(arr);
	return errs;
}
