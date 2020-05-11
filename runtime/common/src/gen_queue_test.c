/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
#include "gen_queue.h"
#include <limits.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define RUNS (long)(1L << 22)

static atomic_long jobs = RUNS;
static atomic_bool stop = 0;
static long recv = 0;

void *push_data(void *p) {
  struct gq_t *q = (struct gq_t *)p;
  long id;
  while ((id = atomic_fetch_sub(&jobs, 1)) > 0) {
    gq_enqueue(q, (void *)id);
  }
  return NULL;
}

void *pop_data(void *p) {
  struct gq_t *q = (struct gq_t *)p;
  long id;
  while (!stop) {
    while ((id = (long)gq_dequeue(q))) {
      ++recv;
    }
    usleep(1000);
  }
  return NULL;
}

int main(int argc, char *argv[]) {
  const long num_cpus =
      argc > 1 ? strtol(argv[1], NULL, 0) : sysconf(_SC_NPROCESSORS_ONLN) + 1;
  pthread_t threads[num_cpus];
  struct gq_t *q = gq_init();
  printf("Creating %ld threads ...\n", num_cpus);
  pthread_create(&threads[0], NULL, pop_data, q);
  for (size_t i = 1; i < num_cpus; ++i) {
    pthread_create(&threads[i], NULL, push_data, q);
  }
  for (size_t i = 1; i < num_cpus; ++i) {
    pthread_join(threads[i], NULL);
  }
  stop = 1;
  usleep(10000);
  pthread_join(threads[0], NULL);
  printf("recv: %ld, expected: %ld\n", recv, RUNS);
  gq_destroy(q);
  return recv == RUNS ? 0 : 1;
}
