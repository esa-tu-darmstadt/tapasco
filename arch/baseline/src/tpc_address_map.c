//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	tpc_address_map.c
//! @brief	Resolves logical registers to concrete AXI addresses on the
//!		Zynq platform (implementation of micro API).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <assert.h>
#include <tpc_address_map.h>
#include <platform_api.h>

#define TPC_MAX_INSTANCES			128

static platform_ctl_addr_t _bases[TPC_MAX_INSTANCES] = { -1 };

static inline tpc_reg_addr_t base_addr(uint32_t const slot_id) {
	assert(slot_id < TPC_MAX_INSTANCES);
	tpc_reg_addr_t ret = _bases[slot_id];
	if (ret == -1)
		ret = _bases[slot_id] = platform_address_get_slot_base(slot_id, 0);
	assert(ret != -1);
	return ret;
}

tpc_reg_addr_t tpc_address_map_func_arg_register(tpc_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, uint32_t const arg_idx) {
	//! @todo Remove this stuff as soon as Vivado HLS can handle offsets correctly.
	return base_addr(slot_id) //platform_address_get_slot_base(slot_id, 0)
	     + 0x20			// first arg is at this offset from base
	     + arg_idx * 0x10;		// one byte seems to be reserved after each
}

tpc_reg_addr_t tpc_address_map_func_reg(tpc_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, tpc_func_reg_t const reg) {
	switch (reg) {
	case TPC_FUNC_REG_BASE:
	case TPC_FUNC_REG_CONTROL:
		return platform_address_get_slot_base(slot_id, 0);
	case TPC_FUNC_REG_IAR:
		return platform_address_get_slot_base(slot_id, 0) + 0x0c;
	case TPC_FUNC_REG_RETURN:
		return platform_address_get_slot_base(slot_id, 0) + 0x10;
	default:
		return 0;
	}
}
