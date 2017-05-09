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
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <errno.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <libgen.h>
#include <assert.h>

#include "rcu_client.h"
#include "rcu_api.h"
#include "kernel_desc.h"

#ifndef NDEBUG
#define DBG(...) \
	do { \
	  fprintf(stdout, "client (%s): ", __func__); \
	  fprintf(stdout, __VA_ARGS__); \
	  fprintf(stdout, "\n"); \
	} while (0)
#else
#define DBG(...)	(void)0
#endif

#define DO_OR_DIE(stmt, ...) \
	do { \
	  if (! (stmt)) { \
	    fprintf(stderr, "FATAL: "); \
	    fprintf(stderr, __VA_ARGS__); \
	    fprintf(stderr, "\n"); \
	    rcu_deinit(); \
	    exit(EXIT_FAILURE); \
	  } \
	} while (0)

static off_t load_file(const char *fn, char **data) {
  DBG("fn = %s", fn);
  int fd = open(fn, O_RDONLY);
  if (! fd) return 0;
  const off_t sz = lseek(fd, 0, SEEK_END); DBG("sz = %zd", sz);
  *data = (char *)malloc(sz);
  lseek(fd, 0, SEEK_SET);
  off_t n = 0;
  ssize_t status;
  do {
    status = read(fd, &(*data)[n], sz - n);
    if (status > 0) n += status;
  } while (status > 0 && n < sz);
  DO_OR_DIE(status >= 0, "error reading %s: %s", fn, strerror(errno));
  return n;
}

int main(int argc, char **argv) {
  DO_OR_DIE(argc == 2, "Expected exactly one argument: kernel description file");
  int sock, i;
  /*****************************************************************************/
  DBG("reading kernel description %s ...", argv[1]);
  kernel_desc_t *kd = kd_read_from_file(argv[1]);
  // DO_OR_DIE(kd->base_addr_cnt, "expected at least one base address!");
  DBG("kernel description read");

  const char *kernel_dir = dirname(argv[1]);
  const uint32_t ns = strlen(kernel_dir) + strlen("/input.data") + 1;
  char *fn = (char *)malloc(ns);

  /*****************************************************************************/
  DBG("loading input data ...");
  char *input = NULL;
  snprintf(fn, ns, "%s/input.data", kernel_dir);
  off_t input_sz = load_file(fn, &input);
  char *input_data = input;
  off_t direct_in_size = 0;

  for (i = 0; i < kd->simple_arg_cnt; ++i)
    direct_in_size += kd->simple_arg_sz[i];
  input_data += direct_in_size;
  input_sz -= direct_in_size;

  /*****************************************************************************/
  DBG("loading check data ...");
  char *check = NULL;
  snprintf(fn, ns, "%s/check.data", kernel_dir);
  off_t check_sz = load_file(fn, &check);// - (kd->ret_sz << 2);
  char *check_data = check;// + (kd->ret_sz << 2);
  off_t direct_ret_size = kd->ret_sz << 2;
  if (direct_ret_size < direct_in_size)
    direct_ret_size = direct_in_size;
  check_sz -= direct_ret_size;
  check_data += direct_ret_size;
  free(fn);

  DBG("simple_arg_cnt = %d, input_sz = %zd, check_sz = %zd",
    kd->simple_arg_cnt, input_sz, check_sz);
  DO_OR_DIE(input_sz == check_sz, "input size does not match check size");
  DBG("reading done");

  /*****************************************************************************/
  // connect to sim and setup the system
  DBG("connecting to simulator....");
  DO_OR_DIE(sock = rcu_init(), "could not connect to simulator");
  DBG("connected to simulator");
  DO_OR_DIE(rcu_setup_system(1), "setup failed");

  if (kd->base_addr_cnt) {
    // load input to memory
    DBG("writing %zd bytes of input data to simulator memory ...", input_sz);
    DO_OR_DIE(rcu_write_mem(kd->base_addr[0], input_sz, input_data),
      "failed to write input data");
    DBG("writing %zd bytes done", input_sz);
  
    DBG("setting %u base addresses ...", kd->base_addr_cnt);
    for (int i = 0; i < kd->base_addr_cnt; ++i) {
      const uint32_t base_addr = i > 0 ? kd->base_addr[0] + kd->base_addr[i]
        : kd->base_addr[0];
      DBG("base address #%d = 0x%08x", i, base_addr);
      DO_OR_DIE(rcu_set_base(0, i, base_addr),
        "failed setting base #%d of instances #%d to 0x%08x",
        i, 0, base_addr);
    }
  }

  /*****************************************************************************/
  if (kd->simple_arg_cnt) {
    char *argp = input;
    if (! kd->simple_arg_sz)
      fprintf(stderr, "WARNING: no sizes for simple args, assuming 32bit each.\n");

    for (int i = 0; i < kd->simple_arg_cnt; ++i) {
      const uint32_t sz = kd->simple_arg_sz ? kd->simple_arg_sz[i] : 4;
      switch (sz) {
      case 8: {
          uint64_t v = *(uint64_t *)argp;
          DBG("setting 64bit reg #%d to %lu", i, v);
          DO_OR_DIE(rcu_set_arg64(0, i, v), "failed to set arg #%d of inst #%d to "
	    "0x%lx (%lu)", i, 0, v, v);
        } break;
      case 4: {
          const uint32_t v = *(uint32_t *)argp;
          DBG("setting 32bit reg #%d to %u", i, v);
          DO_OR_DIE(rcu_set_arg32(0, i, v), "failed to set arg #%d of inst #%d to "
	    "0x%x (%u)", i, 0, v, v);
        } break;
      default: DO_OR_DIE(0, "unsupported size: %d", sz);
      }
      argp += sz;
    }
  }

  int irqs = 0;
  int64_t start = 0, stop = 0;
  DO_OR_DIE(rcu_get_time(&start), "failed to get start time");
  DBG("start time = %ld", start);

  DBG("launching kernel ...");
  DO_OR_DIE(rcu_launch_kernel(0, &irqs), "failed to launch kernel");
  DBG("kernel done");

  DO_OR_DIE(rcu_get_time(&stop), "failed to get stop time");
  DBG("stop time = %ld", stop);

  /*****************************************************************************/
  int ok = 1;

  switch (kd->ret_sz) {
    case RET_SZ_32BIT: {
        int ret = 0, resp = 0;
	int exp = *((int *)check); // expect first entry to be expected ret val
	DO_OR_DIE(rcu_read_kernel_reg(0, 4, &ret, &resp),
	  "failed to read return register");
	DBG("return reg = 0x%x (%d), expected = 0x%x (%d)", ret, ret, exp, exp);
	ok = ok && ret == exp;
      } break;
    case RET_SZ_64BIT: {
        int ret0, ret1, resp;
	const int64_t exp = *((int64_t *)check);
	DO_OR_DIE(rcu_read_kernel_reg(0, 4, &ret0, &resp),
	  "failed to read return register");
	DO_OR_DIE(rcu_read_kernel_reg(0, 5, &ret1, &resp),
	  "failed to read return register");
	const uint32_t r0 = (uint32_t)ret0;
	const uint32_t r1 = (uint32_t)ret1;
	DBG("ret0 = %u, ret1 = %u", r0, r1);
	const int64_t ret = ((uint64_t)ret1 << 32) | (uint64_t)r0;
	DBG("return reg = 0x%lx (%ld), expected = 0x%lx (%ld)", ret, ret, exp, exp);
	ok = ok && ret == exp;
      } break;
    default:
      DBG("no return value expected");
      break;
  }

  if (kd->base_addr_cnt && check_sz == input_sz) {
    DBG("reading results ...");
    DO_OR_DIE(rcu_read_mem(kd->base_addr[0], input_sz, input_data),
      "failed to read output data");
    DBG("results read, checking ...");
  
    if (check_sz == input_sz && memcmp(input_data, check_data, input_sz) != 0) {
      int i = 0;
      int *ptr = (int *)input_data;
      int *cptr = (int *)check_data;
      for (; i < input_sz >> 2; ++i, ++ptr, ++cptr) {
        if (*ptr != *cptr) {
          fprintf(stderr, "ERROR: output[%d] = 0x%08x (%u), check[%d] = 0x%08x (%u)\n",
  	  i, *ptr, *ptr, i, *cptr, *cptr);
        }
      }
    } else {
      DBG("yay, data ok!");
    }
    ok = ok && ! memcmp(input_data, check_data, input_sz);
    DBG("results checked, %s", ok ? "ok" : "not ok");
  }

  DBG("stopping simulation ...");
  DO_OR_DIE(rcu_stop(ok), "stop failed");
  rcu_deinit();
  DBG("simulation stopped, disconnected");
  DBG("client finished!");

  free(input);
  free(check);

  kd_destroy(kd);

  printf("Total kernel execution time: %ld\n", stop - start);
  return ok ? 0 : 1;
}
