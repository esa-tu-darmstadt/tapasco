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
//! @file	platform_perfc.h
//! @brief	Performance counters interface for libplatform.
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo application library.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef PLATFORM_PERFC_H__
#define PLATFORM_PERFC_H__

#include "platform_types.h"

#ifdef _PC
	#undef _PC
#endif

#define PLATFORM_PERFC_COUNTERS \
	_PC(signals_received) \
	_PC(waiting_for_slot) \
	_PC(slot_interrupts_active) \
	_PC(sem_wait_error) \
	_PC(sem_post_error)

#ifndef NPERFC
	const char *platform_perfc_tostring(platform_dev_id_t const dev_id);
	#define _PC(name) \
	void platform_perfc_ ## name ## _inc(platform_dev_id_t dev_id); \
	void platform_perfc_ ## name ## _add(platform_dev_id_t dev_id, int const v); \
	long platform_perfc_ ## name ## _get(platform_dev_id_t dev_id); \
	void platform_perfc_ ## name ## _set(platform_dev_id_t dev_id, int const v); \

	PLATFORM_PERFC_COUNTERS
	#undef _PC
#else /* NPERFC */
	static inline
	const char *platform_perfc_tostring(platform_dev_id_t const dev_id) { return ""; }
	#define _PC(name) \
	inline static void platform_perfc_ ## name ## _inc(platform_dev_id_t dev_id) {} \
	inline static void platform_perfc_ ## name ## _add(platform_dev_id_t dev_id, int const v) {} \
	inline static long platform_perfc_ ## name ## _get(platform_dev_id_t dev_id) { return 0; } \
	inline static void platform_perfc_ ## name ## _set(platform_dev_id_t dev_id, int const v) {}

	PLATFORM_PERFC_COUNTERS
	#undef _PC
#endif /* NPERFC */
#endif /* PLATFORM_PERFC_H__ */
