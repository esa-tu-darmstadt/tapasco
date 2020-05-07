/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo 
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
//! @file	tlkm_perfc.c
//! @brief	Performance counters interface for TaPaSCo:
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo loadable kernel module (TLKM).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/atomic.h>
#include "tlkm_ioctl_cmds.h"
#include "tlkm_perfc.h"

#ifndef NPERFC

static struct tlkm_perfc_t {
#define _PC(NAME) atomic_t pc_##NAME[TLKM_DEVS_SZ];
	TLKM_PERFC_COUNTERS
} tlkm_perfc;

#undef _PC
#define _PC(name)                                                              \
	void tlkm_perfc_##name##_inc(dev_id_t dev_id)                          \
	{                                                                      \
		atomic_inc(&tlkm_perfc.pc_##name[dev_id]);                     \
	}                                                                      \
                                                                               \
	void tlkm_perfc_##name##_add(dev_id_t dev_id, int const v)             \
	{                                                                      \
		atomic_add(v, &tlkm_perfc.pc_##name[dev_id]);                  \
	}                                                                      \
                                                                               \
	int tlkm_perfc_##name##_get(dev_id_t dev_id)                           \
	{                                                                      \
		return atomic_read(&tlkm_perfc.pc_##name[dev_id]);             \
	}                                                                      \
                                                                               \
	void tlkm_perfc_##name##_set(dev_id_t dev_id, int const v)             \
	{                                                                      \
		atomic_set(&tlkm_perfc.pc_##name[dev_id], v);                  \
	}

TLKM_PERFC_COUNTERS
#undef _PC

#endif
