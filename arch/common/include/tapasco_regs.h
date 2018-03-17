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
//! @file	tapasco_reg.h
//! @brief	Register defines for TaPaSCo control registers.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_REGS_H__
#define TAPASCO_REGS_H__

#include <tapasco_types.h>
#ifdef __cplusplus
#include <cstdlib>
#else
#include <stdlib.h>
#endif

/** Named control registers at each PE. */
typedef enum {
	/** Control register (start). */
	TAPASCO_REG_CTRL,
	/** Interrupt enable register. */
	TAPASCO_REG_IER,
	/** Global interrupt enable register. */
	TAPASCO_REG_GIER,
	/** Function interrupt acknowledge register. */
	TAPASCO_REG_IAR,
	/** Register with return value of function. */
	TAPASCO_REG_RET
} tapasco_reg_t;

/**
 * Returns register space address of the arg_idx'th argument register
 * of the processing element in slot slot_id.
 * @param dev_ctx FPGA device context.
 * @param slot_id Slot id.
 * @param arg_idx Index of argument.
 * @return Register space address of arg register.
 **/
tapasco_handle_t tapasco_regs_arg_register(
		tapasco_dev_ctx_t const *dev_ctx,
		tapasco_slot_id_t const slot_id,
		size_t const arg_idx);

/**
 * Returns the register space address of the given named register of the
 * processing element in slot slot_id.
 * @param dev_ctx FPGA device context.
 * @param slot_id Slot id.
 * @param reg Named register to resolve.
 * @return Register space address > 0 if found.
 **/
tapasco_handle_t tapasco_regs_named_register(tapasco_dev_ctx_t const *dev_ctx,
		tapasco_slot_id_t const slot_id,
		tapasco_reg_t const reg);

#endif /* TAPASCO_REGS_H__ */
