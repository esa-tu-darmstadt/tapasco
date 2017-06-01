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
//! @file	tapasco_address_map.c
//! @brief	Resolves logical registers to concrete AXI addresses on the
//!		Zynq platform (implementation of micro API).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <assert.h>
#include <tapasco_global.h>
#include <tapasco_address_map.h>
#include <platform.h>

static platform_ctl_addr_t _bases[TAPASCO_MAX_INSTANCES] = { 0 };

static inline tapasco_reg_addr_t base_addr(uint32_t const slot_id) {
	assert(slot_id < TAPASCO_MAX_INSTANCES);
	tapasco_reg_addr_t ret = _bases[slot_id];
	if (! ret)
		ret = (_bases[slot_id] = platform_address_get_slot_base(slot_id, 0));
	assert(slot_id == 0 || ret > 0);
	return ret;
}

tapasco_reg_addr_t tapasco_address_map_func_arg_register(tapasco_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, uint32_t const arg_idx) {
	//! @todo Remove this stuff as soon as Vivado HLS can handle offsets correctly.
	return base_addr(slot_id) //platform_address_get_slot_base(slot_id, 0)
	     + 0x20			// first arg is at this offset from base
	     + arg_idx * 0x10;		// one byte seems to be reserved after each
}

tapasco_reg_addr_t tapasco_address_map_func_reg(tapasco_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, tapasco_func_reg_t const reg) {
	switch (reg) {
	case TAPASCO_FUNC_REG_BASE:
	case TAPASCO_FUNC_REG_CONTROL:
		return platform_address_get_slot_base(slot_id, 0);
	case TAPASCO_FUNC_REG_IAR:
		return platform_address_get_slot_base(slot_id, 0) + 0x0c;
	case TAPASCO_FUNC_REG_RETURN:
		return platform_address_get_slot_base(slot_id, 0) + 0x10;
	default:
		return 0;
	}
}
