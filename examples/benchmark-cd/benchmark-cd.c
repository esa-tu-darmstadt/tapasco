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

#define	MIN_NSECS					(10000)
#define MAX_NSECS					(1000000)
#define NSTEPS						(15)
#define JOBS						(1000)

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
		if (fd == -1) {
			fprintf(stderr, "WARNING: could not open /sys/class/fclk/fclk0/set_rate, using TAPASCO_FREQ\n");
			assert(getenv("TAPASCO_FREQ") && "must set TAPASCO_FREQ env var!");
			hz = strtoul(getenv("TAPASCO_FREQ"), NULL, 0) * 1000000;
		} else {
			rc = read(fd, buf, 1023);
			assert(rc); (void) rc;
			fprintf(stderr, "fclk/set_rate = %s", buf);
			close(fd);
			hz = strtoul(buf, NULL, 0);
		}
		period = 1.0 / (hz / 1000000000.0);
		fprintf(stderr, "period = %3.2f ns\n", period);
	}
	return period;
}

static inline unsigned long ns_to_cd(unsigned long ns) {
	// convert to countdown value:
	// t = 2 * period + n * 2 * period
	// i.e., 2 cycles init + 2 cycles per loop iteration
	return ns / (2 * clock_period()) - 1;
}

static inline void tapasco_run(long cc)
{
	tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, 14, 0);
	tapasco_device_job_set_arg(dev, j_id, 0, sizeof(cc), &cc);
	if (tapasco_device_job_launch(dev, j_id,
			TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING) != TAPASCO_SUCCESS)
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
	tapasco_device_release_job_id(dev, j_id);
}

static inline void cpu_run(long us)
{
	usleep(us);
}

static inline void *run(void *p)
{
	long job;
	long clk = (long)p;
	long cc = ns_to_cd(clk);
	long us = clk / 1000;
	while ((job = __atomic_fetch_sub(&jobs, 1, __ATOMIC_SEQ_CST)) > 0) {
		if (mode == 0)
			tapasco_run(cc);
		else
			cpu_run(us);
	}
	return NULL;
}

static inline void print_header(void)
{
	long const pc = sysconf(_SC_NPROCESSORS_CONF);
	printf("Kernel Runtime (us)");
	for (int no_p = 1; no_p <= pc; ++no_p)
		printf(",Ideal (%d cores), CPU (%d core), FPGA (%d core)",
				no_p, no_p, no_p);
	printf("\n\n");
}

static inline void print_line(double clk, double *t)
{
	long const pc = sysconf(_SC_NPROCESSORS_CONF);
	printf("%3.2f", clk);
	for (int no_p = 1; no_p <= pc; ++no_p) {
		double cpu_t = 1.0 / (t[no_p - 1] / clk / JOBS);
		double fpga_t = 1.0 / (t[no_p + pc - 1] / clk / JOBS);
		printf(", %3.4f, %3.4f, %3.4f", (float)no_p, cpu_t, fpga_t);
	}
	/*printf("%3.2f, %3.2f, %3.2f", clk, ideal_1, ideal_n);
	for (int i = 0; i < sysconf(_SC_NPROCESSORS_CONF) * 2; ++i) {
		double const actual = 1.0 / (t[i] / clk / JOBS);
		printf(", %3.8f", actual);
	}*/
	printf("\n");
}

int main(int argc, char **argv)
{
	long clk_step, clk;
	pthread_t threads[sysconf(_SC_NPROCESSORS_CONF)];
	double times[sysconf(_SC_NPROCESSORS_CONF) * 2];

	// init timer and data
	TIMER_INIT();

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	assert(tapasco_device_func_instance_count(dev, 14) > 0);

	clk_step = (MAX_NSECS - MIN_NSECS) / NSTEPS;
	clk = MIN_NSECS;
	print_header();
	TIMER_START(total)
	for (int i = 0; i <= NSTEPS; ++i, clk += clk_step) {
		for (mode = 0; mode < sysconf(_SC_NPROCESSORS_CONF) * 2; ++mode) {
			//for (int nt = 1; nt <= 1/*sysconf(_SC_NPROCESSORS_CONF)*/; ++nt) {
			//	
				jobs = JOBS;
				int const nt = mode % sysconf(_SC_NPROCESSORS_CONF) + 1;
				errors = 0;
				TIMER_START(run)
				for (int i = 0; i < nt; ++i)
					pthread_create(&threads[i], NULL, run, (void *)clk);
				for (int i = 0; i < nt; ++i)
					pthread_join(threads[i], NULL);
				TIMER_STOP(run)
				times[mode] = errors ? 0.0 : TIMER_USECS(run);
			//}
		}
		print_line(clk / 1000.0, times);
	}
	TIMER_STOP(total)
	fprintf(stderr, "Total duration: %llu us.\n", TIMER_USECS(total));
	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
}
