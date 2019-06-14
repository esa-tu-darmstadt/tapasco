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
//! @file	tapasco_perfc.c
//! @brief	Performance counters interface for libtapasco.
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo application library.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include "tapasco_perfc.h"

#ifndef NPERFC

#define TAPASCO_MAX_DEVS				32

static
struct tapasco_perfc_t {
#define _PC(NAME) 	_Atomic(long int) pc_ ## NAME[TAPASCO_MAX_DEVS];
	TAPASCO_PERFC_COUNTERS
#undef _PC
} tapasco_perfc;

#define _PC(name) \
void tapasco_perfc_ ## name ## _inc(tapasco_dev_id_t dev_id) \
{ \
	tapasco_perfc.pc_ ## name[dev_id]++; \
} \
\
void tapasco_perfc_ ## name ## _add(tapasco_dev_id_t dev_id, int const v) \
{ \
	tapasco_perfc.pc_ ## name[dev_id] += v; \
} \
\
long int tapasco_perfc_ ## name ## _get(tapasco_dev_id_t dev_id) \
{ \
	return tapasco_perfc.pc_ ## name[dev_id]; \
} \
\
void tapasco_perfc_ ## name ## _set(tapasco_dev_id_t dev_id, int const v) \
{ \
	tapasco_perfc.pc_ ## name[dev_id] = v; \
}

TAPASCO_PERFC_COUNTERS
#undef _PC

#ifndef STR
	#define	STR(v)			#v
#endif

const char *tapasco_perfc_tostring(tapasco_dev_id_t const dev_id)
{
	static char _buf[1024];
#define _PC(name) "%39s:\t%8ld\n"
	const char *const fmt = TAPASCO_PERFC_COUNTERS "\n%c";
#undef _PC
#define _PC(name) STR(name), tapasco_perfc_ ## name ## _get(dev_id),
	snprintf(_buf, 1024, fmt, TAPASCO_PERFC_COUNTERS 0);
	return _buf;
}

#endif
