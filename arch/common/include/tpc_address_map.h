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
//! @file	tpc_address_map.h
//! @brief	Common TPC API implementation fragment:
//!		Provides standard API to resolve function registers to AXI
//!		addresses. Supporting file for re-use.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TPC_ADDRESS_MAP_H__
#define __TPC_ADDRESS_MAP_H__

#include <tpc_api.h>

/** Register space address type (opaque). */
typedef uint32_t tpc_reg_addr_t;

/** Named registers at each function instance. */
typedef enum {
	/** Base address of first register set. */
	TPC_FUNC_REG_BASE,
	/** Control register (start). */
	TPC_FUNC_REG_CONTROL,
	/** Function interrupt acknowledge register (if any). */
	TPC_FUNC_REG_IAR,
	/** Register with return value of function (if any). */
	TPC_FUNC_REG_RETURN
} tpc_func_reg_t;

/**
 * Returns register space address of the arg_idx'th argument register
 * of the function in slot slot_id.
 * @param dev_ctx FPGA device context.
 * @param slot_id Slot id.
 * @param arg_idx Index of argument.
 * @return Register space address of arg register.
 **/
tpc_reg_addr_t tpc_address_map_func_arg_register(tpc_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, uint32_t const arg_idx);

/**
 * Returns the register space address of the given named register of the
 * function in slot slot_id.
 * @param dev_ctx FPGA device context.
 * @param slot_id Slot id.
 * @param reg Named register to resolve.
 * @return Register space address > 0 if found.
 **/
tpc_reg_addr_t tpc_address_map_func_reg(tpc_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, tpc_func_reg_t const reg);

#endif /* __TPC_ADDRESS_MAP_H__ */


