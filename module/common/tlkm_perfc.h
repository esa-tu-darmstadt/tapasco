//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
//! @file	tlkm_module.c
//! @brief	Performance counters interface for TaPaSCo:
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo loadable kernel module (TLKM).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TLKM_PERFC_H__
#define TLKM_PERFC_H__

#include "tlkm_devices.h"

#ifdef _PC
	#undef _PC
#endif

#define TLKM_PERFC_COUNTERS \
	_PC(control_read) \
	_PC(control_written) \
	_PC(control_signaled) \
	_PC(total_mem) \
	_PC(dma_transfers) \
	_PC(dma_bytes)

#ifndef NDEBUG
#include <linux/types.h>

#define _PC(name) \
void tlkm_perfc_ ## name ## _inc(dev_id_t dev_id); \
int  tlkm_perfc_ ## name ## _get(dev_id_t dev_id);

TLKM_PERFC_COUNTERS
#undef _PC

#else /* NDEBUG */

#define _PC(name) \
inline static void tlkm_perfc_ ## name ## _inc(dev_id_t dev_id) {} \
inline static int  tlkm_perfc_ ## name ## _get(dev_id_t dev_id) { return 0; } \

TLKM_PERFC_COUNTERS
#undef _PC

#endif /* NDEBUG */
#endif /* TLKM_PERFC_H__ */
