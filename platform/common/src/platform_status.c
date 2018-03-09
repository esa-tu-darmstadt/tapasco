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
 *  @file	platform_status.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <stdint.h>
#include <string.h>
#include <platform.h>
#include <platform_status.h>
#include <platform_logging.h>
#include <platform_errors.h>

#ifndef PLATFORM_API_TAPASCO_STATUS_BASE
#error "PLATFORM_API_TAPASCO_STATUS_BASE is not defined - set to base addr "
       "of TaPaSCo status core in libplatform implementation"
#endif

static platform_ctl_addr_t const PLATFORM_STATUS_SLOT_BASE   = 0x100;
static platform_ctl_addr_t const PLATFORM_STATUS_SLOT_OFFSET = 0x010;

struct platform_status {
	uint32_t id[PLATFORM_NUM_SLOTS];
	uint32_t mem[PLATFORM_NUM_SLOTS];
	uint32_t gen_ts;
	uint32_t vivado_version;
	uint32_t platform_version;
	uint32_t host_clk;
	uint32_t mem_clk;
	uint32_t design_clk;
	uint32_t num_intcs;
	uint32_t cap0_flags;
};

static
platform_res_t read_platform_status(platform_ctx_t *ctx,
		platform_status_t **status)
{
	uint32_t d = 0;
	LOG(LPLL_STATUS, "creating status info");
	platform_ctl_addr_t h = PLATFORM_API_TAPASCO_STATUS_BASE;
	LOG(LPLL_STATUS, "status addr = 0x%08lx", (unsigned long)h);
	// check magic number
	platform_read_ctl(ctx, h, sizeof(d), &d, PLATFORM_CTL_FLAGS_NONE);
	if (d != 0xE5AE1337) {
		ERR("no PLATFORM bitstream detected, load bitstream and restart");
		return PERR_STATUS_CORE_NOT_FOUND;
	}
	// read number of INTCs
	platform_read_ctl(ctx, h + sizeof(uint32_t), sizeof(d),
			&(*status)->num_intcs, PLATFORM_CTL_FLAGS_NONE);
	// read capabilities
	platform_read_ctl(ctx, h + 2 * sizeof(uint32_t), sizeof(d),
			&(*status)->cap0_flags, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "cap-0 bitfield: 0x%08x", (*status)->cap0_flags);
	if ((*status)->cap0_flags == 0x13371337) // filter old dead register val
		(*status)->cap0_flags = 0;
	// read vivado version
	platform_read_ctl(ctx, h + 4 * sizeof(uint32_t), sizeof(d),
			&(*status)->vivado_version, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "vivado version: 0x%08x (%d.%d)",
			(*status)->vivado_version,
			PLATFORM_VERSION_MAJOR((*status)->vivado_version),
			PLATFORM_VERSION_MINOR((*status)->vivado_version));
	// read platform version
	platform_read_ctl(ctx, h + 5 * sizeof(uint32_t), sizeof(d),
			&(*status)->platform_version, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "platform version: 0x%08x (%d.%d)",
			(*status)->platform_version,
			PLATFORM_VERSION_MAJOR((*status)->platform_version),
			PLATFORM_VERSION_MINOR((*status)->platform_version));
	// read timestamp
	platform_read_ctl(ctx, h + 6 * sizeof(uint32_t), sizeof(d),
			&(*status)->gen_ts, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "generated timestamp: 0x%08x", (*status)->gen_ts);
	// read host clk
	platform_read_ctl(ctx, h + 7 * sizeof(uint32_t), sizeof(d),
			&(*status)->host_clk, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "host   clock: % 3d MHz", (*status)->host_clk);
	// read mem clk
	platform_read_ctl(ctx, h + 8 * sizeof(uint32_t), sizeof(d),
			&(*status)->mem_clk, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "memory clock: % 3d MHz", (*status)->mem_clk);
	// read design clk
	platform_read_ctl(ctx, h + 9 * sizeof(uint32_t), sizeof(d),
			&(*status)->design_clk, PLATFORM_CTL_FLAGS_NONE);
	LOG(LPLL_STATUS, "design clock: % 3d MHz", (*status)->design_clk);

	h += PLATFORM_STATUS_SLOT_BASE;
	for (int i = 0; i < PLATFORM_NUM_SLOTS; ++i, h += PLATFORM_STATUS_SLOT_OFFSET) {
		platform_read_ctl(ctx, h, sizeof(d), &d, PLATFORM_CTL_FLAGS_NONE);
		LOG(LPLL_STATUS, "slot %u has kernel with id %u", i, d);
		(*status)->id[i] = d;

		if ((*status)->cap0_flags & PLATFORM_CAP0_PE_LOCAL_MEM) {
			platform_read_ctl(ctx, h + 4, sizeof((*status)->mem[i]),
					&(*status)->mem[i],
					PLATFORM_CTL_FLAGS_NONE);
			if ((*status)->mem[i] > 0) {
				LOG(LPLL_STATUS, "slot %u has %u bytes of memory",
						i, (*status)->mem[i]);
			}
		}
	}
	return PLATFORM_SUCCESS;
}

int platform_status_has_capability_0(const platform_status_t *status,
		platform_capabilities_0_t caps)
{
	return (status->cap0_flags & caps) > 0 ? 1 : 0;
}

platform_res_t platform_status_init(platform_ctx_t *ctx,
		platform_status_t **status)
{
	*status = (platform_status_t *)malloc(sizeof(**status));
	if (! status) return PERR_OUT_OF_MEMORY;
	memset(*status, 0, sizeof(**status));
	platform_res_t ok = read_platform_status(ctx, status);
	if (ok != PLATFORM_SUCCESS) {
		ERR("initialization failed: %s (%d)", platform_strerror(ok), ok);
		free(*status);
		*status = NULL;
	}
	return ok;
}

void platform_status_deinit(platform_ctx_t *ctx, platform_status_t *status)
{
	if (status) {
		LOG(LPLL_STATUS, "releasing status info");
		free(status);
	}
}

uint32_t platform_status_get_vivado_version(const platform_status_t *status)
{
	return status->vivado_version;
}

uint32_t platform_status_get_platform_version(const platform_status_t *status)
{
	return status->platform_version;
}

uint32_t platform_status_get_gen_ts(const platform_status_t *status)
{
	return status->gen_ts;
}

uint32_t platform_status_get_host_clk(const platform_status_t *status)
{
	return status->host_clk;
}

uint32_t platform_status_get_mem_clk(const platform_status_t *status)
{
	return status->mem_clk;
}

uint32_t platform_status_get_design_clk(const platform_status_t *status)
{
	return status->design_clk;
}

uint32_t platform_status_get_slot_id(const platform_status_t *status,
		platform_slot_id_t const slot_id)
{
#ifndef NDEBUG
	if (slot_id >= PLATFORM_NUM_SLOTS)
		return PERR_ADDR_INVALID_SLOT_ID;
#endif
	return status->id[slot_id];
}

uint32_t platform_status_get_slot_mem(const platform_status_t *status,
		platform_slot_id_t const slot_id)
{
#ifndef NDEBUG
	if (slot_id >= PLATFORM_NUM_SLOTS)
		return PERR_ADDR_INVALID_SLOT_ID;
#endif
	return status->mem[slot_id];
}
