//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
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
#include "tlkm_logging.h"
#include "dual_dma.h"

/* Register Map and commands */
#define REG_HOST_ADDR_LOW 		0x00 	/* slv_reg0 = PCIe addr (under) */
#define REG_HOST_ADDR_HIGH 		0x04	/* slv_reg1 = PCIe addr (upper) */
#define REG_FPGA_ADDR_LOW 		0x08	/* slv_reg2 = FPGA addr */
#define REG_BTT 			0x10	/* slv_reg4 = bytes to transfer */
#define REG_ID 				0x14	/* slv_reg5 = ID */
#define REG_CMD 			0x18	/* slv_reg6 = CMD */
#define REG_STATUS 			0x20	/* slv_reg8 = return status */

#define CMD_READ			0x10001000 	/* from m32 fpga memory to m64 host memory */
#define CMD_WRITE			0x10000001 	/* from m64 host memory to m32 fpga memory */
#define CMD_ACK				0x10011001 	/* acknowledge data transfer to toggle interrupt */

irqreturn_t dual_dma_intr_handler_dma(int irq, void * dev_id)
{
	struct dma_engine *dma = (struct dma_engine *)dev_id;
	*(u32 *)(dma->regs + REG_CMD) = CMD_ACK;
	mutex_unlock(&dma->regs_mutex);
	atomic64_inc(&dma->wq_processed);
	atomic64_inc(&dma->rq_processed);
	wake_up_interruptible(&dma->wq);
	return IRQ_HANDLED;
}

ssize_t dual_dma_copy_from(struct dma_engine *dma, void __user *usr_addr, dev_addr_t dev_addr, size_t len)
{
	LOG(TLKM_LF_DMA, "dev_addr = 0x%px, usr_addr = 0x%px, len: %zu bytes", (void *)dev_addr, usr_addr, len);
	if(mutex_lock_interruptible(&dma->regs_mutex)) {
		WRN("got killed while aquiring the mutex");
		return len;
	}

	*(u32 *)(dma->regs + REG_FPGA_ADDR_LOW)		= (u32)dev_addr;
	*(u32 *)(dma->regs + REG_HOST_ADDR_LOW)		= (u32)((uintptr_t)usr_addr);
	*(u32 *)(dma->regs + REG_HOST_ADDR_HIGH)	= sizeof(usr_addr) > 4 ? (u32)((uintptr_t)usr_addr >> 32) : 0;
	*(u32 *)(dma->regs + REG_BTT)			= (u32)len;
	wmb();
	*(u32 *)(dma->regs + REG_CMD)			= CMD_READ;
	return atomic64_inc_return(&dma->rq_enqueued);
}

ssize_t dual_dma_copy_to(struct dma_engine *dma, dev_addr_t dev_addr, const void __user *usr_addr, size_t len)
{
	LOG(TLKM_LF_DMA, "dev_addr = 0x%px, usr_addr = 0x%px, len: %zu bytes", (void *)dev_addr, usr_addr, len);
	if(mutex_lock_interruptible(&dma->regs_mutex)) {
		WRN("got killed while aquiring the mutex");
		return len;
	}

	*(u32 *)(dma->regs + REG_HOST_ADDR_LOW) 	= (u32)((uintptr_t)usr_addr);
	*(u32 *)(dma->regs + REG_HOST_ADDR_HIGH)	= sizeof(usr_addr) > 4 ? (u32)((uintptr_t)usr_addr >> 32) : 0;
	*(u32 *)(dma->regs + REG_FPGA_ADDR_LOW) 	= (u32)dev_addr;
	*(u32 *)(dma->regs + REG_BTT)			= (u32)len;
	wmb();
	*(u32 *)(dma->regs + REG_CMD)			= CMD_WRITE;
	return atomic64_inc_return(&dma->wq_enqueued);
}
