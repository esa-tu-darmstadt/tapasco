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
#include <platform_errors.h>
#include <platform_logging.h>
#include <platform_addr_map.h>
#include <assert.h>

#ifndef PLATFORM_API_TAPASCO_STATUS_BASE
#error "PLATFORM_API_TAPASCO_STATUS_BASE is not defined - set to base addr "
       "of TaPaSCo status core in libplatform implementation"
#endif

struct platform_addr_map {
	platform_ctl_addr_t platform_base[PLATFORM_NUM_SLOTS];
	platform_ctl_addr_t arch_base[PLATFORM_NUM_SLOTS];
};

platform_res_t platform_addr_map_init(platform_addr_map_t **am)
{
	*am = (platform_addr_map_t *)malloc(sizeof(*am));
	if (! *am) {
		ERR("could not allocate memory for platform_addr_map_t");
		return PERR_OUT_OF_MEMORY;
	}

	size_t slot_id = 0;
	platform_res_t pres = PLATFORM_SUCCESS, ares = PLATFORM_SUCCESS;
	platform_ctl_addr_t pbase = PLATFORM_API_TAPASCO_STATUS_BASE +
			PLATFORM_ADDRESS_MAP_START;
	platform_ctl_addr_t abase = pbase + (PLATFORM_NUM_SLOTS * sizeof(uint64_t));
	int cont = 1;
	
	do {
		cont = 0;
		pres = platform_read_ctl(pbase, sizeof(pbase),
				&(*am)->platform_base[slot_id],
				PLATFORM_CTL_FLAGS_NONE);
		ares = platform_read_ctl(abase, sizeof(abase),
				&(*am)->arch_base[slot_id],
				PLATFORM_CTL_FLAGS_NONE);
		if (ares == PLATFORM_SUCCESS && pres == PLATFORM_SUCCESS) {
			LOG(LPLL_ADDR, "read base 0x%08lx for platform base #%zd "
					"from status core at 0x%08lx",
					(unsigned long)(*am)->platform_base[slot_id],
					(unsigned long)pbase, slot_id);
			LOG(LPLL_ADDR, "read base 0x%08lx for arch slot base #%zd "
					"from status core at 0x%08lx",
					(unsigned long)(*am)->arch_base[slot_id],
					(unsigned long)abase, slot_id);
			cont = (*am)->platform_base[slot_id] !=
					PLATFORM_ADDRESS_MAP_INVALID_BASE ||
					(*am)->arch_base[slot_id] !=
					PLATFORM_ADDRESS_MAP_INVALID_BASE;
			pbase += sizeof(uint64_t);
			abase += sizeof(uint64_t);
			++slot_id;
		}
	} while (pres == PLATFORM_SUCCESS && ares == PLATFORM_SUCCESS && cont &&
			++slot_id < PLATFORM_NUM_SLOTS);

	if (pres != PLATFORM_SUCCESS) {
		ERR("could not read at 0x%08lx, platform base for slot #%zd: %s (%d)",
				(unsigned long)pbase, slot_id,
				platform_strerror(pres), pres);
		return pres;
	}

	if (ares != PLATFORM_SUCCESS) {
		ERR("could not read at 0x%08lx, arch base for slot #%zd: %s (%d)",
				(unsigned long)abase, slot_id,
				platform_strerror(ares), ares);
		return ares;
	}
	LOG(LPLL_ADDR, "addr map successfully initialized");
	return PLATFORM_SUCCESS;
}

void platform_addr_map_deinit(platform_addr_map_t *am)
{
	free(am);
	LOG(LPLL_ADDR, "destroyed");
}

platform_ctl_addr_t platform_addr_map_get_slot_base(
		platform_addr_map_t const* am,
		platform_slot_id_t const slot_id)
{
	assert(am || "addr struct must not be NULL");
	if (slot_id >= 0 && slot_id < PLATFORM_NUM_SLOTS) {
		return am->arch_base[slot_id];
	}
	ERR("invalid slot_id %d: must be >= 0 and <= %d",
			slot_id, PLATFORM_NUM_SLOTS);
	return PLATFORM_ADDRESS_MAP_INVALID_BASE;
}

platform_ctl_addr_t platform_addr_map_get_special_base(
		platform_addr_map_t const* am,
		platform_special_ctl_t const ent)
{
	if (ent == PLATFORM_SPECIAL_CTL_STATUS) {
		return PLATFORM_API_TAPASCO_STATUS_BASE;
	}
	ERR("invalid ent_id %d: must be >= 0 and <= %d",
			ent, PLATFORM_NUM_SLOTS);
	return PLATFORM_ADDRESS_MAP_INVALID_BASE;
}
