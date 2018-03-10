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
#include <assert.h>
#include <string.h>
#include <platform_info.h>
#include <platform_context.h>
#include <platform_logging.h>
#include <platform_addr_map.h>
#include <platform.h>

#define PLATFORM_STATUS_REGISTERS \
	_X(REG_MAGIC_ID ,		0x0000 ,	magic_id) \
	_X(REG_NUM_INTC ,		0x0004 ,	num_intc) \
	_X(REG_CAPS0 ,			0x0008 ,	caps0) \
	_X(REG_VIVADO_VERSION ,		0x0010 ,	vivado_version) \
	_X(REG_PLATFORM_VERSION ,	0x0014 ,	tapasco_version) \
	_X(REG_COMPOSE_TS ,		0x0018 ,	compose_ts) \
	_X(REG_HOST_CLOCK ,		0x001c ,	clock.host) \
	_X(REG_DESIGN_CLOCK ,		0x0020 ,	clock.design) \
	_X(REG_MEMORY_CLOCK ,		0x0024 ,	clock.memory)

#ifdef _X
	#undef _X
#endif

#define _X(constant, code, field) \
	constant = code,
typedef enum {
	PLATFORM_STATUS_REGISTERS
} platform_status_reg_t;
#undef _X

#define REG_KERNEL_ID_START					0x0100
#define	REG_LOCAL_MEM_START					0x0800

static platform_ctx_t const *_last_ctx = NULL;
static platform_info_t _last_info;

static
platform_res_t read_info_from_status_core(platform_ctx_t const *p,
		platform_info_t *info)
{
	platform_ctl_addr_t status;
	platform_res_t r = platform_address_get_component_base(p,
			PLATFORM_COMPONENT_STATUS, &status);
	if (r != PLATFORM_SUCCESS) {
		ERR("could not read status core: %s (%d)",
				platform_strerror(r), r);
		return r;
	}
#ifdef _X
	#undef _X
#endif
#define _X(_name, _val, _field) \
	r = platform_read_ctl(p, status + _name, sizeof(info->_field), \
			&(info->_field), PLATFORM_CTL_FLAGS_NONE); \
	if (r != PLATFORM_SUCCESS) { \
		ERR("could not read _name: %s (%d)", platform_strerror(r), r); \
		return r; \
	}
	PLATFORM_STATUS_REGISTERS
#undef _X
	for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
		platform_ctl_addr_t const rk = status + REG_KERNEL_ID_START +
				s * sizeof(info->kernel_id[s]);
		r = platform_read_ctl(p, rk, sizeof(uint32_t),
				&(info->kernel_id[s]), PLATFORM_CTL_FLAGS_NONE);
		if (r != PLATFORM_SUCCESS) {
			ERR("could not read kernel id at slot %lu: %s (%d)",
					(unsigned long)s,
					platform_strerror(r), r);
			return r;
		}
		platform_ctl_addr_t const rm = status + REG_LOCAL_MEM_START +
				s * sizeof(info->kernel_id[s]);
		r = platform_read_ctl(p, rm, sizeof(info->memory[s]),
				&(info->memory[s]), PLATFORM_CTL_FLAGS_NONE);
		if (r != PLATFORM_SUCCESS) {
			ERR("could not read memory id at slot %lu: %s (%d)",
					(unsigned long)s,
					platform_strerror(r), r);
			return r;
		}
	}
	return PLATFORM_SUCCESS;
}

platform_res_t platform_info(platform_ctx_t const *ctx,
		platform_info_t *info)
{
	LOG(LPLL_STATUS, "reading status core information ...");
	assert(ctx);
	assert(info);
	platform_res_t r = PLATFORM_SUCCESS;
	if (_last_ctx != ctx) {
		_last_ctx = ctx;
		r = read_info_from_status_core(ctx, &_last_info);
	}
	if (r == PLATFORM_SUCCESS) {
		LOG(LPLL_STATUS, "read device info successfully, copying ...");
		memcpy(info, &_last_info, sizeof(*info));
	}
	return r;
}

static inline
void log_device_info(platform_info_t const *info)
{
#ifndef NDEBUG
#ifdef _X
	#undef _X
#endif
#define _X(_name, _val, _field) \
	LOG(LPLL_STATUS, "_field = _val");
	PLATFORM_STATUS_REGISTERS
#undef _X
	for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
		if (info->kernel_id[s])
			LOG(LPLL_STATUS, "slot #%lu: kernel id 0x%08x (%u)",
					(unsigned long)s,
					(unsigned)info->kernel_id[s],
					(unsigned long)info->kernel_id[s]);
		if (info->memory[s])
			LOG(LPLL_STATUS, "slot #%lu: memory    0x%08x (%u)",
					(unsigned long)s,
					(unsigned)info->memory[s],
					(unsigned long)info->memory[s]);
	}
#endif
}
