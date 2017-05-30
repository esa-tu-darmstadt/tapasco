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
/**
 *  @file	tapasco_status.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifdef __cplusplus
	#include <cstdint>
	#include <cstring>
#else
	#include <stdint.h>
	#include <string.h>
#endif
#include <platform.h>
#include <tapasco_status.h>
#include <tapasco_logging.h>
#include <tapasco_errors.h>

static platform_ctl_addr_t const TAPASCO_STATUS_SLOT_BASE   = 0x100;
static platform_ctl_addr_t const TAPASCO_STATUS_SLOT_OFFSET = 0x010;

static tapasco_res_t read_tapasco_status(tapasco_status_t **status)
{
	uint32_t d = 0;
	LOG(LALL_STATUS, "creating status info");
	platform_ctl_addr_t h = platform_address_get_special_base(
			PLATFORM_SPECIAL_CTL_STATUS);
	LOG(LALL_STATUS, "status address = 0x%08lx", (unsigned long)h);
	// check magic number
	platform_read_ctl(h, sizeof(d), &d, PLATFORM_CTL_FLAGS_NONE);
	if (d != 0xE5AE1337) {
		ERR("no TPC bitstream detected, load bitstream and restart");
		return TAPASCO_ERR_STATUS_CORE_NOT_FOUND;
	}

	h += TAPASCO_STATUS_SLOT_BASE;
	for (int i = 0; i < TAPASCO_MAX_INSTANCES; ++i, h += TAPASCO_STATUS_SLOT_OFFSET) {
		platform_read_ctl(h, sizeof(d), &d, PLATFORM_CTL_FLAGS_NONE);
		LOG(LALL_STATUS, "slot %u has kernel with id %u", i, d);
		(*status)->id[i] = d;
	}
	return TAPASCO_SUCCESS;
}

tapasco_res_t tapasco_status_init(tapasco_status_t **status)
{
	*status = (tapasco_status_t *)malloc(sizeof(**status));
	if (! status) return TAPASCO_ERR_OUT_OF_MEMORY;
	memset(*status, 0, sizeof(**status));
	tapasco_res_t ok = read_tapasco_status(status);
	if (ok != TAPASCO_SUCCESS) {
		ERR("initialization failed");
		free(*status);
		*status = NULL;
	}
	return ok;
}

void tapasco_status_deinit(tapasco_status_t *status)
{
	LOG(LALL_STATUS, "releasing status info");
	free(status);
}
