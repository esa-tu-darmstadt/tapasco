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
//! @file	tlkm_perfc.c
//! @brief	Performance counters interface for TaPaSCo:
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo loadable kernel module (TLKM).
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <asm/atomic.h>
#include "tlkm_perfc.h"

#ifndef NDEBUG

static
struct tlkm_perfc_t {
#define _PC(NAME) 	atomic_t pc_ ## NAME;
	TLKM_PERFC_COUNTERS
} tlkm_perfc;

#undef _PC
#define _PC(name) \
void tlkm_perfc_ ## name ## _inc(void) \
{ \
	atomic_inc(&tlkm_perfc.pc_ ## name); \
} \
\
int tlkm_perfc_ ## name ## _get(void) \
{ \
	return atomic_read(&tlkm_perfc.pc_ ## name); \
}
TLKM_PERFC_COUNTERS
#undef _PC

#endif
