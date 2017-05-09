//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	tpc_logging.h
//! @brief	libtpc logging functions.
//!		Internal logging functions to produce debug output; levels are
//!		bitfield that can be turned on/off individually, with the
//!		exception of all-zeroes (critical error) and 1 (warning), which
//!		are always activated.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TPC_LOGGING_H__
#define __TPC_LOGGING_H__

#define LIBTPC_LOGLEVELS \
	_LALL(INIT,		(1 << 1)) \
	_LALL(DEVICE,		(1 << 2)) \
	_LALL(SCHEDULER,	(1 << 3)) \
	_LALL(IRQ,		(1 << 4)) \
	_LALL(MEM,		(1 << 5)) \
	_LALL(FUNCTIONS,	(1 << 6)) \
	_LALL(STATUS,		(1 << 7))

typedef enum {
#define _LALL(name, level) LALL_##name = level,
LIBTPC_LOGLEVELS
#undef _LALL
} tpc_ll_t;

int tpc_logging_init(void);
void tpc_logging_exit(void);
#ifdef NDEBUG
inline void tpc_log(tpc_ll_t const level, char *fmt, ...) {}
#else
void tpc_log(tpc_ll_t const level, char *fmt, ...);
#endif

#define ERR(msg, ...)		tpc_log(0, "[%s] " msg "\n", __func__, ##__VA_ARGS__)
#define WRN(msg, ...)		tpc_log(1, "[%s] " msg "\n", __func__, ##__VA_ARGS__)
#define LOG(l, msg, ...)	tpc_log(l, "[%s] " msg "\n", __func__, ##__VA_ARGS__)

#endif /* __TPC_LOGGING_H__ */
