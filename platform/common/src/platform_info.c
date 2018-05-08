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
#include <platform_caps.h>
#include <platform_devctx.h>
#include <platform_logging.h>
#include <platform_addr_map.h>
#include <platform.h>
#include <zynq/zynq.h>

#define PLATFORM_STATUS_REGISTERS \
	_X(REG_MAGIC_ID ,		0x0000 ,	magic_id) \
	_X(REG_NUM_INTC ,		0x0004 ,	num_intc) \
	_X(REG_CAPS0 ,			0x0008 ,	caps0) \
	_X(REG_VIVADO_VERSION ,		0x0010 ,	version.vivado) \
	_X(REG_PLATFORM_VERSION ,	0x0014 ,	version.tapasco) \
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
#define REG_LOCAL_MEM_START					0x0104
#define REG_SLOT_OFFSET						0x0010
#define REG_PLATFORM_BASE_START					0x1000
#define	REG_ARCH_BASE_START \
		(REG_PLATFORM_BASE_START + sizeof(uint64_t) * PLATFORM_NUM_SLOTS)

#define STRINGIFY(f)					#f

static platform_info_t _info[PLATFORM_MAX_DEVS];

static
platform_res_t read_info_from_status_core(platform_devctx_t const *p,
		platform_info_t *info)
{
	platform_res_t r;
	platform_dev_id_t dev_id = p->dev_id;
	platform_ctl_addr_t status = p->platform.status.base;
#ifdef _X
	#undef _X
#endif
#define _X(_name, _val, _field) \
	r = platform_read_ctl(p, status + _name, sizeof(info->_field), \
			&(info->_field), PLATFORM_CTL_FLAGS_NONE); \
	if (r != PLATFORM_SUCCESS) { \
		DEVERR(dev_id, "could not read " STRINGIFY(_name) ": %s (" PRIres ")", platform_strerror(r), r); \
		return r; \
	} \
	DEVLOG(dev_id, LPLL_STATUS, "read " STRINGIFY(_name) ": %#08x", info->_field);
	PLATFORM_STATUS_REGISTERS
#undef _X
	for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
		platform_ctl_addr_t const rk = status + REG_KERNEL_ID_START + s * REG_SLOT_OFFSET;
		r = platform_read_ctl(p, rk, sizeof(uint32_t), &(info->composition.kernel[s]), 0);
		if (r != PLATFORM_SUCCESS) {
			DEVERR(dev_id, "could not read kernel id at slot " PRIslot ": %s (" PRIres ")",
					s, platform_strerror(r), r);
			return r;
		}
		platform_ctl_addr_t const rm = status + REG_LOCAL_MEM_START + s * REG_SLOT_OFFSET;
		r = platform_read_ctl(p, rm, sizeof(info->composition.memory[s]),
				&(info->composition.memory[s]), PLATFORM_CTL_FLAGS_NONE);
		if (r != PLATFORM_SUCCESS) {
			DEVERR(dev_id, "could not read memory at slot " PRIslot ": %s (" PRIres ")",
					s, platform_strerror(r), r);
			return r;
		}

		if (info->caps0 & PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP) {
			platform_ctl_addr_t const pb = status +
					REG_PLATFORM_BASE_START +
					s * sizeof(uint64_t);
			r = platform_read_ctl(p, pb,
					sizeof(info->base.platform[s]),
					&(info->base.platform[s]),
					PLATFORM_CTL_FLAGS_NONE);
			if (r != PLATFORM_SUCCESS) {
				DEVERR(dev_id, "could not read platform base " PRIslot ": %s (" PRIres ")",
						s, platform_strerror(r), r);
				return r;
			} 

			platform_ctl_addr_t const ab = status + REG_ARCH_BASE_START + s * sizeof(uint64_t);
			r = platform_read_ctl(p, ab, sizeof(info->base.arch[s]), &(info->base.arch[s]), 0);
			if (r != PLATFORM_SUCCESS) {
				DEVERR(dev_id, "could not read platform base " PRIslot ": %s (" PRIres ")",
						s, platform_strerror(r), r);
				return r;
			} 
		} else {
			DEVERR(dev_id, "loaded bitstream does not support dynamic address map - "
			    "please use a libplatform version < 1.5 with this bitstream");
			return PERR_INCOMPATIBLE_BITSTREAM;
		}

	}
	return PLATFORM_SUCCESS;
}

inline
void log_device_info(platform_dev_id_t const dev_id, platform_info_t const *info)
{
#ifndef NDEBUG
#ifdef _X
	#undef _X
#endif
#define _X(name, value, field) \
	DEVLOG(dev_id, LPLL_STATUS, "" STRINGIFY(field) " = %#08lx (%u)", (unsigned long)info->field, (unsigned long)info->field);
	PLATFORM_STATUS_REGISTERS
#undef _X
	for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
		if (info->composition.kernel[s])
			DEVLOG(dev_id, LPLL_STATUS, "slot #" PRIslot ": k %#08x (" PRIkernel ")",
					s, (unsigned)info->composition.kernel[s], info->composition.kernel[s]);
		if (info->composition.memory[s])
			DEVLOG(dev_id, LPLL_STATUS, "slot #" PRIslot ": m %#08x (%zu)",
					s, (unsigned)info->composition.memory[s], (size_t)info->composition.memory[s]);
		if (info->base.platform[s])
			DEVLOG(dev_id, LPLL_STATUS, "plat #" PRIslot ":   " PRIctl, s, info->base.platform[s]);
		if (info->base.arch[s])
			DEVLOG(dev_id, LPLL_STATUS, "arch #" PRIslot ":   " PRIctl, s, info->base.arch[s]);
	}
#endif
}

platform_res_t platform_info(platform_devctx_t const *ctx, platform_info_t *info)
{
	platform_res_t r = PLATFORM_SUCCESS;
	platform_dev_id_t dev_id = ctx->dev_id;
	assert(ctx);
	assert(info);
	assert(dev_id < PLATFORM_MAX_DEVS);
	if (! _info[dev_id].magic_id) {
		DEVLOG(dev_id, LPLL_STATUS, "reading device info ...");
		r = read_info_from_status_core(ctx, &_info[dev_id]);
		if (r == PLATFORM_SUCCESS) {
			DEVLOG(dev_id, LPLL_STATUS, "read device info successfully");
			log_device_info(dev_id, &_info[dev_id]);
		}
	}
	if (r == PLATFORM_SUCCESS) {
		memcpy(info, &_info[dev_id], sizeof(*info));
	}
	return r;
}
