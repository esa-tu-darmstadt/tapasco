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
//! @file	platform_logging.h
//! @brief	libplatform logging functions.
//!		Internal logging functions to produce debug output; levels are
//!		bitfield that can be turned on/off individually, with the
//!		exception of all-zeroes (critical error) and 1 (warning), which
//!		are always activated.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __PLATFORM_LOGGING_H__
#define __PLATFORM_LOGGING_H__

#define LIBPLATFORM_LOGLEVELS \
	_LPLL(INIT,	(1 << 1)) \
	_LPLL(MM,	(1 << 2)) \
	_LPLL(MEM,	(1 << 3)) \
	_LPLL(CTL,	(1 << 4)) \
	_LPLL(IRQ,	(1 << 5)) \
	_LPLL(DMA,	(1 << 6))

typedef enum {
#define _LPLL(name, level) LPLL_##name = level,
LIBPLATFORM_LOGLEVELS
#undef _LPLL
} platform_ll_t;

int platform_logging_init(void);
void platform_logging_exit(void);
#ifdef NDEBUG
inline void platform_log(platform_ll_t const level, char *fmt, ...) {}
#else
void platform_log(platform_ll_t const level, char *fmt, ...);
#endif

#define ERR(msg, ...)	 platform_log((platform_ll_t)0, "[%s] " msg "\n", __func__, ##__VA_ARGS__)
#define WRN(msg, ...)	 platform_log((platform_ll_t)1, "[%s] " msg "\n", __func__, ##__VA_ARGS__)
#define LOG(l, msg, ...) platform_log((platform_ll_t)(l), "[%s] " msg "\n", __func__, ##__VA_ARGS__)

#endif /* __PLATFORM_LOGGING_H__ */
