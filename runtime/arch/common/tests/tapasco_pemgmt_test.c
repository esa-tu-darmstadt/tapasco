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
//! @file	tapasco_pemgmt_test.c
//! @brief	Unit tests for functions micro API implementation.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include "tapasco_pemgmt_test.h"
#include <check.h>
#include <platform.h>
#include <platform_addr_map.h>
#include <pthread.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <tapasco_pemgmt.h>
#include <unistd.h>

static platform_info_t _info;

platform_res_t platform_info(platform_ctx_t const *ctx, platform_info_t *info) {
  memcpy(info, &_info, sizeof(_info));
  return PLATFORM_SUCCESS;
}

platform_addr_map_t *platform_context_addr_map(platform_ctx_t const *ctx) {
  return NULL;
}

platform_res_t platform_addr_map_get_slot_base(platform_addr_map_t const *am,
                                               platform_slot_id_t const s,
                                               platform_ctl_addr_t *addr) {
  *addr = 0x0UL;
  return PLATFORM_SUCCESS;
}

tapasco_res_t tapasco_status_set_id(int idx, tapasco_kernel_id_t id) {
  _info.composition.kernel[idx] = id;
  return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_device_platform(tapasco_ctx_t *ctx,
                                      tapasco_devctx_t **p) {
  *p = NULL;
  return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_device_pemgmt(tapasco_ctx_t *ctx, tapasco_pemgmt_t **p) {
  *p = NULL;
  return TAPASCO_SUCCESS;
}

/* Fakes a composition consisting of ascending function ids. */
static inline void composition_asc(void) {
  for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i)
    tapasco_status_set_id(i, i + 1);
}

/* Checks the function counting. */
START_TEST(tapasco_pemgmt_check_counts) {
  composition_asc();

  tapasco_pemgmt_t *pemgmt = NULL;
  tapasco_pemgmt_init(NULL, &pemgmt);

  for (int i = 0; i < TAPASCO_NUM_SLOTS; ++i) {
    fail_if(tapasco_pemgmt_count(pemgmt, i + 1) != 1);
    tapasco_slot_id_t slot_id = tapasco_pemgmt_acquire(pemgmt, i + 1);
    printf("f_id = %d -> slot_id = %d\n", i + 1, slot_id);
    fail_if(slot_id < 0);
    tapasco_slot_id_t unavail = tapasco_pemgmt_acquire(pemgmt, i + 1);
    fail_if(unavail >= 0);
    tapasco_pemgmt_release(pemgmt, slot_id);
  }

  tapasco_pemgmt_deinit(pemgmt);
}
END_TEST

/* Acquire a random function id a hundred times and release. */
static void *run(void *fp) {
  tapasco_pemgmt_t *pemgmt = (tapasco_pemgmt_t *)fp;
  for (int i = 0; i < 100; ++i) {
    tapasco_kernel_id_t const f_id = (rand() % TAPASCO_NUM_SLOTS) + 1;
    tapasco_slot_id_t slot_id;
    do {
      slot_id = tapasco_pemgmt_acquire(pemgmt, f_id);
      sched_yield();
    } while (slot_id < 0);
    tapasco_pemgmt_release(pemgmt, slot_id);
  }
  return NULL;
}

/* Spawns as many threads as host has cores, each starting run. */
START_TEST(tapasco_pemgmt_mt) {
  size_t const nprocs = sysconf(_SC_NPROCESSORS_CONF);
  composition_asc();

  tapasco_pemgmt_t *pemgmt = NULL;
  tapasco_pemgmt_init(NULL, &pemgmt);

  pthread_t *threads = malloc(sizeof(pthread_t *) * nprocs);
  fail_if(!threads);

  printf("starting %zd threads ...\n", nprocs);
  for (int i = 0; i < nprocs; ++i)
    fail_if(pthread_create(&threads[i], NULL, run, pemgmt));

  // join all threads
  for (int i = 0; i < nprocs; ++i)
    fail_if(pthread_join(threads[i], NULL));

  free(threads);
  tapasco_pemgmt_deinit(pemgmt);
}
END_TEST

TCase *pemgmt_testcase(void) {
  TCase *tc_core = tcase_create("Functions");
  tcase_add_test(tc_core, tapasco_pemgmt_check_counts);
  tcase_add_test(tc_core, tapasco_pemgmt_mt);
  return tc_core;
}
