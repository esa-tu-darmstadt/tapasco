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
//! @file	memcheck-mt.cc
//! @brief	Initializes the first TPC device and iterates over a number
//!  		of integer arrays of increasing size, allocating each array
//!  		on the device, copying to and from and then checking the
//!   		results. Basic regression test for platform implementations.
//!		Multi-threaded Pthreads variant.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include <assert.h>
#include <tapasco.h>

#define DEFAULT_RUNS					(1000)

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;
static long int errs;
static long int runs;
static size_t const arr_szs[] = { 1, 2, 8, 10, 16, 1024, 2048, 4096, 8192, 16384 };

static void check_fpga(tapasco_res_t const result)
{
	if (result != TAPASCO_SUCCESS) {
		fprintf(stderr, "fpga fatal error: %s\n", tapasco_strerror(result));
		exit(result);
	}
}

static void init_array(int *arr, size_t sz) {
	for (size_t i = 0; i < sz; ++i)
		arr[i] = i;
}

static int compare_arrays(long int const s, int const *arr, int const *rarr,
		size_t const sz, unsigned int const base)
{
	int errs = 0;
	for (size_t i = 0; i < sz; ++i) {
		if (rarr[i] != arr[i]) {
			unsigned int const addr = base + i * sizeof(int);
			fprintf(stderr, "%ld: wrong data: arr[%zd] = %d != %d "
					"= rarr[%zd]\terror at 0x%08x\n",
					s, i, arr[i], rarr[i], i, addr);
			++errs;
		}
	}
	return errs;
}

static void *test_thread(void *p)
{
	long const sc = sizeof(arr_szs) / sizeof(*arr_szs);
	long int s;
	while ((s = __atomic_sub_fetch(&runs, 1, __ATOMIC_SEQ_CST)) > 0) {
		s = s % sc;
		//printf("%ld: Checking array size %zd (%zd byte) ...\n",
		//		s, arr_szs[s], arr_szs[s] * sizeof(int));
		// allocate and fill array
		int *arr = (int *)malloc(arr_szs[s] * sizeof(int));
		assert(arr != NULL);
		init_array(arr, arr_szs[s]);
		// allocate array for read data
		int *rarr = (int *)malloc(arr_szs[s] * sizeof(int));
		assert(rarr != NULL);

		// get tapasco handle
		tapasco_handle_t h;
		tapasco_device_alloc(dev, &h, arr_szs[s] * sizeof(int), 0);
		// printf("%ld: handle = 0x%08lx, size = %zd bytes\n", s,
		//		(unsigned long)h, arr_szs[s] * sizeof(int));
		assert((unsigned long)h > 0);

		// copy data to and back
		int merr = 0;
		//printf("%ld: sizeof(arr) %zd, sizeof(rarr) %zd\n", s, sizeof(arr),
		//		sizeof(rarr));
		tapasco_res_t res = tapasco_device_copy_to(dev, arr, h,
				arr_szs[s] * sizeof(int),
				TAPASCO_DEVICE_COPY_BLOCKING);
		if (res == TAPASCO_SUCCESS) {
			// printf("%ld: copy to successful, copying from ...\n", s);
			res = tapasco_device_copy_from(dev, h, rarr,
					arr_szs[s] * sizeof(int),
					TAPASCO_DEVICE_COPY_BLOCKING);
			// printf("%ld: copy from finished\n", s);
			if (res == TAPASCO_SUCCESS) {
				merr += compare_arrays(s, arr, rarr, arr_szs[s], (unsigned int)h);
			} else {
				printf("%ld: Copy from device failed.\n", s);
				merr += 1;
			}
		} else {
			printf("%ld: Copy to device failed.\n", s);
			merr += 1;
		}
		__atomic_add_fetch(&errs, merr, __ATOMIC_SEQ_CST);
		tapasco_device_free(dev, h, 0);

		if (! merr)
			/*printf("%ld: Array size %zd (%zd byte) ok!\n",
					s, arr_szs[s], arr_szs[s] * sizeof(int));*/
			(void)0;
		else
			printf(/*stderr,*/ "%ld: FAILURE: array size %zd (%zd byte) not ok.\n",
					s, arr_szs[s], arr_szs[s] * sizeof(int));

		free(arr);
		free(rarr);
	}
	return NULL;
}

int main(int argc, char **argv) {
	if (argc < 2) {
		fprintf(stderr, "Usage: memcheck-mt <number of threads> [<number of transfers per thread>]\n");
		exit(EXIT_FAILURE);
	}
	long unsigned tc = strtoul(argv[1], NULL, 0);
	runs = DEFAULT_RUNS;
	if (argc > 2)
		runs = strtol(argv[2], NULL, 0);
	printf("Executing %ld transfers with %ld threads ...\n", runs, tc);
	setbuf(stdout, NULL);

	// initialize FPGA
	check_fpga(tapasco_init(&ctx));
	check_fpga(tapasco_create_device(ctx, 0, &dev, 0));

	printf("Starting %lu threads ...\n", tc);
	pthread_t *thrds = (pthread_t *)malloc(tc * sizeof(pthread_t));
	assert(thrds);
	errs = 0;

	for (long int s = 0; s < tc; ++s) {
		pthread_create(&thrds[s], NULL, test_thread, (void *)s);
	}
	for (long int s = 0; s < tc; ++s) {
		pthread_join(thrds[s], NULL);
	}

	if (! errs)
		printf("\nSUCCESS\n");
	else
		fprintf(stderr, "\nFAILURE\n");

	free(thrds);
	// release device
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	return errs;
}
