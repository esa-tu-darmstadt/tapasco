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
//! @file	arrayinit-example.c
//! @brief	TPC API based example program exercising a hardware threadpool
//!             containing instances of the arrayinit kernel.
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


void handle_error() {
    int l = tapasco_last_error_length();
    char* buf = (char*)malloc(sizeof(char) * l);
    tapasco_last_error_message(buf, l);
    printf("ERROR: %s\n", buf);
    free(buf);
}

static unsigned int check_array(int *arr, size_t sz) {
  unsigned int errs = 0;
  for (size_t i = 0; i < sz; ++i) {
    if (arr[i] != i) {
      fprintf(stderr, "wrong data at %zd: %d\n", i, arr[i]);
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
    if(t == 0) {
        handle_error();
        ret = -1;
        goto finish;
    }

    // Retrieve the number of devices from the runtime
    int num_devices = 0;
    if((num_devices = tapasco_tlkm_device_len(t)) < 0) {
        handle_error();
        ret = -1;
        goto finish_tlkm;
    }

    if(num_devices == 0) {
        printf("No TaPaSCo devices found.\n");
        ret = -1;
        goto finish_tlkm;
    }

    // Allocates the first device
    Device *d = 0;
    if((d = tapasco_tlkm_device_alloc(t, 0)) == 0) {
        handle_error();
        ret = -1;
        goto finish_tlkm;
    }

    if(tapasco_device_access(d, TlkmAccessExclusive) < 0) {
        handle_error();
        ret = -1;
        goto finish_device;
    }

  // check arrayinit instance count
  //printf("instance count: %zd\n", tapasco_device_kernel_pe_count(dev, 11));
  //assert(tapasco_device_kernel_pe_count(dev, 11));

  for (int run = 0; run < RUNS; ++run) {

    // Allocate memory for return value of hardware
    int *arr = (int *)malloc(SZ * sizeof(int));
    if(arr == 0) {
        printf("Could not allocate memory for run %d.\n", run);
        ret = -1;
        goto finish_device;
    }

    memset(arr, -1, SZ * sizeof(int));

    // Create argument list
    JobList *jl = tapasco_job_param_new();

    // Allocates memory on device and copies data from device after execution
    tapasco_job_param_alloc(d, (uint8_t*)arr, SZ * sizeof(int), false, true, true, jl);

    // Acquire arrayinit PE
    Job* j = tapasco_device_acquire_pe(d, 11);
    if(j == 0) {
        handle_error();
        ret = -1;
        goto finish_device;
    }

    if(tapasco_job_start(j, jl) < 0) {
        handle_error();
        ret = -1;
        goto finish_device;
    }

    if(tapasco_job_release(j, 0, true) < 0) {
        handle_error();
        ret = -1;
        goto finish_device;
    }
    unsigned int errs = check_array(arr, SZ);
    errs_total += errs;
    printf("\nRUN %d %s\n", run, errs == 0 ? "OK" : "NOT OK");
    free(arr);
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
