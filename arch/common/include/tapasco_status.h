//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TAPASCO).
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
 *  @file	tapasco_status.h
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef TAPASCO_STATUS_H__
#define TAPASCO_STATUS_H__

#include <tapasco.h>
#include <tapasco_global.h>

typedef struct tapasco_status tapasco_status_t;
struct tapasco_status {
	tapasco_func_id_t id[TAPASCO_MAX_INSTANCES];
	uint32_t gen_ts;
	uint32_t vivado_version;
	uint32_t tapasco_version;
	uint32_t host_clk;
	uint32_t mem_clk;
	uint32_t design_clk;
	uint32_t num_intcs;
	uint32_t cap0_flags;
};

typedef enum {
  TAPASCO_CAP0_ATSPRI 					   	= (1 << 0),
  TAPASCO_CAP0_ATSCHECK 					= (1 << 1),
} tapasco_capabilities_0_t;

#define TAPASCO_VERSION_MAJOR(v) 				((v) >> 16)
#define TAPASCO_VERSION_MINOR(v) 				((v) & 0xFFFF)

tapasco_res_t tapasco_status_init(tapasco_status_t **status);
void tapasco_status_deinit(tapasco_status_t *status);
int tapasco_status_has_capability_0(const tapasco_status_t *status,
		tapasco_capabilities_0_t caps);
uint32_t tapasco_status_get_vivado_version(const tapasco_status_t *status);
uint32_t tapasco_status_get_tapasco_version(const tapasco_status_t *status);
uint32_t tapasco_status_get_gen_ts(const tapasco_status_t *status);
uint32_t tapasco_status_get_host_clk(const tapasco_status_t *status);
uint32_t tapasco_status_get_mem_clk(const tapasco_status_t *status);
uint32_t tapasco_status_get_design_clk(const tapasco_status_t *status);

#endif /* TAPASCO_STATUS_H__ */
