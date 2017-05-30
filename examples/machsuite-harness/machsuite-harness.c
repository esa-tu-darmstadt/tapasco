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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <assert.h>
#include <fcntl.h>
#include <tapasco.h>
#include "../benchmark-mem/timer.h"
#include "machsuite-harness.h"

#define MACH_ID						(13138)
#define DEFAULT_ITERATIONS				(1000)

#define	MIN_NSECS					(10000)
#define MAX_NSECS					(1000000)
#define NSTEPS						(15)
#define JOBS						(1000)

static void *input_data, *golden;

static long iterations;
static long jobs;
static long errors;
static long mode;

static tapasco_ctx_t *ctx;
static tapasco_dev_ctx_t *dev;

static inline void check_tapasco(tapasco_res_t const result)
{
	if (result != TAPASCO_SUCCESS) {
		fprintf(stderr, "tapasco fatal error: %s\n", tapasco_strerror(result));
		exit(result);
	}
}

static inline double clock_period(void)
{
	static double period = 0.0;
	if (period == 0.0) {
		unsigned long hz;
		char buf[1024] = "";
		ssize_t rc;
		int fd = open("/sys/class/fclk/fclk0/set_rate", O_RDONLY);
		assert(fd);
		rc = read(fd, buf, 1023);
		assert(rc);
		fprintf(stderr, "fclk/set_rate = %s", buf);
		close(fd);
		hz = strtoul(buf, NULL, 0);
		period = 1.0 / (hz / 1000000000.0);
		fprintf(stderr, "period = %3.2f ns\n", period);
	}
	return period;
}

static void dump(tapasco_job_id_t const j_id, void *d)
{
	static int dumps = 0;
	char buf[1024] = "";
	FILE *fp;
	snprintf(buf, 1024, "wrong_data_job_%u_%d", j_id, dumps++);
	fp = fopen(buf, "w+");
	assert(fp);
	fwrite(d, INPUT_SIZE, 1, fp);
	fclose(fp);
}

static inline void tapasco_run(void)
{
	tapasco_res_t r;
	void *d = malloc(INPUT_SIZE);
	assert(d && "out of memory: tapasco_run");
	tapasco_handle_t h = tapasco_device_alloc(dev, INPUT_SIZE, 0);
	if (h <= 0) {
		fprintf(stderr, "could not allocate memory\n");
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
		free(d);
		exit(1);
	}
	r = tapasco_device_copy_to(dev, input_data, h, INPUT_SIZE, TAPASCO_COPY_BLOCKING);
	tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, MACH_ID, 0);
	if (r != TAPASCO_SUCCESS) {
		fprintf(stderr, "job copy to failed\n");
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
		exit(1);
	} else {
		tapasco_device_job_set_arg(dev, j_id, 0, sizeof(h), &h);
		r = tapasco_device_job_launch(dev, j_id, TAPASCO_JOB_LAUNCH_BLOCKING);
		if (r != TAPASCO_SUCCESS) {
			fprintf(stderr, "job launch failed\n");
			__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
		 	exit(1);
		}
		r = tapasco_device_copy_from(dev, h, d, INPUT_SIZE, TAPASCO_COPY_BLOCKING);
		if (r != TAPASCO_SUCCESS) {
			fprintf(stderr, "job copy from failed\n");
			__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
			exit(1);
		}
	}
	tapasco_device_free(dev, h);
	tapasco_device_release_job_id(dev, j_id);
	if (memcmp(d, golden, INPUT_SIZE)) {
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
		fprintf(stderr, "FPGA result is wrong\n");
		dump(j_id, d);
		exit(1);
	}
}

static inline void cpu_run(void)
{
	char *data = (char *)malloc(INPUT_SIZE);
	assert(data && "out of memory: cpu_run");
	memcpy(data, input_data, INPUT_SIZE);
	run_benchmark(data);
	if (memcmp(data, golden, INPUT_SIZE))
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
	free(data);
}

static inline void *run(void *p)
{
	long job;
	while ((job = __atomic_fetch_sub(&jobs, 1, __ATOMIC_SEQ_CST)) > 0) {
		if (mode)
			tapasco_run();
		else
			cpu_run();
	}
	return NULL;
}

static inline void print_header(long pc)
{
	printf("Threads, CPU, FPGA\n\n");
}

static inline void print_line(long tc, double *t)
{
	double cpu_t = t[0] / (double)iterations;
	double fpga_t = t[1] / (double)iterations;
	printf("%ld, %3.4f, %3.4f\n", tc, cpu_t, fpga_t);
}

static void *load_input(void)
{
	int fd, n, status;
	char *data;
	generate_binary();
	data = (char *)malloc(INPUT_SIZE);
	assert(data && "out of memory!");
	fd = open("input.data", O_RDONLY);
	n = 0;
	while (n < INPUT_SIZE) {
		status = read(fd, &data[n], INPUT_SIZE - n);
		assert(status >= 0 && "failed to read");
		n += status;
	}
  	close(fd);
	return data;
}

int main(int argc, char **argv)
{
	/*long clk_step, clk;
	pthread_t threads[sysconf(_SC_NPROCESSORS_CONF)];*/
	double times[2];
	pthread_t *threads;
	unsigned long tc;
	if (argc < 2) {
		fprintf(stderr, "Usage: machsuite-harness <max. number of threads> [<number of iterations>]\n");
		exit(EXIT_FAILURE);
	}
	tc = strtoul(argv[1], NULL, 0);
	if (argc > 2)
		iterations = strtol(argv[2], NULL, 0);
	else
		iterations = DEFAULT_ITERATIONS;
	fprintf(stderr, "maximal number of threads = %lu, iterations = %ld\n", tc, iterations);
	fprintf(stderr, "INPUT_SIZE = %d bytes\n", INPUT_SIZE);

	threads = (pthread_t *)malloc(tc * sizeof(*threads));
	assert(threads && "out of memory: threads");

	//times = (double *)malloc(tc * 2 * sizeof(*times));
	//assert(times && "out of memory: times");

	input_data = load_input();
	golden     = load_input();

	run_benchmark(golden);

	// init timer and data
	TIMER_INIT();

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	assert(tapasco_device_func_instance_count(dev, MACH_ID) > 0);

	print_header(tc);
	TIMER_START(total)
	for (int nt = 1; nt <= tc; ++nt) {
		for (mode = 0; mode < 2; ++mode) {
			jobs = iterations;
			errors = 0;
			TIMER_START(run)
			for (int i = 0; i < nt; ++i)
				pthread_create(&threads[i], NULL, run, NULL);
			for (int i = 0; i < nt; ++i)
				pthread_join(threads[i], NULL);
			TIMER_STOP(run)
			times[mode] = errors ? 0.0 : TIMER_USECS(run);
		}
		print_line(nt, times);
	}
	TIMER_STOP(total)
	fprintf(stderr, "Total duration: %llu us.\n", TIMER_USECS(total));

	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);

	//free(times);
	free(threads);
	free(golden);
	free(input_data);
}
