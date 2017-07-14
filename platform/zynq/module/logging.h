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
//! @file	logging.h
//! @brief	Kernel logging helper functions:
//!		Declares module parameter 'logging_level' which determines the
//!		amount of printk output; errors are signaled using level 0 and
//!		are always output, warnings are level 1, the other levels are
//!		bitfield indicators and can be defined by the user.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __TAPASCO_PLATFORM_LOGGING_H__
#define __TAPASCO_PLATFORM_LOGGING_H__

#include <linux/printk.h>

#ifdef LOGGING_MODULE_INCLUDE
unsigned int logging_level = 0x7fffffff;
module_param(logging_level, uint, S_IRUGO|S_IWUSR|S_IWGRP);
#else
extern int logging_level;
#endif

#ifndef NDEBUG
#define ERR(msg, ...)		tapasco_platform_log(0, msg, ##__VA_ARGS__)
#define WRN(msg, ...)		tapasco_platform_log(1, msg, ##__VA_ARGS__)
#define LOG(l, msg, ...)	tapasco_platform_log((l), msg, ##__VA_ARGS__)

#define tapasco_platform_log(level, fmt, ...) do { \
		switch ((int)level) { \
		case 0: \
			printk(KERN_ERR "tapasco-platform-zynq: [%s] " \
					fmt "\n", __func__, \
					##__VA_ARGS__); \
			break; \
		case 1: \
			printk(KERN_WARNING "tapasco-platform-zynq: [%s] " \
					fmt "\n", __func__, \
					##__VA_ARGS__); \
			break; \
		default: \
			if (logging_level & level) \
				printk(KERN_NOTICE "tapasco_platform_zynq: [%s] " \
						fmt "\n", __func__, \
						##__VA_ARGS__); \
			break; \
		} \
	} while(0)
#else
/* only errors and warnings, no other messages */
#define ERR(fmt, ...)		printk(KERN_ERR "tapasco-platform-zynq: [%s] " \
					fmt "\n", __func__, \
					##__VA_ARGS__)

#define WRN(fmt, ...)		printk(KERN_WARNING "tapasco-platform-zynq: [%s] " \
					fmt "\n", __func__, \
					##__VA_ARGS__)

#define LOG(l, msg, ...)
#define tapasco_platform_log(level, fmt, ...)
#endif

#endif /* __TAPASCO_PLATFORM_LOGGING_H__ */
