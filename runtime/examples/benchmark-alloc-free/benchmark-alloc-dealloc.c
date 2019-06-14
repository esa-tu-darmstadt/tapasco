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
//! @file	benchmark-mem.c
//! @brief	TPC API application that performs a simplistic benchmark on the
//!		implementation: It allocates memory as fast as possible in chunk
//!		sizes ranging from 2^12 (== 4KiB) to 2^26 (== 64MiB) with one
//!		thread per core.
//!		The program output can be used for the gnuplot script in this
//!		directory to generate a bar plot.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include <tapasco.h>
#include "timer.h"

#define ALLOCATION_COUNT			(1000)
#define UPPER_BND				(26)
#define LOWER_BND				(12)

typedef unsigned long int ul;
typedef long int l;

static ul   chunk_sz;
static l    allocations;
static ul   errors;
static l    mode;

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;

static inline void alloc_dealloc(size_t const sz)
{
	void *ptr = malloc(sz);
	if (! ptr)
		__sync_fetch_and_add(&errors, 1);
	free(ptr);
}

static inline void tapasco_alloc_dealloc(size_t const sz)
{
	tapasco_handle_t h;
	tapasco_device_alloc(dev, &h, sz, 0);
	if (h <= 0)
		__sync_fetch_and_add(&errors, 1);
	else
		tapasco_device_free(dev, h, 0);
}

static void *run(void *p)
{
	size_t const sz = (size_t)p;
	while (! errors && __sync_sub_and_fetch(&allocations, 1) > 0) {
		if (mode)
			tapasco_alloc_dealloc(sz);
		else
			alloc_dealloc(sz);
	}
	return NULL;
}

static void print_header(void)
{
	printf("Allocation Size (KiB),virt. mem (alloc+dealloc/s),DMA mem (alloc+dealloc/s)\n");
}

static void print_line(ul const *times)
{
	printf("%lu,%3.2f,%3.2f\n", chunk_sz / 1024,
			ALLOCATION_COUNT / (times[0] / 1000000.0),
			ALLOCATION_COUNT / (times[1] / 1000000.0));
}

static void check_tapasco(tapasco_res_t const result)
{
	if (result != TAPASCO_SUCCESS) {
		fprintf(stderr, "tapasco fatal error: %s\n", tapasco_strerror(result));
		exit(result);
	}
}

int main(int argc, char **argv)
{
	int pw, i;
	pthread_t threads[sysconf(_SC_NPROCESSORS_CONF)];
	ul times[2] = { 0 };

	// init timer and data
	TIMER_INIT();

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));

	print_header();
	TIMER_START(total)
	for (pw = UPPER_BND; pw >= LOWER_BND; --pw) {
		chunk_sz = (size_t)(pow(2, pw));
		for (mode = 0; mode < 2; ++mode) {
			allocations = ALLOCATION_COUNT;
			errors = 0;
			TIMER_START(run)
			for (i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
				pthread_create(&threads[i], NULL, run, (void *)chunk_sz);
			for (i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
				pthread_join(threads[i], NULL);
			TIMER_STOP(run)
			// fprintf(stderr, "\nerrors = %lu\n", errors);
			times[mode] = errors ? 0 : TIMER_USECS(run);
		}
		print_line(times);
	}
	TIMER_STOP(total)
	fprintf(stderr, "Total duration: %llu us.\n", TIMER_USECS(total));
	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
}
