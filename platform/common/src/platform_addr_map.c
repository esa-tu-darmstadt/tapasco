//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
/**
 *  @file	platform_addr_map.c
 *  @brief	Supporting code for dynamic addr map.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <platform.h>
#include <platform_global.h>
#include <platform_context.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <platform_addr_map.h>
#include <assert.h>

#ifndef PLATFORM_API_TAPASCO_STATUS_BASE
#error "PLATFORM_API_TAPASCO_STATUS_BASE is not defined - set to base addr "
       "of TaPaSCo status core in libplatform implementation"
#endif

struct platform_addr_map {
	platform_info_t const *info;
};

platform_res_t platform_addr_map_init(platform_ctx_t *ctx,
		platform_info_t const *info,
		platform_addr_map_t **am)
{
	*am = (platform_addr_map_t *)malloc(sizeof(**am));
	if (! *am) {
		ERR("could not allocate memory for platform_addr_map_t");
		return PERR_OUT_OF_MEMORY;
	}
	(*am)->info = info;

	LOG(LPLL_ADDR, "address map successfully initialized");
	return PLATFORM_SUCCESS;
}

void platform_addr_map_deinit(platform_ctx_t *ctx, platform_addr_map_t *am)
{
	if (am) free(am);
	LOG(LPLL_ADDR, "destroyed");
}

platform_res_t platform_addr_map_get_slot_base(platform_addr_map_t const* am,
		platform_slot_id_t const slot_id,
		platform_ctl_addr_t *addr)
{
#ifndef NDEBUG
	assert(am || "addr struct must not be NULL");
	if (slot_id < 0 || slot_id >= PLATFORM_NUM_SLOTS) {
		ERR("invalid slot_id %d: must be >= 0 and <= %d",
				slot_id, PLATFORM_NUM_SLOTS);
		return PLATFORM_ADDRESS_MAP_INVALID_BASE;
	}
#endif
	*addr = am->info->base.arch[slot_id];
	return PLATFORM_SUCCESS;
}

inline
platform_res_t platform_address_get_slot_base(platform_ctx_t const *ctx,
		platform_slot_id_t const slot_id,
		platform_ctl_addr_t *addr)
{
	return platform_addr_map_get_slot_base(
			platform_context_addr_map(ctx), slot_id, addr);
}

platform_res_t platform_addr_map_get_component_base(
		platform_addr_map_t const* am,
		platform_component_t const comp_id,
		platform_ctl_addr_t *addr)
{
	if (comp_id == PLATFORM_COMPONENT_STATUS) {
		return PLATFORM_API_TAPASCO_STATUS_BASE;
	}
#ifndef NDEBUG
	if (comp_id < 0 || comp_id >= PLATFORM_NUM_SLOTS) {
		ERR("invalid comp_id %d: must be >= 0 and <= %d",
				comp_id, PLATFORM_NUM_SLOTS);
		return PERR_ADDR_INVALID_COMP_ID;
	}
	if (am->info->base.platform[comp_id] == 0) {
		ERR("no base defined for component #%lu", (unsigned long)comp_id);
		return PERR_COMPONENT_NOT_FOUND;
	}
#endif
	*addr = am->info->base.platform[comp_id];
	return PLATFORM_SUCCESS;
}

inline
platform_res_t platform_address_get_component_base(platform_ctx_t const *ctx,
		platform_component_t const ent,
		platform_ctl_addr_t *addr)
{
	return platform_addr_map_get_component_base(
			platform_context_addr_map(ctx), ent, addr);
}
