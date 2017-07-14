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
/**
 *  @file	tapasco_logging_benchmark.c
 *  @brief	Logging mechanism benchmark.
 *  		Starts a number of threads to produce random log messages as
 *  		fast as possible and report the average throughput.
 *  		Random data is preallocated in memory block to avoid L2 effects.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <errno.h>
#include <pthread.h>
#include <sys/time.h>

#include "tapasco.h"
#include "tapasco_logging_benchmark.h"
#include "tapasco_logging.h"

/* @{ globals */
static uint8_t *_rnd_data;
static volatile uint8_t *_curr_rnd;
static long _logs;
/* globals @} */

/* @{ random data */
/**
 * Fetches random data from /dev/urandom.
 * @param pp pointer to random data array
 * @param sz size of array
 * @return 0 on error
 **/
static int prepare_random_data(void **pp, size_t const sz)
{
	int rv = 1;
	*pp = malloc(sz);
	if (! *pp) return 0;
	FILE *fp = fopen("/dev/urandom", "r");
	if (! fp) return 0;
	rv = fread(*pp, 1, sz, fp) == sz;
	fclose(fp);
	_curr_rnd = _rnd_data;
	return rv;
}

/**
 * Copies random data from the global pool and advances global pointer.
 * @param p pointer to copy data to
 * @param sz size of data
 **/
static void get_random_data(void *p, size_t const sz)
{
	uint8_t *old, *new;
	do {
		old = (uint8_t *)_curr_rnd;
		new = old + sz < (_rnd_data + RANDOM_DATA_SZ) ?
				old + sz : _rnd_data;
	} while (! __atomic_compare_exchange(&_curr_rnd, &old, &new, false,
			__ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST) ||
			old + sz >= _rnd_data + RANDOM_DATA_SZ);
	memcpy(p, old, sz);
}
/* random data @} */

/* @{ random message generation */
static inline void log_random_message()
{
	tapasco_ll_t ll;		// make random log level
	char c;
	short int s;
	unsigned int u;
	float f;
	double d;
	tapasco_res_t r;
	long long unsigned int llu;
	long long int lld;

	get_random_data(&ll, sizeof(ll));
	ll = 2;
	get_random_data(&c, sizeof(c));
	c = 65 + c % 26; // ASCII A-Z
	get_random_data(&s, sizeof(s));
	get_random_data(&u, sizeof(u));
	f = 2.0007f;
	d = 42.42424242424242;
	get_random_data(&r, sizeof(r));
	get_random_data(&llu, sizeof(llu));
	llu = llu & 0xFFFFFFFFLLU;
	get_random_data(&lld, sizeof(lld));
	lld = lld & 0xFFFFFFFFLL;
	LOG(ll, "This is a random message: %c, %d, %u, %3.6f, d%3.2f, "
			"'%s', %llu, %lld",
			c, s, u, f, d, tapasco_strerror(r), llu, lld);
}
/* random message generation @} */

/* @{ thread main */
static void *thread_main(void *p)
{
	while(__atomic_sub_fetch(&_logs, 1, __ATOMIC_SEQ_CST) >= 0)
		log_random_message();
	return NULL;
}
/* thread main @} */

/* @{ run */
static void run(unsigned long const thrdcnt)
{
	pthread_t threads[thrdcnt];
	for (unsigned long i = 0; i < thrdcnt; ++i) {
		if (pthread_create(&threads[i], NULL, thread_main, NULL)) {
			fprintf(stderr, "ERROR: could not create thread: %s\n",
					strerror(errno));
			threads[i] = (pthread_t)0;
		}
	}
	for (unsigned long i = 0; i < thrdcnt; ++i)
		if((int)threads[i]) pthread_join(threads[i], NULL);
}
/* run @} */

/* @{ time difference */
inline struct timespec diff(struct timespec start, struct timespec end)
{
	struct timespec temp;
	if ((end.tv_nsec - start.tv_nsec) < 0) {
		temp.tv_sec = end.tv_sec - start.tv_sec - 1;
		temp.tv_nsec = 1000000000 + end.tv_nsec - start.tv_nsec;
	} else {
		temp.tv_sec = end.tv_sec - start.tv_sec;
		temp.tv_nsec = end.tv_nsec - start.tv_nsec;
	}
	return temp;
}
/* time difference @} */

/* @{ program usage */
static void print_usage(void)
{
	fprintf(stderr, "Usage: tapasco-logging-test [<NUM_THREADS> [<NUM_LOGS>]]\n"
			"where\n"
			"\t<NUM_THREADS> = number of thread (>= 1)\n"
			"\t<NUM_LOGS> = total number of log messages\n\n");
}
/* program usage @} */

/* @{ main */
int main(int argc, char *argv[])
{
	struct timespec tv_begin, tv_end, tv_diff;
	long thrdcnt = DEFAULT_THREADS;
	long long unsigned time_diff;
	long logs;
	_logs = DEFAULT_LOGS;
	if (argc > 1) thrdcnt = strtoul(argv[1], NULL, 0);
	if (errno) goto err_invalid_argument;

	if (argc > 2) _logs = strtoul(argv[2], NULL, 0);
	if (errno) goto err_invalid_argument;
	logs = _logs;

	printf("Starting logging benchmark with %ld threads for %ld messages.\n",
			thrdcnt, logs);
	printf("Preparing random data ... ");
	if (! prepare_random_data((void *)&_rnd_data, RANDOM_DATA_SZ))
		goto err_random_data;
	printf("done!\n");
	tapasco_logging_init();

	clock_getres(CLOCK_MONOTONIC_RAW, &tv_begin);
	printf("clock resolution: %ld, %ld\n", tv_begin.tv_sec, tv_begin.tv_nsec);

	clock_gettime(CLOCK_MONOTONIC_RAW, &tv_begin);
	run(thrdcnt);
	clock_gettime(CLOCK_MONOTONIC_RAW, &tv_end);
	tv_diff = diff(tv_begin, tv_end);
	time_diff = tv_diff.tv_sec * 1000000LLU + tv_diff.tv_nsec / 1000LLU;

	printf("Run took %3.4f ms for %lu log messages on %ld threads.\n",
			time_diff / 1000.0, logs, thrdcnt);
	printf("Average throughput: %10.1f logs/s\n", logs / (time_diff / 1000000.0));
	printf("Thread  throughput: %10.1f logs/s\n",
			logs / (time_diff / 1000000.0) / (double)thrdcnt);

	free(_rnd_data);
	printf("Finished the test.\n");
	tapasco_logging_exit();
	return EXIT_SUCCESS;

err_invalid_argument:
	fprintf(stderr, "Invalid argument: %s\n", strerror(errno));
	print_usage();
	goto err;
err_random_data:
	fprintf(stderr, "Could not prepare random data: %s\n",
			strerror(errno));
err:
	tapasco_logging_exit();
	exit(EXIT_FAILURE);
}
/* main @} */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
