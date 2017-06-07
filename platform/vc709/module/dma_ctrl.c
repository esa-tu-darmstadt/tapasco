//
// Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
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
 * @file dual_dma_ctrl.c
 * @brief Implementation of custom dma engine specific code
	Strips the layout of the dma-registers and setup stuff to start a dma transfer
	in addition calls to acknowledge the interrupt in hw is given
 * */

/******************************************************************************/

#include "common/dma_ctrl.h"

/******************************************************************************/

/******************************************************************************/
/* functions for irq-handling */

#define REG_ID 0x18

typedef enum {
	DMA_USED_DUAL = 0,
	DMA_USED_BLUE = 1
} dma_used_t;

typedef irqreturn_t (*dma_intr_handler)(int , void *);
typedef void (*dma_from_device)(void *, dma_addr_t, int, void *);
typedef void (*dma_to_device)(void *, dma_addr_t , int , void *);

typedef struct {
	dma_intr_handler intr;
	dma_from_device from_dev;
	dma_to_device to_dev;
} fflink_dma_t;

static dma_used_t dma_used;

static const fflink_dma_t fflink_dma[] = {
	[DMA_USED_DUAL] = {
		dual_dma_intr_handler_dma,
		dual_dma_transmit_from_device,
		dual_dma_transmit_to_device
	},
	[DMA_USED_BLUE] = {
		blue_dma_intr_handler,
		blue_dma_transmit_from_device,
		blue_dma_transmit_to_device
	}
};

void dma_ctrl_init(void * device_base_addr)
{
	if(pcie_readl(device_base_addr + REG_ID) == 0xE5A0023) {
		dma_used = DMA_USED_BLUE;
		fflink_warn("Detected BlueDMA\n");
	} else {
		dma_used = DMA_USED_DUAL;
		fflink_warn("Detected DualDMA\n");
	}
}

/**
 * @brief Interrupt handler for dma engine 0
 * @param irq Interrupt number of calling line
 * @param dev_id magic number for interrupt sharing (not needed)
 * @return Tells OS, that irq is handled properly
 * */
irqreturn_t intr_handler_dma(int irq, void * dev_id)
{
	fflink_info("Interrupt called with irq %d\n", irq);

	fflink_dma[dma_used].intr(irq, dev_id);
	wake_up_queue(0);

	return IRQ_HANDLED;
}

/******************************************************************************/

/**
 * @brief Sets register of dma_engine to start a transfer from FPGA to Main memory
 * @param device_buffer FPGA memory address
 * @param host_handle Handle for platform independent memory address
 * @param btt Bytes to transfer
 * @param device_base_addr Address of dma engine registers
 * @return none
 * */
void transmit_from_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr)
{
	fflink_dma[dma_used].from_dev(device_buffer, host_handle, btt, device_base_addr);
}

/**
 * @brief Sets register of dma_engine to start a transfer from Main memory to FPGA
 * @param device_buffer FPGA memory address
 * @param host_handle Handle for platform independent memory address
 * @param btt Bytes to transfer
 * @param device_base_addr Address of dma engine registers
 * @return none
 * */
void transmit_to_device(void * device_buffer, dma_addr_t host_handle, int btt, void * device_base_addr)
{
	fflink_dma[dma_used].to_dev(device_buffer, host_handle, btt, device_base_addr);
}

/******************************************************************************/
