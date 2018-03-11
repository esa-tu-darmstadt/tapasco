//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
//! @file	tapasco_address_map.c
//! @brief	Resolves logical registers to concrete AXI addresses on the
//!		Zynq platform (implementation of micro API).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <assert.h>
#include <tapasco_types.h>
#include <tapasco_global.h>
#include <tapasco_regs.h>
#include <tapasco_device.h>
#include <platform.h>
#include <platform_context.h>
#include <platform_addr_map.h>

#define FIRST_ARG_OFFSET 					0x20
#define ARG_OFFSET						0x10
#define GIER_OFFSET						0x04
#define IER_OFFSET						0x08
#define IAR_OFFSET						0x0c
#define RET_OFFSET						0x10

static tapasco_handle_t _bases[TAPASCO_NUM_SLOTS] = { 0 };
 

static inline tapasco_handle_t base_addr(tapasco_dev_ctx_t *dev_ctx,
		tapasco_slot_id_t const slot_id)
{
	assert(slot_id < TAPASCO_NUM_SLOTS);
	platform_ctx_t *pctx = tapasco_device_platform(dev_ctx);
	platform_addr_map_t *am = platform_context_addr_map(pctx);
	if (! _bases[slot_id]) {
		platform_addr_map_get_slot_base(am, slot_id, &_bases[slot_id]);
	}
	return _bases[slot_id];
}

tapasco_handle_t tapasco_regs_arg_register(
		tapasco_dev_ctx_t *dev_ctx,
		tapasco_slot_id_t const slot_id,
		size_t const arg_idx)
{
	tapasco_handle_t base = base_addr(dev_ctx, slot_id);
	return base
	     + FIRST_ARG_OFFSET
	     + arg_idx * ARG_OFFSET;
}

tapasco_handle_t tapasco_regs_named_register(tapasco_dev_ctx_t *dev_ctx,
		tapasco_slot_id_t const slot_id,
		tapasco_reg_t const reg)
{
	tapasco_handle_t const base = base_addr(dev_ctx, slot_id);
	switch (reg) {
	case TAPASCO_REG_CTRL:
		return base;
	case TAPASCO_REG_GIER:
		return base + GIER_OFFSET;
	case TAPASCO_REG_IER:
		return base + IER_OFFSET;
	case TAPASCO_REG_IAR:
		return base + IAR_OFFSET;
	case TAPASCO_REG_RET:
		return base + RET_OFFSET;
	default:
		return 0;
	}
}
