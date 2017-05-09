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
#ifndef __KERNEL_DESC_H__
#define __KERNEL_DESC_H__

#include <stdint.h>

#ifdef __cplus_plus
extern "C" {
#endif

typedef enum { RET_SZ_NA, RET_SZ_32BIT, RET_SZ_64BIT } ret_sz_t;

typedef struct kernel_desc_t {
  uint32_t *base_addr;
  uint32_t base_addr_cnt;
  uint32_t simple_arg_cnt;
  uint32_t *simple_arg_sz;
  ret_sz_t ret_sz;
} kernel_desc_t;

kernel_desc_t *kd_read_from_file(const char *fn);
void kd_destroy(kernel_desc_t *kd);

#ifdef __cplus_plus
} /* extern "C" */
#endif

#endif /* __KERNEL_DESC_H__ */
