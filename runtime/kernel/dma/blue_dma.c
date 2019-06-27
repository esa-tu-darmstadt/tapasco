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
#include <linux/sched.h>
#include "tlkm_dma.h"
#include "tlkm_logging.h"
#include "tlkm_perfc.h"

/* Register Map and commands */
#define REG_HOST_ADDR 			0x00 	/* slv_reg0 = PCIe addr */
#define REG_FPGA_ADDR 			0x08	/* slv_reg1 = FPGA addr */
#define REG_BTT 			0x10	/* slv_reg2 = bytes to transfer */
#define REG_CMD 			0x20	/* slv_reg3 = CMD */
#define REG_ID 						0x18

#define REG_READ_REQUESTS 0x48
#define REG_WRITE_REQUESTS 0x56

#define CMD_READ			0x10001000 	/* from m64 fpga memory to m64 host memory */
#define CMD_WRITE			0x10000001 	/* from m64 host memory to m64 fpga memory */

#define BLUE_DMA_ID				 0xE5A0023

irqreturn_t blue_dma_intr_handler_read(int irq, void * dev_id)
{
	struct dma_engine *dma = (struct dma_engine *)dev_id;
	volatile uint32_t* msix_ack = (volatile uint32_t*) (dma->dev->mmap.plat + 0x28120);
	atomic64_inc(&dma->rq_processed);
	wake_up_interruptible(&dma->rq);
	msix_ack[0] = 0;
	return IRQ_HANDLED;
}

irqreturn_t blue_dma_intr_handler_write(int irq, void * dev_id)
{
	struct dma_engine *dma = (struct dma_engine *)dev_id;
	volatile uint32_t* msix_ack = (volatile uint32_t*) (dma->dev->mmap.plat + 0x28120);
	atomic64_inc(&dma->wq_processed);
	wake_up_interruptible(&dma->wq);
	msix_ack[0] = 1;
	return IRQ_HANDLED;
}

int blue_dma_init(struct dma_engine *dma) {

	u64 id = *(u64 *)(dma->regs + REG_ID);
	if ((id & 0xFFFFFFFF) == BLUE_DMA_ID) {
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "detected BlueDMA");
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "PCIe beats per burst: %u", (uint8_t)(id >> 32));
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "FPGA beats per burst: %u", (uint8_t)(id >> 40));
		DEVLOG(dma->dev_id, TLKM_LF_DMA, "smallest alignment: %u", (uint8_t)(id >> 48));
		dma->alignment = (uint8_t)(id >> 48);
		return 1;
	} else {
		return 0;
	}
}

ssize_t blue_dma_copy_from(struct dma_engine *dma, void *dma_handle, dev_addr_t dev_addr, size_t len)
{
	dma_addr_t handle = (dma_addr_t)dma_handle;
	DEVLOG(dma->dev_id, TLKM_LF_DMA, "dev_addr = 0x%p, dma_handle = 0x%p, len: %zu bytes", (void *)dev_addr, dma_handle, len);
	if (mutex_lock_interruptible(&dma->regs_mutex)) {
		WRN("got killed while aquiring the mutex");
		return len;
	}

	*(u64 *)(dma->regs + REG_FPGA_ADDR)		= dev_addr;
	*(u64 *)(dma->regs + REG_HOST_ADDR)		= (u64)(handle);
	*(u64 *)(dma->regs + REG_BTT)			= len;
	wmb();
	*(u64 *)(dma->regs + REG_CMD)			= CMD_READ;
	mutex_unlock(&dma->regs_mutex);
	return atomic64_inc_return(&dma->rq_enqueued);
}

ssize_t blue_dma_copy_to(struct dma_engine *dma, dev_addr_t dev_addr, const void *dma_handle, size_t len)
{
	dma_addr_t handle = (dma_addr_t)dma_handle;
	DEVLOG(dma->dev_id, TLKM_LF_DMA, "dev_addr = 0x%px, dma_handle = 0x%p, len: %zu bytes", (void *)dev_addr, dma_handle, len);
	if (mutex_lock_interruptible(&dma->regs_mutex)) {
		WRN("got killed while aquiring the mutex");
		return len;
	}

	*(u64 *)(dma->regs + REG_FPGA_ADDR)		= dev_addr;
	*(u64 *)(dma->regs + REG_HOST_ADDR)		= (u64)(handle);
	*(u64 *)(dma->regs + REG_BTT)			= len;
	wmb();
	*(u64 *)(dma->regs + REG_CMD)			= CMD_WRITE;
	mutex_unlock(&dma->regs_mutex);
	return atomic64_inc_return(&dma->wq_enqueued);
}
