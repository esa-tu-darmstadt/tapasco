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
//! @file	platform_stress_alloc.c
//! @brief	Platform API based stress test for memory allocation / deallocation:
//!		Configurable number of threads allocates randomly sized device mem,
//!		holds it for a random time < 1ms, and finally frees it.
//!		Each thread performs a configurable number of iteration (def: 1000).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <pthread.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>

#include <platform.h>
#include "common.h"

#define LOWER_BND					(2)
#define UPPER_BND					(20)

static long stop = 0;
static unsigned long mode = 0;

static inline int check_transfer(platform_mem_addr_t const addr, size_t const sz)
{
	int fd, result;
	size_t rd;
	ssize_t res;
	void *rnddata = malloc(sz);
	void *resdata = malloc(sz);
	char *p;
	if (rnddata == NULL || resdata == NULL) {
		fprintf(stderr, "FATAL: out of memory\n");
		return 0;
	}
	fd = open("/dev/urandom", O_RDONLY);
	if (fd == -1) {
		fprintf(stderr, "FATAL: could not open /dev/urandom: %s", strerror(errno));
		free(rnddata);
		return 0;
	}
	rd = sz;
	p = (char *)rnddata;
	do {
		res = read(fd, p, rd);
		if (res >= 0) {
			rd -= res;
			p += res;
		}
	} while (! stop && rd > 0 && res >= 0);
	close(fd);

	platform_write_mem(addr, sz, rnddata, PLATFORM_MEM_FLAGS_NONE);
	platform_read_mem(addr, sz, resdata, PLATFORM_MEM_FLAGS_NONE);

	result = memcmp(resdata, rnddata, sz) == 0;

	free(resdata);
	free(rnddata);
	return result;
}

static void *stress(void *p)
{
	unsigned long runs = (unsigned long)p;
	platform_mem_addr_t addr;
	platform_res_t res;
	while (runs && ! stop) {
		size_t const sz = pow(2, LOWER_BND + rand() % (UPPER_BND - LOWER_BND));
		res = platform_alloc(sz, &addr, PLATFORM_ALLOC_FLAGS_NONE);
		if (! check(res)) {
			stop = 1;
			fprintf(stderr, "error during allocation of size %zu bytes: %s\n",
					sz, platform_strerror(res));
			return NULL;
		}
		/* if mode > 0, actual data is copied and checked */
		if (mode) {
			if (! check_transfer(addr, sz)) {
				stop = 1;
				fprintf(stderr, "data corrupted, transfer of %zu bytes failed\n", sz);
				return NULL;
			}
		} else {
			usleep(rand() % 1000); /* just sleep a while */
		}
		res = platform_dealloc(addr, PLATFORM_ALLOC_FLAGS_NONE);
		if (! check(res)) {
			stop = 1;
			fprintf(stderr, "error during release of size %zu bytes: %s\n",
					sz, platform_strerror(res));
			return NULL;
		}
		--runs;
	}
	return NULL;
}

static inline void print_usage_and_exit(void)
{
	printf("Usage: platform-stress-alloc [<threads>] [<iterations>] [<mode>]\n"
			"\t<threads>   : number of threads to use\n"
			"\t<iterations>: number of iterations per thread\n"
			"\t<mode>      : 0 == random usleep, 1 == actual copy & compare\n\n");
	exit(EXIT_SUCCESS);
}

int main(int argc, char **argv)
{
	if (argc == 2 && strcmp("-h", argv[1]) == 0)
		print_usage_and_exit();
	int t;
	long const thread_count = argc > 1 ? strtol(argv[1], NULL, 0) : sysconf(_SC_NPROCESSORS_CONF);
	unsigned long const runs = argc > 2 ? strtoul(argv[2], NULL, 0) : 10000;
	mode = argc > 3 ? strtoul(argv[3], NULL, 0) : 0;
	pthread_t threads[thread_count];

	srand(time(NULL));
	if (!check(platform_init()))
		exit(EXIT_FAILURE);

	printf("Starting %ld threads with %lu runs each, mode = %lu...\n", thread_count, runs, mode);
	for (t = 0; t < thread_count; ++t)
		pthread_create(&threads[t], NULL, stress, (void *)runs);
	for (t = 0; t < thread_count; ++t)
		pthread_join(threads[t], NULL);

	platform_deinit();

	if (! stop)
		printf("Test successful.\n");
	else
		fprintf(stderr, "Test failed!\n");
	return stop ? EXIT_FAILURE : EXIT_SUCCESS;
}
