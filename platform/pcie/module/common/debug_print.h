//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
/**
 * @file debug_print.h
 * @brief Composition of everything needed for debug output
 * currently three different levels of outputs defined
 * */

#ifndef __DEBUG_PRINT_H
#define __DEBUG_PRINT_H

/******************************************************************************/

/* preprocessor stuff for stringification, e.g., needed for device attributes */
#define STRV(arg)	#arg
#define XSTRV(s)	STRV(s)

/* convert byte offset to offset in void * stride */
#define ptr_offset(ptr, x)	((char *)ptr + x)

/******************************************************************************/
/* Debug macros */

#ifdef DEBUG_VERBOSE
#define fflink_info(msg, ...)	printk(KERN_INFO "ffLink (%s): " msg, \
		__func__, ##__VA_ARGS__)
#else
#define fflink_info(msg, ...)
#endif

#ifdef DEBUG
#define fflink_notice(msg, ...)	printk(KERN_NOTICE "ffLink (%s): " msg, \
		__func__, ##__VA_ARGS__)
#else
#define fflink_notice(msg, ...)
#endif

#define fflink_warn(msg, ...)	printk(KERN_WARNING "ffLink (%s): " msg, \
		__func__, ##__VA_ARGS__)

/******************************************************************************/

#endif // __DEBUG_PRINT_H
