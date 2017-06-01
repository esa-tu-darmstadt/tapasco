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
 * @file pcie_device.h 
 * @brief Composition of everything needed to handle pcie device
 * */

#ifndef __PCIE_DEVICE_H
#define __PCIE_DEVICE_H

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
#include "common/dma_ctrl.h"
#include "common/device_pcie.h"

/******************************************************************************/

#define FFLINK_PCI_NAME "FFLINK_PCI_DRIVER"

// pci id to find device on the bus
#define XILINX_VENDOR_ID   0x10EE
#define XILINX_DEVICE_ID   0x7038

static struct pci_device_id fflink_pci_id[ ] = {
	{ PCI_DEVICE( XILINX_VENDOR_ID , XILINX_DEVICE_ID ) },
	{ } // empty entry for termination
};

// export structure for hot-plug and depmod
MODULE_DEVICE_TABLE(pci, fflink_pci_id);

// init/exit functions to handle pci device properly
static int fflink_pci_probe(struct pci_dev *pdev, const struct pci_device_id *id);
static void fflink_pci_remove(struct pci_dev *pdev);

// struct representation of functions above similiar to fops
static struct pci_driver fflink_pci_driver = {
	.name		= FFLINK_PCI_NAME,
	.id_table	= fflink_pci_id,
	.probe		= fflink_pci_probe,
	.remove		= fflink_pci_remove,
};

/******************************************************************************/

/* struct to hold data related to the pcie device */
struct pci_data_struct{
	struct pci_dev* pdev;
	unsigned long long phy_addr_bar0;
	unsigned long long phy_len_bar0;
	unsigned long long phy_flags_bar0;
	unsigned long long phy_addr_bar2;
	unsigned long long phy_len_bar2;
	unsigned long long phy_flags_bar2;
	unsigned int irq_first;	
	unsigned int irq_length;
	unsigned int irq_assigned;
	void * kvirt_addr_bar0;
	void * kvirt_addr_bar2;
};

/******************************************************************************/
/* helper functions called for registering pcie-device */

static int register_intr_handler(struct pci_dev *pdev, int c);
static int claim_device(struct pci_dev *pdev);
static int configure_device(struct pci_dev *pdev);
static int claim_msi(struct pci_dev *pdev);
static void report_link_status(struct pci_dev *pdev);

/******************************************************************************/

#endif // __PCIE_DEVICE_H
