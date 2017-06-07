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
 * @file char_device_user.h
 * @brief Composition of everything needed to handle char-device calls for user-functions
	here all definitions of functions and structs are given, which are used by the char-device
	user can choose, how much minor devices will be allocated
	each minor device belongs to one Xilinx IRQ core, the base address is the physical address attached to the pcie-core
	definition of address map of one IRQ core is given with all offsets of its registers
	this has to match the current specification of the version used by Xilinx
	tested with Axi Interrupt Controller (INTC) v4.1
 * */

#ifndef __CHAR_DEVICE_USER_H
#define __CHAR_DEVICE_USER_H

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
#include "common/device_user.h"
#include "include/user_ioctl_calls.h"
#include "common/device_pcie.h"

/******************************************************************************/

/* number of device, which will be created for PEs  */
#define FFLINK_USER_NODES 1

#define PE_IRQS 128

/* device name to register fops with
 * fops will append a number to name for multiple minor nodes */
#define FFLINK_USER_NAME "FFLINK_USER_DEVICE"

/* size of uint32 array allocated statically for reading/writing registers  */
#define STATIC_BUFFER_SIZE 2
/* size of one AXI-Lite register in byte  */
#define REGISTER_BYTE_SIZE 4

/******************************************************************************/
/* addresses and commands for interrupt controllers  */

#define IRQ_BASE_ADDR_0 0x400000
#define IRQ_BASE_ADDR_1 0x410000
#define IRQ_BASE_ADDR_2 0x420000
#define IRQ_BASE_ADDR_3 0x430000

#define IRQ_REG_ISR		0x00	/* Interrupt Status Register */
#define IRQ_REG_IPR		0x04	/* Interrupt Pending Register */
#define IRQ_REG_IER		0x08	/* Interrupt Enable Register */
#define IRQ_REG_IAR		0x0C	/* Interrupt Acknowledge Register */
#define IRQ_REG_SIE		0x10	/* Set Interrupt Enables */
#define IRQ_REG_CIE		0x14	/* Clear Interrupt Enables */
#define IRQ_REG_IVR		0x18	/* Interrupt Vector Register */
#define IRQ_REG_MER		0x1C	/* Master Enable Register */
#define IRQ_REG_IMR		0x20	/* Interrupt Mode Register */
#define IRQ_REG_ILR		0x24	/* Interrupt Level Register */

#define CMD_IER_EN		0xFFFFFFFF
#define CMD_MER_EN		0x3

/******************************************************************************/
/* default ID should be found in every bitsream */
#define HW_ID_MAGIC				0xE5AE1337
#define HW_ID_ADDR				0x02800000

/******************************************************************************/

/* struct array to hold data over multiple fops-calls */
struct priv_data_struct {
	wait_queue_head_t user_wait_queue[PE_IRQS];
	int user_condition[PE_IRQS];
};

/******************************************************************************/
/* functions for user-space interaction */

static int user_open(struct inode *, struct file *);
static int user_close(struct inode *, struct file *);
static long user_ioctl(struct file *, unsigned int, unsigned long);
static ssize_t user_read(struct file *, char __user *, size_t count, loff_t *);
static ssize_t user_write(struct file *, const char __user *, size_t count, loff_t *);
static int user_mmap(struct file *filp, struct vm_area_struct *vma);

/******************************************************************************/

#endif // __CHAR_DEVICE_USER_H
