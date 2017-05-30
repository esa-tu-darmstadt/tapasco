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
#include <assert.h>
#include <fcntl.h>
#include <errno.h>
#include <tapasco.h>
#include <platform.h>
#include "../benchmark-mem/timer.h"

#define	MIN_NSECS					(10000)
#define MAX_NSECS					(1000000)
#define NSTEPS						(15)
#define JOBS						(10)

struct config_t {
	unsigned long int min;
	unsigned long int max;
	unsigned long int time_steps;
	unsigned long int iterations;
};

static long errors;

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
		ssize_t rc; (void)rc;
		int fd = open("/sys/class/fclk/fclk0/set_rate", O_RDONLY);
		if (fd == -1) {
			fprintf(stderr, "WARNING: could not open /sys/class/fclk/fclk0/set_rate, using TAPASCO_FREQ\n");
			assert(getenv("TAPASCO_FREQ") && "must set TAPASCO_FREQ env var!");
			hz = strtoul(getenv("TAPASCO_FREQ"), NULL, 0) * 1000000;
		} else {
			rc = read(fd, buf, 1023);
			assert(rc);
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

static inline void tapasco_run(uint32_t cc)
{
	tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev, 14, 0);
	tapasco_device_job_set_arg(dev, j_id, 0, sizeof(cc), &cc);
	if (tapasco_device_job_launch(dev, j_id, TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING) !=
			TAPASCO_SUCCESS)
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
	tapasco_device_release_job_id(dev, j_id);
}

static inline void platform_run(uint32_t cc)
{
	uint32_t const start = 1;
	platform_ctl_addr_t sb = platform_address_get_slot_base(0, 0);
	if (platform_write_ctl(sb + 0x20, 4, &cc, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
	if (platform_write_ctl_and_wait(sb, 4, &start, 0, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
	// ack interrupt
	if (platform_write_ctl(sb + 0xc, 4, &start, PLATFORM_CTL_FLAGS_NONE) != PLATFORM_SUCCESS)
		__atomic_fetch_add(&errors, 1, __ATOMIC_SEQ_CST);
}

static inline void print_header(void)
{
	printf("Kernel time (ns), Kernel time (cycles), Average Latency TPC (us), Average Latency Platform (us)\n");
}

static inline void print_line(double clk, unsigned long long t1, unsigned long long t2)
{
	printf("%3.2f, %lu, %llu, %llu\n", clk, ns_to_cd(clk), t1, t2);
}

static inline void print_usage(void)
{
	fprintf(stderr,
		"Usage: benchmark-latency [<MIN_TIME> [<MAX_TIME> [<TIME_STEPS> [<ITERATIONS>]]]] with\n"
		"\t<MIN_TIME>   = minimum kernel runtime in ns                (default: 10ns)\n"
		"\t<MAX_TIME>   = maximum kernel runtime in ns                (default: 10000ns)\n"
		"\t<TIME_STEPS> = number of equidistant sampling points       (default:10)\n"
		"\t<ITERATIONS> = number of iterations at each sampling point (default:1000)\n\n");
}

static inline void check_parse(unsigned long v)
{
	if (v == 0) {
		fprintf(stderr, "ERROR: invalid option string!\n");
		print_usage();
		exit(EXIT_FAILURE);
	}
}

static inline void print_args(struct config_t const *cfg)
{
	fprintf(stderr,
		"Configuration:\n"
		"\tminimum kernel time = %lu\n"
		"\tmaximum kernel time = %lu\n"
		"\tkernel time steps   = %lu\n"
		"\titerations          = %lu\n\n",
		cfg->min, cfg->max, cfg->time_steps, cfg->iterations);
}

static inline void parse_args(int argc, char **argv, struct config_t *cfg)
{
	// set defaults
	cfg->min        = 10;
	cfg->max        = 10000;
	cfg->time_steps = 10;
	cfg->iterations = 10;

	// try to parse arguments (if some where given)
	if (argc > 1) {
		cfg->min = strtoul(argv[1], NULL, 0);
		check_parse(cfg->min);
	}
	if (argc > 2) {
		cfg->max = strtoul(argv[2], NULL, 0);
		check_parse(cfg->max);
	}
	if (argc > 3) {
		cfg->time_steps = strtoul(argv[3], NULL, 0);
		check_parse(cfg->time_steps);
	}
	if (argc > 4) {
		cfg->iterations = strtoul(argv[4], NULL, 0);
		check_parse(cfg->iterations);
	}
	print_args(cfg);
}

int main(int argc, char **argv)
{
	struct config_t cfg;
	parse_args(argc, argv, &cfg);

	unsigned long long int times[cfg.time_steps];

	// init timer and data
	TIMER_INIT();

	// initialize threadpool
	check_tapasco(tapasco_init(&ctx));
	check_tapasco(tapasco_create_device(ctx, 0, &dev, 0));
	assert(tapasco_device_func_instance_count(dev, 14) > 0);

	unsigned long int clk_step = (cfg.max - cfg.min) / cfg.time_steps;
	unsigned long int clk = cfg.min;
	print_header();
	TIMER_START(total)
	for (int i = 0; i < cfg.time_steps; ++i, clk += clk_step) {
		TIMER_START(run)
		for (int j = 0; j < cfg.iterations; ++j)
			tapasco_run(ns_to_cd(clk));
		TIMER_STOP(run)
		times[i] = (TIMER_USECS(run) - (clk * cfg.iterations / 1000)) / cfg.iterations;

		TIMER_START(papi_run)
		for (int j = 0; j < cfg.iterations; ++j)
			platform_run(ns_to_cd(clk));
		TIMER_STOP(papi_run)
		unsigned long long int papi_time = (TIMER_USECS(papi_run) - (clk * cfg.iterations / 1000)) / cfg.iterations;

		print_line(clk, times[i], papi_time);
	}
	TIMER_STOP(total)
	fprintf(stderr, "Total duration: %llu us, errors: %ld.\n", TIMER_USECS(total), errors);
	// de-initialize threadpool
	tapasco_destroy_device(ctx, dev);
	tapasco_deinit(ctx);
}
