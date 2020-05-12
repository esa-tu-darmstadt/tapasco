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
//! @file	arrayupdate-example.c
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the arrayupdate kernel.
//!             Single-threaded variant.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <tapasco.h>

#define SZ 256
#define RUNS 25

#define PE_ID 9

void handle_error() {
  int l = tapasco_last_error_length();
  char *buf = (char *)malloc(sizeof(char) * l);
  tapasco_last_error_message(buf, l);
  printf("ERROR: %s\n", buf);
  free(buf);
}

static void init_array(int *arr, size_t sz) {
  for (size_t i = 0; i < sz; ++i)
    arr[i] = i + 1;
}

void arrayupdate(int arr[SZ]) {
  for (size_t i = 0; i < SZ; i++)
    arr[i] += 42;
}

static unsigned int check_arrays(int *arr, int *golden_arr, size_t sz) {
  unsigned int errs = 0;
  for (size_t i = 0; i < sz; ++i) {
    if (arr[i] != golden_arr[i]) {
      fprintf(stderr, "wrong data at %zd: %d, should be %d\n", i, arr[i],
              golden_arr[i]);
      ++errs;
    }
  }
  return errs;
}

int main(int argc, char **argv) {
  int errs_total = 0;
  int ret = 0;

  // initialize threadpool
  tapasco_init_logging();
  TLKM *t = tapasco_tlkm_new();
  if (t == 0) {
    handle_error();
    ret = -1;
    goto finish;
  }

  // Retrieve the number of devices from the runtime
  int num_devices = 0;
  if ((num_devices = tapasco_tlkm_device_len(t)) < 0) {
    handle_error();
    ret = -1;
    goto finish_tlkm;
  }

  if (num_devices == 0) {
    printf("No TaPaSCo devices found.\n");
    ret = -1;
    goto finish_tlkm;
  }

  // Allocates the first device
  Device *d = 0;
  if ((d = tapasco_tlkm_device_alloc(t, 0)) == 0) {
    handle_error();
    ret = -1;
    goto finish_tlkm;
  }

  if (tapasco_device_num_pes(d, PE_ID) == 0) {
    printf("No Arrayupdate PE found.\n");
    goto finish_device;
  }

  if (tapasco_device_access(d, TlkmAccessExclusive) < 0) {
    handle_error();
    ret = -1;
    goto finish_device;
  }

  for (int run = 0; run < RUNS; ++run) {
    // init whole array to subsequent numbers
    int *arr = (int *)malloc(SZ * sizeof(int));
    if (arr == 0) {
      printf("Could not allocate memory for run %d.\n", run);
      ret = -1;
      goto finish_device;
    }
    int *golden_arr = (int *)malloc(SZ * sizeof(int));
    if (golden_arr == 0) {
      printf("Could not allocate memory for run %d.\n", run);
      ret = -1;
      goto finish_device;
    }
    init_array(arr, SZ);
    init_array(golden_arr, SZ);
    // golden run
    arrayupdate(golden_arr);

    // Create argument list
    JobList *jl = tapasco_job_param_new();

    // Allocates memory on device and copies data from device after execution
    tapasco_job_param_alloc(d, (uint8_t *)arr, SZ * sizeof(int), true, true,
                            true, jl);

    // Acquire arrayinit PE
    Job *j = tapasco_device_acquire_pe(d, PE_ID);
    if (j == 0) {
      handle_error();
      ret = -1;
      goto finish_device;
    }

    if (tapasco_job_start(j, &jl) < 0) {
      handle_error();
      ret = -1;
      goto finish_device;
    }

    if (tapasco_job_release(j, 0, true) < 0) {
      handle_error();
      ret = -1;
      goto finish_device;
    }

    unsigned int errs = check_arrays(arr, golden_arr, SZ);
    printf("\nRUN %d %s\n", run, errs == 0 ? "OK" : "NOT OK");

    errs_total += errs;

    free(arr);
    free(golden_arr);
  }

  if (!errs_total)
    printf("SUCCESS\n");
  else
    fprintf(stderr, "FAILURE\n");

finish_device:
  tapasco_tlkm_device_destroy(d);
finish_tlkm:
  tapasco_tlkm_destroy(t);
finish:
  return ret;
}
