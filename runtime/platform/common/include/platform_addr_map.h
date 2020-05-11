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
//! @file	platform_addr_map.h
//! @brief	Supporting code for dynamic addr map.
//! @authors	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef PLATFORM_API_ADDR_MAP_H__
#define PLATFORM_API_ADDR_MAP_H__

#include <platform_types.h>

typedef struct platform_addr_map platform_addr_map_t;

platform_res_t platform_addr_map_init(platform_devctx_t *ctx,
                                      platform_info_t const *info,
                                      platform_addr_map_t **am);

void platform_addr_map_deinit(platform_devctx_t *ctx, platform_addr_map_t *am);

platform_res_t platform_addr_map_get_slot_base(platform_addr_map_t const *am,
                                               platform_slot_id_t const slot_id,
                                               platform_ctl_addr_t *addr);

platform_res_t
platform_addr_map_get_component_base(platform_addr_map_t const *am,
                                     platform_component_t const comp_id,
                                     platform_ctl_addr_t *addr);

#endif /* PLATFORM_API_ADDR_MAP_H__ */
