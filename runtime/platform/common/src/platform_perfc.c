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
//! @file	platform_perfc.c
//! @brief	Performance counters interface for libplatform.
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo application library.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <stdio.h>
#include "platform_perfc.h"

#ifndef NPERFC

static
struct platform_perfc_t {
#define _PC(NAME) 	_Atomic(long int) pc_ ## NAME[PLATFORM_MAX_DEVS];
	PLATFORM_PERFC_COUNTERS
#undef _PC
} platform_perfc;

#define _PC(name) \
void platform_perfc_ ## name ## _inc(platform_dev_id_t dev_id) \
{ \
	platform_perfc.pc_ ## name[dev_id]++; \
} \
\
void platform_perfc_ ## name ## _add(platform_dev_id_t dev_id, int const v) \
{ \
	platform_perfc.pc_ ## name[dev_id] += v; \
} \
\
long int platform_perfc_ ## name ## _get(platform_dev_id_t dev_id) \
{ \
	return platform_perfc.pc_ ## name[dev_id]; \
} \
\
void platform_perfc_ ## name ## _set(platform_dev_id_t dev_id, int const v) \
{ \
	platform_perfc.pc_ ## name[dev_id] = v; \
}

PLATFORM_PERFC_COUNTERS
#undef _PC

#ifndef STR
	#define	STR(v)			#v
#endif

const char *platform_perfc_tostring(platform_dev_id_t const dev_id)
{
	static char _buf[1024];
#define _PC(name) "%40s:\t%8ld\n"
	const char *const fmt = PLATFORM_PERFC_COUNTERS "\n%c";
#undef _PC
#define _PC(name) STR(name), platform_perfc_ ## name ## _get(dev_id),
	snprintf(_buf, 1024, fmt, PLATFORM_PERFC_COUNTERS 0);
	return _buf;
}

#endif
