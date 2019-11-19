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

#include "tlkm_device.h"

#ifdef _PC
#undef _PC
#endif

#define TLKM_PERFC_COUNTERS                                                    \
	_PC(signals_read)                                                      \
	_PC(signals_written)                                                   \
	_PC(signals_signaled)                                                  \
	_PC(control_ioctls)                                                    \
	_PC(total_alloced_mem)                                                 \
	_PC(total_freed_mem)                                                   \
	_PC(total_usr2dev_transfers)                                           \
	_PC(total_dev2usr_transfers)                                           \
	_PC(total_ctl_writes)                                                  \
	_PC(total_ctl_reads)                                                   \
	_PC(link_width)                                                        \
	_PC(link_speed)                                                        \
	_PC(dma_reads)                                                         \
	_PC(dma_writes)                                                        \
	_PC(outstanding)                                                       \
	_PC(outstanding_high_watermark)                                        \
	_PC(limited_by_read_sz)                                                \
	_PC(limited_by_outbuf_sz)                                              \
	_PC(indices_in_order)                                                  \
	_PC(indices_reversed)                                                  \
	_PC(irq_error_already_pending)                                         \
	_PC(total_irqs)

#ifndef NPERFC
#include <linux/types.h>

#define _PC(name)                                                              \
	void tlkm_perfc_##name##_inc(dev_id_t dev_id);                         \
	void tlkm_perfc_##name##_add(dev_id_t dev_id, int const v);            \
	int tlkm_perfc_##name##_get(dev_id_t dev_id);                          \
	void tlkm_perfc_##name##_set(dev_id_t dev_id, int const v);

TLKM_PERFC_COUNTERS
#undef _PC
#else /* NPERFC */
#define _PC(name)                                                              \
	inline static void tlkm_perfc_##name##_inc(dev_id_t dev_id)            \
	{                                                                      \
	}                                                                      \
	inline static void tlkm_perfc_##name##_add(dev_id_t dev_id,            \
						   int const v)                \
	{                                                                      \
	}                                                                      \
	inline static int tlkm_perfc_##name##_get(dev_id_t dev_id)             \
	{                                                                      \
		return 0;                                                      \
	}                                                                      \
	inline static void tlkm_perfc_##name##_set(dev_id_t dev_id,            \
						   int const v)                \
	{                                                                      \
	}

TLKM_PERFC_COUNTERS
#undef _PC
#endif /* NPERFC */
#endif /* TLKM_PERFC_H__ */
