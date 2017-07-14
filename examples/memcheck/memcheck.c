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
//! @file	memcheck-mt-ff.cc
//! @brief	Initializes the first TPC device and iterates over a number
//!  		of integer arrays of increasing size, allocating each array
//!  		on the device, copying to and from and then checking the
//!   		results. Basic regression test for platform implementations.
//!		Single-threaded variant.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <tapasco.h>

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;

static void check(int const result) {
	if (! result) {
		fprintf(stderr, "fatal error: %s\n", strerror(errno));
		exit(errno);
	}
}

static void check_fpga(tapasco_res_t const result) {
	if (result != TAPASCO_SUCCESS) {
		fprintf(stderr, "fpga fatal error: %s\n", tapasco_strerror(result));
		exit(result);
	}
}

void init_array(int *arr, size_t sz) {
	for (size_t i = 0; i < sz; ++i)
		arr[i] = i;
}

int compare_arrays(int const *arr, int const *rarr, size_t const sz) {
	int errs = 0;
	for (size_t i = 0; i < sz; ++i) {
		if (rarr[i] != arr[i]) {
			fprintf(stderr, "wrong data: arr[%zd] = %d != %d = rarr[%zd]\n",
					i, arr[i], rarr[i], i);
			++errs;
		}
	}
	return errs;
}

int main(int argc, char **argv) {
	int errs = 0;
	size_t arr_szs[] = { 1, 2, 8, 10, 16, 1024, 2048, 4096, 8192, 16384 };

	// initialize threadpool
	check_fpga(tapasco_init(&ctx));
	check_fpga(tapasco_create_device(ctx, 0, &dev, 0));

	for (int s = 0; s < sizeof(arr_szs) / sizeof(*arr_szs) && errs == 0; ++s) {
		printf("Checking array size %zd (%zd byte) ...\n",
				arr_szs[s], arr_szs[s] * sizeof(int));
		// allocate and fill array
		int *arr = (int *)malloc(arr_szs[s] * sizeof(int));
		check(arr != NULL);
		init_array(arr, arr_szs[s]);
		// allocate array for read data
		int *rarr = (int *)malloc(arr_szs[s] * sizeof(int));

		// get fpga handle
		tapasco_handle_t h;
		tapasco_device_alloc(dev, &h, arr_szs[s] * sizeof(int), 0);
		printf("handle = 0x%08lx\n", (unsigned long)h);
		check((unsigned long)h);

		// copy data to and back
		printf("sizeof(arr) %zd, sizeof(rarr) %zd\n", sizeof(arr), sizeof(rarr));
		check_fpga(tapasco_device_copy_to(dev, arr, h, arr_szs[s] * sizeof(int), 0));
		check_fpga(tapasco_device_copy_from(dev, h, rarr, arr_szs[s] * sizeof(int), 0));

		tapasco_device_free(dev, h, 0);

		int merr = compare_arrays(arr, rarr, arr_szs[s]);
		errs =+ merr;

		if (! merr)
			printf("Array size %zd (%zd byte) ok!\n",
					arr_szs[s], arr_szs[s] * sizeof(int));
		else
			fprintf(stderr, "FAILURE: array size %zd (%zd byte) not ok.\n",
					arr_szs[s], arr_szs[s] * sizeof(int));

		free(arr);
		free(rarr);
	}

	if (! errs)
		printf("\nSUCCESS\n");
	else
		fprintf(stderr, "\nFAILURE\n");

	// release device
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	return errs;
}
