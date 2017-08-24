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
 * @file ffLink_driver.h
 * @brief Composition of everything needed for kernel module
	mainly consists of the init-/exit-functions
	handles versioning, licensing and small description can be found in the implementation
 * */

#ifndef __FFLINK_DRIVER_H
#define __FFLINK_DRIVER_H

/******************************************************************************/
/* Includes section */

/* Includes from linux headers */
#include <linux/module.h>
#include <linux/version.h>
#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/kdev_t.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/mm.h>
//#include <linux/pagemap.h>
//#include <linux/gfp.h>
//#include <linux/dma-mapping.h>
//#include <linux/delay.h>
#include <linux/slab.h>
//#include <linux/clk.h>
#include <asm/io.h>
#include <linux/highmem.h>
#include <linux/interrupt.h>
#include <linux/mutex.h>
#include <linux/semaphore.h>
#include <linux/spinlock.h>
#include <linux/errno.h>
//#include <linux/kernel.h>
//#include <asm/system.h>
#include <asm/uaccess.h>
#include <linux/delay.h>
#include <linux/pci.h>
#include <linux/sched.h>

/* Includes from local files */
#include "common/debug_print.h"
#include "common/device_dma.h"
#include "common/device_user.h"
#include "common/device_pcie.h"

/******************************************************************************/
/* driver identification */

/* module version */
#define FFLINK_VERSION_MAJOR	1
#define FFLINK_VERSION_MINOR	2
#define FFLINK_VERSION_BUILD	3
#define FFLINK_VERSION		\
	FFLINK_VERSION_MAJOR.FFLINK_VERSION_MINOR.FFLINK_VERSION_BUILD

/******************************************************************************/
/* global init/exit method */

static int 	__init fflink_init(void);
static void __exit fflink_exit(void);

/******************************************************************************/

#endif // __FFLINK_DRIVER_H
