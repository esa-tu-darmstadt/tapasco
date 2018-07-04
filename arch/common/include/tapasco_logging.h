//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TAPASCO).
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

#include <inttypes.h>

#include <log.h>

#define LIBTAPASCO_LOGLEVELS \
	_LALL(INIT,		(1 << 1)) \
	_LALL(DEVICE,		(1 << 2)) \
	_LALL(SCHEDULER,	(1 << 3)) \
	_LALL(IRQ,		(1 << 4)) \
	_LALL(MEM,		(1 << 5)) \
	_LALL(PEMGMT,		(1 << 6)) \
	_LALL(STATUS,		(1 << 7)) \
	_LALL(TRANSFERS,	(1 << 8)) \
	_LALL(ASYNC	,	(1 << 9))

typedef enum {
#define _LALL(name, level) LALL_##name = level,
LIBTAPASCO_LOGLEVELS
#undef _LALL
} tapasco_ll_t;

int tapasco_logging_init(void);
void tapasco_logging_deinit(void);

#ifndef DEV_PREFIX
	#define DEV_PREFIX		"device #" PRIdev
#endif

#ifdef NDEBUG
	#include <stdio.h>

	#define LOG(l, msg, ...) {}
	#define DEVLOG(dev_id, l, msg, ...)	{}

	#define ERR(msg, ...)		fprintf(stderr, "[%s]: " msg "\n", __func__, ##__VA_ARGS__)
	#define WRN(msg, ...)		fprintf(stderr, "[%s]: " msg "\n", __func__, ##__VA_ARGS__)

	#define DEVERR(dev_id, msg, ...) \
			fprintf(stderr, DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__, ##__VA_ARGS__)
	#define DEVWRN(dev_id, l, msg, ...) \
			fprintf(stderr, DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__, ##__VA_ARGS__)
#else /* !NDEBUG */
	#define LOG(l, msg, ...) log_error("[%s]: " msg "\n", __func__, ##__VA_ARGS__)

	#define DEVLOG(dev_id, l, msg, ...)	log_info(DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__, ##__VA_ARGS__)

	#define ERR(msg, ...)	log_error("[%s]: " msg "\n", __func__, ##__VA_ARGS__)
	#define WRN(msg, ...)	log_warn("[%s]: " msg "\n", __func__, ##__VA_ARGS__)

	#define DEVERR(dev_id, msg, ...) \
			log_error(DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__, ##__VA_ARGS__)
	#define DEVWRN(dev_id, msg, ...) \
			log_warn(DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__, ##__VA_ARGS__)
#endif

#endif /* TAPASCO_LOGGING_H__ */
