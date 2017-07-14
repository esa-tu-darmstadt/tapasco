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
//! @file	tapasco_address_map_dummy.c
//! @brief	Dummy implementation of address map micro API to prevent linker
//!		errors.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <tapasco_address_map.h>

tapasco_reg_addr_t tapasco_address_map_func_arg_register(tapasco_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, uint32_t const arg_idx)
{
	return 0;
}

/**
 * Returns register space address of a special register in the architecture,
 * e.g., the interrupt controllers status register.
 * @param dev_ctx FPGA device context.
 * @param reg Register to resolve.
 * @return Register space address > 0 if found.
 **/
/*tapasco_reg_addr_t tapasco_address_map_special_reg(tapasco_dev_ctx_t *dev_ctx,
		tapasco_special_reg_t const reg)
{
	return 0;
}*/

/**
 * Returns the register space address of the given named register of the
 * function in slot slot_id.
 * @param dev_ctx FPGA device context.
 * @param slot_id Slot id.
 * @param reg Named register to resolve.
 * @return Register space address > 0 if found.
 **/
tapasco_reg_addr_t tapasco_address_map_func_reg(tapasco_dev_ctx_t *dev_ctx,
		uint32_t const slot_id, tapasco_func_reg_t const reg)
{
	return 0;
}
