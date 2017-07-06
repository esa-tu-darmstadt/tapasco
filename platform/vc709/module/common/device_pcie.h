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
 * @file device_pcie.h
 * @brief Composition of everything needed to handle pcie device
	Responsible for (un/)load pcie device, allows acces to pci-specific information
	and supports wrapper for safe access to pcie-bar0 space
 * */

#ifndef __DEVICE_PCIE_H
#define __DEVICE_PCIE_H

/******************************************************************************/

/* Bit Mask, which is accessible from dma-core - 32 and 64 bit supported */
#define DMA_MAX_BIT 32

/* helper functions/definition called to (un/)load pci device */
int pcie_register(void);
void pcie_unregister(void);

/* access to pci_mapping information (virtual addr, irqs, ...) */
struct pci_dev* get_pcie_dev(void);
//void * get_virt_bar0_addr(void);

/* wrapper to read/write from pcie-bar0 */
void pcie_writel(unsigned long data, void * addr);
void pcie_writeq(unsigned long long data, void * addr);
unsigned long pcie_readl(void * addr);
unsigned long long pcie_readq(void * addr);

void pcie_writel_bar2(unsigned long data, void * addr);
unsigned long pcie_readl_bar2(void * addr);

int pcie_translate_irq_number(int irq);

/******************************************************************************/

#endif // __DEVICE_PCIE_H
