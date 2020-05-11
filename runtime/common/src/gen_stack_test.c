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
#include "gen_stack.h"
#include <limits.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

static struct gs_t _stk;

static _Atomic int64_t _exe = 1LL << 24;

void *run(void *arg) {
  while (atomic_fetch_sub(&_exe, 1LL) > 0) {
    gs_push(&_stk, arg);
    gs_pop(&_stk);
  }
  return NULL;
}

int main(int argc, char *argv[]) {
  size_t num_threads = sysconf(_SC_NPROCESSORS_ONLN);
  if (argc > 1)
    num_threads = strtoul(argv[1], NULL, 0);
  pthread_t threads[num_threads];

  for (size_t i = 0; i < num_threads; ++i) {
    pthread_create(&threads[i], NULL, run, (void *)(i + 1));
  }

  for (size_t i = 0; i < num_threads; ++i) {
    pthread_join(threads[i], NULL);
  }
}
