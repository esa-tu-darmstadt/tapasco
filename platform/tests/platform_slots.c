//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
//! @file	platform_slots.c
//! @brief	Platform API test which triggers countdown kernels (ID 14) in all
//!		available slots. Basic tool to debug IRQ mechanisms.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>

#include <platform.h>
#include "common.h"

#define COUNTER_ID					14

static platform_ctx_t *ctx;
static platform_devctx_t *devctx;
static platform_info_t info;

struct cfg_t {
	long all_slots, slot_id, delay, iterations, mt;
};

static int call_slot(struct cfg_t const *cfg, short unsigned const slot_id)
{
	printf("Calling slot #%u ...\n", slot_id);
	uint32_t cd_loops = cfg->delay <= clock_period() ? 1 : (cfg->delay / clock_period() - 2) >> 1;
	const uint32_t addr = info.base.arch[slot_id];
	const uint32_t fire = 1;
	uint32_t retval = 0;
	for (long i = 0; i < cfg->iterations; ++i) {
		if (info.composition.kernel[slot_id] != COUNTER_ID) return 0;
		if (! check( platform_write_ctl(devctx, addr + 0x4, sizeof(fire), &fire, PLATFORM_CTL_FLAGS_NONE) ))
			return 1;
		if (! check( platform_write_ctl(devctx, addr + 0x8, sizeof(fire), &fire, PLATFORM_CTL_FLAGS_NONE) ))
			return 1;
		if (! check( platform_write_ctl(devctx, addr + 0x20, sizeof(cd_loops), &cd_loops, PLATFORM_CTL_FLAGS_NONE) ))
			return 1;
		if (! check( platform_write_ctl(devctx, addr, sizeof(fire), &fire, PLATFORM_CTL_FLAGS_NONE) ))
			return 1;
		if (! check( platform_wait_for_slot(devctx, slot_id) ))
			return 1;
		if (! check( platform_write_ctl(devctx, addr + 0xc, sizeof(fire), &fire, PLATFORM_CTL_FLAGS_NONE) ))
			return 1;
		if (! check( platform_read_ctl(devctx, addr + 0x10, sizeof(retval), &retval, PLATFORM_CTL_FLAGS_NONE) ))
			return 1;
		if (retval <= cd_loops) {
			fprintf(stderr, "ERROR: returned value = %u, expected: >= %u\n", retval, cd_loops);
			return 1;
		}
	}
	return 0;
}

struct call_t {
	struct cfg_t *cfg;
	long slot_id;
};

static void *run_call_slot(void *p)
{
	struct call_t *c = (struct call_t *)p;
	long ret = call_slot(c->cfg, c->slot_id);
	return (void *)ret;
}

static void print_usage_and_exit(void)
{
	printf("Usage: platform_slots (<slot #> | -a) [<delay>] [<iterations>]\n"
			"\t<slot #>:\thardware thread slot to test, or -a for all\n"
			"\t<delay>:\tdesired countdown delay (in ns) (default: 10000)\n"
			"\t<iterations>:\tnumber of calls to perform (default: 1)\n\n");
	exit(EXIT_FAILURE);
}

int main(int argc, char **argv)
{
	struct cfg_t cfg;
	platform_res_t res;
	int errs = 0;
	if (argc < 2)
		print_usage_and_exit();

	cfg.all_slots = strcmp("-a", argv[1]) == 0;

	if (! cfg.all_slots)
		cfg.slot_id = strtoul(argv[1], NULL, 0);
	else
		cfg.slot_id = -1;

	if (argc > 2)
		cfg.delay = strtoul(argv[2], NULL, 0);
	else
		cfg.delay = 10000;

	if (argc > 3)
		cfg.iterations = strtoul(argv[3], NULL, 0);
	else
		cfg.iterations = 1;

	cfg.mt = cfg.all_slots && argc > 4;

	printf("Starting: all_slots = %ld, slot_id = %ld, delay = %ld, iterations = %ld\n",
			cfg.all_slots, cfg.slot_id, cfg.delay, cfg.iterations);

	if ((res = platform_init(&ctx)) != PLATFORM_SUCCESS) {
		fprintf(stderr, "Failed to initialize Platform API: %s\n", platform_strerror(res));
		exit(EXIT_FAILURE);
	} else if ((res = platform_create_device(ctx, 0, PLATFORM_EXCLUSIVE_ACCESS, &devctx)) != PLATFORM_SUCCESS) {
		fprintf(stderr, "Failed to create Platform device: %s\n", platform_strerror(res));
		platform_deinit(ctx);
		exit(EXIT_FAILURE);
	}
	platform_info(devctx, &info);
	if (cfg.all_slots) {
		if (cfg.mt) {
			pthread_t t[PLATFORM_NUM_SLOTS];
			long ret[PLATFORM_NUM_SLOTS];
			struct call_t c[PLATFORM_NUM_SLOTS];
			for (int i = 0; i < PLATFORM_NUM_SLOTS; ++i) {
				c[i].cfg = &cfg;
				c[i].slot_id = i;
				pthread_create(&t[i], NULL, run_call_slot, &c[i]);
			}
			for (int i = 0; i < PLATFORM_NUM_SLOTS; ++i)
				pthread_join(t[i], (void *)&ret[i]);
			for (int i = 0; i < PLATFORM_NUM_SLOTS; ++i)
				errs += ret[i];
		} else {
			for (unsigned short i = 0; i < PLATFORM_NUM_SLOTS; ++i) {
				errs += call_slot(&cfg, i);
			}
		}
	} else {
		errs = call_slot(&cfg, cfg.slot_id);
	}
	platform_destroy_device_by_id(ctx, 0);
	platform_deinit(ctx);
	return errs;
}
