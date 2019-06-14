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
//!		memory system: 1GiB of data is transferred in chunks of sizes 
//!		ranging from 2^12 (== 4KiB) to 2^26 (== 64MiB) with one thread
//!		per processor. Each thread performs alloc-copy-dealloc until all
//!		transfers are finished; this is done in three modes read, write
//!		and read+write (data is either only copied from, copied to or
//!		copied in both directions).
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

#define TRANSFER_SZ				((size_t)(1024*1024*1024))
#define UPPER_BND				(26)
#define LOWER_BND				(12)

typedef unsigned long int ul;
typedef long int l;

static void *rnddata;
static ul   chunk_sz;
static l    transfers;
static ul   errors;
static l    mode;

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;

static void fill_with_random(void *d, size_t const sz)
{
	FILE *f;
	//size_t c;
	TIMER_START(fill_with_random);
	f = fopen("/dev/urandom", "r");
	assert(f);
	//c = fread(d, sizeof(char), sz, f);
	//assert(c == sz);
	fclose(f);
	TIMER_STOP(fill_with_random);
	fprintf(stderr, "fill_with_random took %llu us.\n",
			TIMER_USECS(fill_with_random));
}

static inline void baseline_transfer(void *d)
{
	void *h;
	if (! d) {
		__sync_fetch_and_add(&errors, 1);
		return;
	}
	h = malloc(chunk_sz);
	if (! h) {
		__sync_fetch_and_add(&errors, 1);
		return;
	}

	switch (mode) {
	case 0:	/* read-only */
		memcpy(h, d, chunk_sz);
		break;
	case 1: /* write-only */
		memcpy(d, h, chunk_sz);
		break;
	case 2: /* read-write */
		memcpy(d, h, chunk_sz);
		memcpy(h, d, chunk_sz);
		break;
	}
	free(h);
}

static inline void tapasco_transfer(void *d)
{
	tapasco_handle_t h;
	if (! d) {
		__sync_fetch_and_add(&errors, 1);
		return;
	}
	if (tapasco_device_alloc(dev, &h, chunk_sz, 0) != TAPASCO_SUCCESS) {
		__sync_fetch_and_add(&errors, 1);
		return;
	}

	switch (mode - 3) {
	case 0:	/* read-only */
		tapasco_device_copy_from(dev, h, d, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
		break;
	case 1: /* write-only */
		tapasco_device_copy_to(dev, d, h, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
		break;
	case 2: /* read-write */
		tapasco_device_copy_to(dev, d, h, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
		tapasco_device_copy_from(dev, h, d, chunk_sz, TAPASCO_DEVICE_COPY_BLOCKING);
		break;
	}
	tapasco_device_free(dev, h, 0);
}

static void *transfer(void *p)
{
	void *d = malloc(chunk_sz);
	while (__sync_fetch_and_sub(&transfers, 1) > 0) {
		if (mode < 3)
			baseline_transfer(d);
		else
			tapasco_transfer(d);
	}
	free (d);
	return NULL;
}

static void print_header(void)
{
	printf("Allocation Size (KiB),virt. R (MiB/s),virt. W (MiB/s),virt. R+W (MiB/s),DMA R (MiB/s),DMA W (MiB/s),DMA R+W (MiB/s)\n");
}

static void print_line(ul const *times)
{
	printf("%lu,%3.2f,%3.2f,%3.2f,%3.2f,%3.2f,%3.2f\n", chunk_sz / 1024,
			(TRANSFER_SZ/(1024*1024)) / (times[0] / 1000000.0),
			(TRANSFER_SZ/(1024*1024)) / (times[1] / 1000000.0),
			(TRANSFER_SZ/(1024*1024)) / (times[2] / 1000000.0),
			(TRANSFER_SZ/(1024*1024)) / (times[3] / 1000000.0),
			(TRANSFER_SZ/(1024*1024)) / (times[4] / 1000000.0),
			(TRANSFER_SZ/(1024*1024)) / (times[5] / 1000000.0));
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
	ul times[6] = { 0 };

	// init timer and data
	TIMER_INIT();
	rnddata = malloc(pow(2, UPPER_BND));
	fill_with_random(rnddata, pow(2, UPPER_BND));

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));

	print_header();
	TIMER_START(total)
	for (pw = UPPER_BND; pw >= LOWER_BND; --pw) {
		chunk_sz = (size_t)(pow(2, pw));
		for (mode = 0; mode <= 5; ++mode) {
			transfers = TRANSFER_SZ / chunk_sz;
			errors = 0;
			TIMER_START(run)
			for (i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
				pthread_create(&threads[i], NULL, transfer, NULL);
			for (i = 0; i < sysconf(_SC_NPROCESSORS_CONF); ++i)
				pthread_join(threads[i], NULL);
			TIMER_STOP(run)
			// fprintf(stderr, "\nerrors = %lu\n", errors);
			times[mode] = errors ? 0 : TIMER_USECS(run);
			if (mode % 3 == 2) times[mode] /= 2;
		}
		print_line(times);
	}
	TIMER_STOP(total)
	fprintf(stderr, "Total duration: %llu us.\n", TIMER_USECS(total));
	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
	free(rnddata);
}
