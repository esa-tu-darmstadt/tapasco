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
//! @file	tapasco_logging.h
//! @brief	libtapasco logging functions.
//!		Internal logging functions to produce debug output; levels are
//!		bitfield that can be turned on/off individually, with the
//!		exception of all-zeroes (critical error) and 1 (warning), which
//!		are always activated.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_LOGGING_H__
#define TAPASCO_LOGGING_H__

#define LIBTAPASCO_LOGLEVELS \
	_LALL(INIT,		(1 << 1)) \
	_LALL(DEVICE,		(1 << 2)) \
	_LALL(SCHEDULER,	(1 << 3)) \
	_LALL(IRQ,		(1 << 4)) \
	_LALL(MEM,		(1 << 5)) \
	_LALL(FUNCTIONS,	(1 << 6)) \
	_LALL(STATUS,		(1 << 7))

typedef enum {
#define _LALL(name, level) LALL_##name = level,
LIBTAPASCO_LOGLEVELS
#undef _LALL
} tapasco_ll_t;

int tapasco_logging_init(void);
void tapasco_logging_exit(void);
#ifdef NDEBUG
inline void tapasco_log(tapasco_ll_t const level, char *fmt, ...) {}
#else
void tapasco_log(tapasco_ll_t const level, char *fmt, ...);
#endif

#define ERR(msg, ...)		tapasco_log(0, "[%s] " msg "\n", __func__, ##__VA_ARGS__)
#define WRN(msg, ...)		tapasco_log(1, "[%s] " msg "\n", __func__, ##__VA_ARGS__)
#define LOG(l, msg, ...)	tapasco_log(l, "[%s] " msg "\n", __func__, ##__VA_ARGS__)

#endif /* TAPASCO_LOGGING_H__ */
