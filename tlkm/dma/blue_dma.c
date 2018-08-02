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

#define CMD_READ			0x10001000 	/* from m64 fpga memory to m64 host memory */
#define CMD_WRITE			0x10000001 	/* from m64 host memory to m64 fpga memory */

irqreturn_t blue_dma_intr_handler_read(int irq, void * dev_id)
{
	struct dma_engine *dma = (struct dma_engine *)dev_id;
	atomic64_inc(&dma->rq_processed);
	wake_up_interruptible(&dma->rq);
	return IRQ_HANDLED;
}

irqreturn_t blue_dma_intr_handler_write(int irq, void * dev_id)
{
	struct dma_engine *dma = (struct dma_engine *)dev_id;
	atomic64_inc(&dma->wq_processed);
	wake_up_interruptible(&dma->wq);
	return IRQ_HANDLED;
}

ssize_t blue_dma_copy_from(struct dma_engine *dma, void *dma_handle, dev_addr_t dev_addr, size_t len)
{
	dma_addr_t handle = (dma_addr_t)dma_handle;
	DEVLOG(dma->dev_id, TLKM_LF_DMA, "dev_addr = 0x%px, dma_handle = 0x%llx, len: %zu bytes", (void *)dev_addr, handle, len);
	if(mutex_lock_interruptible(&dma->regs_mutex)) {
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
	DEVLOG(dma->dev_id, TLKM_LF_DMA, "dev_addr = 0x%px, dma_handle = 0x%llx, len: %zu bytes", (void *)dev_addr, handle, len);
	if(mutex_lock_interruptible(&dma->regs_mutex)) {
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
