//
// Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
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
/**
 * @file char_device_hsa_dma.h
 * @brief TODO
 * */

#ifndef __CHAR_DEVICE_HSA_DMA_H
#define __CHAR_DEVICE_HSA_DMA_H

/******************************************************************************/
/* Include section */

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
#include <asm/atomic.h>
#include <linux/aio.h>
#include <linux/uio.h>
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
#include "common/device_pcie.h"
#include "include/hsa_dma_ioctl_calls.h"

/******************************************************************************/

#define HSA_DUMMY_DMA_BUFFER_SIZE 4 * 1024 * 1024

#define FFLINK_HSA_DMA_NAME "HSA_DMA_BUFFER"

/******************************************************************************/

/* struct array to hold data over multiple fops-calls */
struct priv_data_struct {
	struct hsa_mmap_space * kvirt_shared_mem;

	dma_addr_t dma_shared_mem;

    size_t mem_size;
};

/******************************************************************************/
/* functions for user-space interaction */

static int hsa_dma_open(struct inode *, struct file *);
static int hsa_dma_close(struct inode *, struct file *);
static long hsa_dma_ioctl(struct file *, unsigned int, unsigned long);
static ssize_t hsa_dma_read(struct file *, char __user *, size_t count, loff_t *);
static ssize_t hsa_dma_write(struct file *, const char __user *, size_t count, loff_t *);
static int hsa_dma_mmap(struct file *, struct vm_area_struct *vma);

/******************************************************************************/

#endif
