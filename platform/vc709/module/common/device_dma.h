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
 * @file device_dma.h
 * @brief Composition of everything needed to (un/)load the char_device respondsible for dma calls
	additionally helper functions defined to ease access throughout different minor nodes
 * */

#ifndef __DEVICE_DMA_H
#define __DEVICE_DMA_H

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

/******************************************************************************/

/* helper functions called to (un/)load this char device */
int char_dma_register(void);
void char_dma_unregister(void);

/* helper functions for information specific for each minor node */
void * get_dev_addr(int i);
void wake_up_queue(int i);


/******************************************************************************/

#endif // __DEVICE_DMA_H
