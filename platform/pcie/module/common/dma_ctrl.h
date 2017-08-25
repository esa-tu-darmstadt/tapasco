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
 * @file dma_ctrl.h
 * @brief Composition of everything needed to handle dma engine(s)
	interrupt handlers will be registered as msi irqs, when the pcie_device is loaded
	common header used for differrent hw-implementations of the dma engine (Xilinx, custom)
	to start a dma transfer on th pci-bus
 * */

#ifndef __DMA_CTRL_H
#define __DMA_CTRL_H

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
#include "debug_print.h"
#include "device_pcie.h"
#include "device_dma.h"

/******************************************************************************/

void dma_ctrl_init(void * device_base_addr);

/* interrupt handler used by dma engines registered in pcie_device.c */
irqreturn_t intr_handler_dma(int irq, void * dev_id);

/* setting registers to start dma transfer specific to used engine (Xilinx, custom) */
void transmit_from_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr);
void transmit_to_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr);

/******************************************************************************/

/* DMA Specific implementations */
irqreturn_t blue_dma_intr_handler(int irq, void * dev_id);
void blue_dma_transmit_from_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr);
void blue_dma_transmit_to_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr);

irqreturn_t dual_dma_intr_handler_dma(int irq, void * dev_id);
void dual_dma_transmit_from_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr);
void dual_dma_transmit_to_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr);

#endif // __DMA_CTRL_H
