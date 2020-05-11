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

#ifndef PLATFORM_INFO_H__
#define PLATFORM_INFO_H__

#include <platform_global.h>
#include <platform_types.h>
#include <stdint.h>

#define TAPASCO_MAGIC_ID 0xe5ae1337

typedef struct platform_info {
  uint32_t magic_id;
  uint32_t num_intc;
  uint32_t caps0;
  struct {
    uint32_t vivado;
    uint32_t tapasco;
  } version;
  uint32_t compose_ts;
  struct {
    uint32_t host;
    uint32_t design;
    uint32_t memory;
  } clock;
  struct {
    platform_kernel_id_t kernel[PLATFORM_NUM_SLOTS];
    uint32_t memory[PLATFORM_NUM_SLOTS];
  } composition;
  struct {
    platform_ctl_addr_t platform[PLATFORM_NUM_SLOTS];
    platform_ctl_addr_t arch[PLATFORM_NUM_SLOTS];
  } base;
} platform_info_t;

inline size_t platform_info_pe_count(platform_info_t const *info,
                                     platform_kernel_id_t const k_id) {
  size_t ret = 0;
  for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s)
    if (info->composition.kernel[s] == k_id)
      ++ret;
  return ret;
}

void log_device_info(platform_dev_id_t const dev_id,
                     platform_info_t const *info);

#endif /* PLATFORM_INFO_H__ */