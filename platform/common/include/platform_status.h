//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (PLATFORM).
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
/**
 *  @file	platform_status.h
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef PLATFORM_STATUS_H__
#define PLATFORM_STATUS_H__

#include <platform_global.h>
#include <platform_caps.h>

typedef struct platform_status platform_status_t;

platform_res_t platform_status_init(platform_status_t **status);
void platform_status_deinit(platform_status_t *status);
int platform_status_has_capability_0(const platform_status_t *status,
		platform_capabilities_0_t caps);
uint32_t platform_status_get_vivado_version(const platform_status_t *status);
uint32_t platform_status_get_tapasco_version(const platform_status_t *status);
uint32_t platform_status_get_gen_ts(const platform_status_t *status);
uint32_t platform_status_get_host_clk(const platform_status_t *status);
uint32_t platform_status_get_mem_clk(const platform_status_t *status);
uint32_t platform_status_get_design_clk(const platform_status_t *status);

uint32_t platform_status_get_slot_id(const platform_status_t *status,
		platform_slot_id_t const slot_id);

uint32_t platform_status_get_slot_mem(const platform_status_t *status,
		platform_slot_id_t const slot_id);

platform_ctl_addr_t platform_status_get_slot_base(const platform_status_t *status,
		platform_slot_id_t const slot_id);

platform_ctl_addr_t platform_status_get_special_base(
		const platform_status_t *status,
		platform_special_ctl_t const ent_id);

#endif /* PLATFORM_STATUS_H__ */
