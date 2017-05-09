//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include "kernel_desc.h"

#ifndef NDEBUG
	#define DBG(...) do { \
		if (getenv("KD_LIB_DEBUG")) { \
			fprintf(stderr, "%s: ", __func__); \
			fprintf(stderr, __VA_ARGS__); \
			fprintf(stderr, "\n"); \
		} \
	} while (0)
#else
	#define DBG(...)
#endif

#define KNOWN_KEYS \
	_X("BaseAddresses", KT_BASE_ADDRESSES, parse_base_addresses) \
	_X("SimpleArgs", KT_SIMPLE_ARGS, parse_simple_args) \
	_X("SimpleArgSizes", KT_SIMPLE_ARG_SIZES, parse_simple_arg_sizes) \
	_X("ReturnSize", KT_RETURN_VAL_SZ, parse_return_value_size)

typedef enum {
  KT_INVALID,
  #define _X(name, val, func) val,
  KNOWN_KEYS
  #undef _X
} kd_key_t;

typedef struct pp_t {
  kernel_desc_t *kd;
  const char *start;
  off_t sz;
  char *p;
  off_t curr;
} pp_t;

static inline void skip_ws(pp_t *pp) {
  while (pp->curr < pp->sz && (*pp->p == ' ' || *pp->p == '\n' || *pp->p == '\t')) {
    ++(pp->p);
    ++(pp->curr);
  }
}

static inline void skip_ws_nn(pp_t *pp) {
  while (pp->curr < pp->sz && (*pp->p == ' ' || *pp->p == '\t')) {
    ++(pp->p);
    ++(pp->curr);
  }
}

static inline void skip_char(pp_t *pp, const char c) {
  while (pp->curr < pp->sz && *pp->p == c) {
    ++(pp->p);
    ++(pp->curr);
  }
}

static inline void skip_until(pp_t *pp, const char c) {
  while (pp->curr < pp->sz && *pp->p != c) {
    ++(pp->p);
    ++(pp->curr);
  }
}

static inline void skip_until_ws(pp_t *pp) {
  while (pp->curr < pp->sz && *pp->p != ' ' && *pp->p != '\n' && *pp->p != '\t') {
    ++(pp->p);
    ++(pp->curr);
  }
}

static inline uint32_t count_elems(pp_t *pp) {
  uint32_t cnt = 0;
  skip_ws_nn(pp);
  while (pp->curr < pp->sz && *pp->p != '\n') {
    skip_ws_nn(pp);
    ++cnt;
    skip_until_ws(pp);
  }
  DBG("count = %u", cnt);
  return cnt;
}

static char *load_file(const char *fn, off_t *off) {
  int fd = open(fn, O_RDONLY);
  assert(fd);
  *off = lseek(fd, 0, SEEK_END);
  DBG("file = %s, size = %zd bytes", fn, *off);
  lseek(fd, 0, SEEK_SET);

  char *res = (char *)malloc(*off);
  assert(res);

  off_t n = *off; int status = 1;
  while (n > 0 && (status = read(fd, &res[*off - n], n))) {
    if (status < 0) {
      fprintf(stderr, "failed to read: %s", strerror(errno));
      exit(errno);
    }
    n -= status;
  }
  close(fd);
  return res;
}

static kd_key_t parse_key(pp_t *pp) {
  skip_ws(pp);
  #define _X(name, val, func) \
    if (strlen(name) <= pp->sz - pp->curr && !strncmp(pp->p, name, strlen(name))) { \
      pp->p += strlen(name); \
      pp->curr += strlen(name); \
      skip_ws(pp); skip_char(pp, '=');\
      return val; \
    }
    KNOWN_KEYS
  #undef _X
  // unknown key, consume line
  skip_until(pp, '\n');
  skip_ws(pp);
  return KT_INVALID;
}

static void parse_base_addresses(pp_t *pp) {
  uint32_t b[320];
  uint32_t b_c = 0;
  while (*pp->p != '\n' && pp->curr < pp->sz) {
    skip_ws(pp);
    skip_char(pp, '"');
    // first absolute, others relative to first
    b[b_c] = strtoul(pp->p, NULL, 0) - (b_c > 0 ? b[0] : 0x0);
    if (errno == 0) {
      DBG("found base: 0x%x", b[b_c]);
      ++b_c;
    }
    skip_until_ws(pp);
  }
  assert(pp->kd);
  if (b_c) {
    pp->kd->base_addr = (uint32_t *)malloc(b_c * sizeof(b[0]));
    assert(pp->kd->base_addr);
    memcpy(pp->kd->base_addr, b, b_c * sizeof(b[0]));
  }
  pp->kd->base_addr_cnt = b_c;
}

static void parse_simple_arg_sizes(pp_t *pp) {
  uint32_t sz[1024];
  uint32_t sz_c = 0;
  while (*pp->p != '\n' && pp->curr < pp->sz) {
    skip_ws(pp);
    skip_char(pp, '"');
    // first absolute, others relative to first
    sz[sz_c] = strtoul(pp->p, NULL, 0);
    if (errno == 0) {
      DBG("found size: %d", sz[sz_c]);
      ++sz_c;
    }
    skip_until_ws(pp);
  }
  assert(pp->kd);
  if (sz_c) {
    pp->kd->simple_arg_sz = (uint32_t *)malloc(sz_c * sizeof(sz[0]));
    assert(pp->kd->simple_arg_sz);
    memcpy(pp->kd->simple_arg_sz, sz, sz_c * sizeof(sz[0]));
  }
}

static void parse_simple_args(pp_t *pp) {
  pp->kd->simple_arg_cnt = count_elems(pp);
}

static void parse_return_value_size(pp_t *pp) {
  skip_ws(pp);
  uint32_t sz = strtoul(pp->p, NULL, 0);
  pp->kd->ret_sz = RET_SZ_32BIT;
  if (! errno) {
    switch (sz) {
      case 8: pp->kd->ret_sz = RET_SZ_64BIT; break;
      case 4: pp->kd->ret_sz = RET_SZ_32BIT; break;
      default:
        fprintf(stderr, "WARNING: found invalid return size %d, assuming 32bit.", sz);
	break;
    }
  } else {
    fprintf(stderr, "WARNING: invalid return size value, assuming 32bit.");
  }
  DBG("return value size: %s", pp->kd->ret_sz == RET_SZ_64BIT ? "64bit" : "32bit");
}

kernel_desc_t *kd_read_from_file(const char *fn) {
  off_t sz;
  char *raw = load_file(fn, &sz);
  kd_key_t key;

  pp_t pp;
  pp.kd = (kernel_desc_t *)calloc(sizeof(kernel_desc_t), 1);
  pp.start = raw;
  pp.sz = sz;
  pp.p = raw;
  pp.curr = 0;

  DBG("opening file %s", fn);

  do {
    key = parse_key(&pp);
    switch (key) {
    #define _X(name, val, func) \
      case val: \
        DBG("found %s", name); \
	func(&pp); \
	break; 
      KNOWN_KEYS
    #undef _X
      case KT_INVALID:
      default:
	break;
    }
  } while (pp.curr < pp.sz);

  free(raw);
  // warn if sizes are missing
  if (pp.kd->simple_arg_cnt && !pp.kd->simple_arg_sz)
    fprintf(stderr, "WARNING: simple args specified, but not their sizes!\n");
  return pp.kd;
}

void kd_destroy(kernel_desc_t *kd) {
  free(kd->simple_arg_sz);
  free(kd->base_addr);
  free(kd);
}
