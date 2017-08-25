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
 * @file char_device_dma.h
 * @brief Composition of everything needed to handle char-device calls for dma transfers
	here all definitions of functions and structs are given, which are used by the char-device
	the user can adapt the method used for transfers (bounce-/double-buffering)
	in addition the size of the internal buffers can be choosen and the upper bound, when double buffering will be used
	the base addresses of the dma engine must match the physical address map of the pci-express design in vivado
	do not confuse these addresses with the address of the pcie_core given by bios
 * */

#ifndef __CHAR_DEVICE_DMA_H
#define __CHAR_DEVICE_DMA_H

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
#include "common/dma_ctrl.h"
#include "include/dma_ioctl_calls.h"

/******************************************************************************/

/* physical address of dma core in register map from vivado */
#define DMA_BASE_ADDR_0 0x300000

#define AXI_CTRL_BASE_ADDR 0x100000

/* BRAM standard address */
#define RAM_BASE_ADDR_0 0x80000000

/* to change buffer_size increase or decrease the order of pages */
#define BUFFER_ORDER (MAX_ORDER -1)
#define BUFFER_SIZE  (PAGE_SIZE * (1 << BUFFER_ORDER))

/* device name to register fops with
 * fops will append a number to name for multiple minor nodes */
#define FFLINK_DMA_NAME "FFLINK_DMA_DEVICE"

/******************************************************************************/

/* struct array to hold data over multiple fops-calls */
struct priv_data_struct {
	void * kvirt_h2l;
	void * kvirt_l2h;

	dma_addr_t dma_handle_h2l;
	dma_addr_t dma_handle_l2h;

	void * mem_addr_l2h;
	void * mem_addr_h2l;

	void * device_base_addr;
	void * ctrl_base_addr;

	wait_queue_head_t rw_wait_queue;
	bool condition_rw;
	struct mutex rw_mutex;

	unsigned int cache_lsize;
	unsigned int cache_mask;
};

/******************************************************************************/
/* functions for user-space interaction */

static int dma_open(struct inode *, struct file *);
static int dma_close(struct inode *, struct file *);
static long dma_ioctl(struct file *, unsigned int, unsigned long);
static ssize_t dma_read(struct file *, char __user *, size_t count, loff_t *);
static ssize_t dma_write(struct file *, const char __user *, size_t count, loff_t *);

/******************************************************************************/
/* helper functions called for sys-calls */
static unsigned int dma_cache_fit(unsigned int btt);
static int dma_alloc_pbufs(void** p, dma_addr_t *handle, gfp_t zone, int direction);
static void dma_free_pbufs(void *p, dma_addr_t handle, int direction);
static void transmit_to_user(void *, void *, dma_addr_t, int);
static void transmit_from_user(void *, void *, dma_addr_t, int);

/******************************************************************************/
/* overload function to exchange bounce-/double-buffering */

static int read_with_bounce(int count, char __user *buf, void * mem_addr, struct priv_data_struct *p);
static inline int read_device(int count, char __user *buf, void * mem_addr, struct priv_data_struct *p);

static int write_with_bounce(int count, const char __user *buf, void * mem_addr, struct priv_data_struct *p);
static inline int write_device(int count, const char __user *buf, void * mem_addr, struct priv_data_struct *p);

/******************************************************************************/

#endif // __CHAR_DEVICE_DMA_H
