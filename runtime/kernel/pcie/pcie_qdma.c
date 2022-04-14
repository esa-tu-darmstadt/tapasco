/*
 * Copyright (c) 2014-2021 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <linux/sched.h>
#include <linux/eventfd.h>
#include "pcie/pcie_qdma.h"
#include "tlkm_logging.h"
#include "tlkm_perfc.h"
#include "pcie/pcie_device.h"

// register offsets of QDMA core
#define QDMA_CTXT_REG_OFF	0x800UL
#define QDMA_C2H_MM_CTRL_OFF	0x1004UL
#define QDMA_H2C_MM_CTRL_OFF	0x1204UL
#define QDMA_PIDX_UPD_OFF	0x18004UL

// QDMA indirect context programming
#define QDMA_CTXT_CMD_CLR 		0
#define QDMA_CTXT_CMD_WR 		1
#define QDMA_CTXT_CMD_RD 		2
#define QDMA_CTXT_CMD_INV 		3

#define QDMA_CTXT_SELC_DEC_SW_C2H 	0x0
#define QDMA_CTXT_SELC_DEC_SW_H2C 	0x1
#define QDMA_CTXT_SELC_DEC_HW_C2H 	0x2
#define QDMA_CTXT_SELC_DEC_HW_H2C 	0x3
#define QDMA_CTXT_SELC_DEC_CR_C2H 	0x4
#define QDMA_CTXT_SELC_DEC_CR_H2C 	0x5
#define QDMA_CTXT_SELC_WRB 		0x6
#define QDMA_CTXT_SELC_PFTCH 		0x7
#define QDMA_CTXT_SELC_INT_COAL 	0x8
#define QDMA_CTXT_SELC_HOST_PROFILE 	0xA
#define QDMA_CTXT_SELC_TIMER 		0xB
#define QDMA_CTXT_SELC_FMAP 		0xC
#define QDMA_CTXT_SELC_FNC_STS 		0xD

#define QDMA_CTXT_BUSY			0x1

#define QDMA_SW_DESC_CTXT_IRQ_ARM	(1UL << 16)
#define QDMA_SW_DESC_CTXT_QEN		(1UL)
#define QDMA_SW_DESC_CTXT_BYPASS	(1UL << 18)
#define QDMA_SW_DESC_CTXT_IRQ_EN	(1UL << 21)
#define QDMA_SW_DESC_CTXT_IS_MM		(1UL << 31)

#define QDMA_IRQ_ARM			(1UL << 16)

// DMA commands of Descriptor Generator IP
#define DESC_GEN_CMD_READ	0x10001000	// C2H -> from FPGA to host memory
#define DESC_GEN_CMD_WRITE	0x10000001	// H2C -> from host to FPGA memory

// IDs of QDMA specific IP cores
#define DESC_GEN_ID		0xDE5C1000
#define QDMA_INTR_CTRL_ID 	0x0D4AC792

// structure of control registers of DescriptorGenerator IP
struct desc_gen_regs {
	uint64_t host_addr;
	uint64_t fpga_addr;
	uint64_t transfer_len;
	uint64_t id;
	uint64_t cmd;
	uint64_t status;
} __packed;

// structure of QDMA indirect context programming registers
struct qdma_ctxt_reg {
	uint32_t reserved;
	uint32_t ctxt_data[8];
	uint32_t ctxt_mask[8];
	uint32_t ctxt_cmd;
} __packed;

/**
 * check whether QDMA is used by checking for the QDMA interrupt controller
 * @param dev TLKM device
 * @return 1 if QDMA is in use, 0 otherwise
 */
int pcie_is_qdma_in_use(struct tlkm_device *dev)
{
	return ((ioread32(dev->mmap.plat +
			  tlkm_status_get_component_base(
				  dev, "PLATFORM_COMPONENT_INTC0") +
			  0x8100) & 0xFFFFFFFF) == QDMA_INTR_CTRL_ID);
}

/*
 * interrupt handlers when QDMA is in use
 */
irqreturn_t qdma_intr_handler_read(int irq, void *data)
{
	struct tlkm_irq_mapping *mapping = (struct tlkm_irq_mapping *)data;
	struct tlkm_pcie_device *pdev = mapping->dev->private_data;

	if (mapping->eventfd != 0)
		eventfd_signal(mapping->eventfd, 1);
	pdev->ack_register_aws[1] = QDMA_IRQ_ARM;
	return IRQ_HANDLED;
}

irqreturn_t qdma_intr_handler_write(int irq, void *data)
{
	struct tlkm_irq_mapping *mapping = (struct tlkm_irq_mapping *)data;
	struct tlkm_pcie_device *pdev = mapping->dev->private_data;

	if (mapping->eventfd != 0)
		eventfd_signal(mapping->eventfd, 1);
	pdev->ack_register_aws[0] = QDMA_IRQ_ARM;
	return IRQ_HANDLED;
}

/**
 * Program the indirect context registers of QDMA
 * @param ctxt_regs Pointer to respective QDMA control registers
 * @param mask Array with mask for context programming
 * @param data Array with data for cotext programming
 * @param ctxt_sel Encoding of context which shall be programmed
 * @return Returns zero on success, otherwise one
 */
static int qdma_program_ind_context(struct qdma_ctxt_reg *ctxt_regs, uint32_t mask[8], uint32_t data[8], uint32_t ctxt_sel)
{
	int i;
	uint32_t w_val;
	for (i = 0; i < 8; ++i)
		iowrite32(mask[i], &ctxt_regs->ctxt_mask[i]);

	for (i = 0; i < 8; ++i)
		iowrite32(data[i], &ctxt_regs->ctxt_data[i]);

	w_val = (ctxt_sel & 0xF) << 1 | QDMA_CTXT_CMD_WR << 5;
	iowrite32(w_val, &ctxt_regs->ctxt_cmd);

	// check whether context programming was successful by polling busy bit until it is cleared
	for (i = 1; i < 100; ++i) {
		if (!(ioread32(&ctxt_regs->ctxt_cmd) & QDMA_CTXT_BUSY))
			break;
	}
	return i >= 100;
}

/**
 * Clear the indirect context registers of QDMA
 * @param ctxt_regs Pointer to respective QDMA control registers
 * @param ctxt_sel Encoding of context which shall be cleared
 * @return Returns zero on success, otherwise one
 */
static int qdma_clear_ind_context(struct qdma_ctxt_reg *ctxt_regs, uint32_t ctxt_sel)
{
	int i;
	uint32_t w_val;
	w_val = (ctxt_sel & 0xF) << 1 | (QDMA_CTXT_CMD_CLR << 5);
	iowrite32(w_val, &ctxt_regs->ctxt_cmd);

	// check whether context clearing was successful by polling busy bit until it is cleared
	for (i = 1; i < 100; ++i) {
		if (!(ioread32(&ctxt_regs->ctxt_cmd) & QDMA_CTXT_BUSY))
			break;
	}
	return i >= 100;
}

/**
 * Invalidate indirect context registers of QDMA
 * @param ctxt_regs Pointer to respective QDMA control registers
 * @param ctxt_sel Encoding of context which shall be invalidated
 * @return Returns zero on success, otherwise one
 */
static int qdma_inv_ind_context(struct qdma_ctxt_reg *ctxt_regs, uint32_t ctxt_sel)
{
	int i;
	uint32_t w_val;
	w_val = (ctxt_sel & 0xF) << 1 | (QDMA_CTXT_CMD_INV << 5);

	// check whether context clearing was successful by polling busy bit until it is cleared
	for (i = 1; i < 100; ++i) {
		if (!(ioread32(&ctxt_regs->ctxt_cmd) & QDMA_CTXT_BUSY))
			break;
	}
	return i >= 100;
}

/**
 * Initialize QDMA core
 * @param pdev TLKM PCIe device structure
 * @return Returns zero on success, and an error code in case of failure
 */
int pcie_qdma_init(struct tlkm_pcie_device *pdev)
{
	int res, i;
	uint32_t data[8], mask[8], *c2h_mm_ctrl, *h2c_mm_ctrl;
	resource_size_t qdma_bar_start, qdma_bar_len;
	struct qdma_ctxt_reg *ctxt_regs;
	struct tlkm_device *dev = pdev->parent;
	struct desc_gen_regs *desc_gen_regs =
		(struct desc_gen_regs *)(dev->mmap.plat +
					 tlkm_status_get_component_base(
						 dev, "PLATFORM_COMPONENT_DMA0"));

	if ((readq(&desc_gen_regs->id) & 0xFFFFFFFF) != DESC_GEN_ID) {
		DEVERR(dev->dev_id, "could not find QDMA descriptor generator");
		res = -ENODEV;
		goto fail_id;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DMA, "Detected QDMA descriptor generator");

	DEVLOG(dev->dev_id, TLKM_LF_DMA, "Map BAR2 and configure QDMA core");
	qdma_bar_start = pci_resource_start(pdev->pdev, 2);
	qdma_bar_len = pci_resource_len(pdev->pdev, 2);
	if (qdma_bar_len < 0x18010) {
		DEVERR(dev->dev_id, "QDMA BAR2 is too small");
		res = -ENODEV;
		goto fail_barlen;
	}

	ctxt_regs = ioremap(qdma_bar_start + QDMA_CTXT_REG_OFF, sizeof(*ctxt_regs));
	if (!ctxt_regs) {
		DEVERR(dev->dev_id, "Failed to map QDMA context registers");
		res = -EFAULT;
		goto fail_ctxtregs;
	}

	c2h_mm_ctrl = ioremap(qdma_bar_start + QDMA_C2H_MM_CTRL_OFF, sizeof(uint32_t));
	if (!c2h_mm_ctrl) {
		DEVERR(dev->dev_id, "Failed to map QDMA C2H MM channel control register");
		res = -EFAULT;
		goto fail_c2hmmctrl;
	}

	h2c_mm_ctrl = ioremap(qdma_bar_start + QDMA_H2C_MM_CTRL_OFF, sizeof(uint32_t));
	if (!h2c_mm_ctrl) {
		DEVERR(dev->dev_id, "Failed to map QDMA H2C MM channel control register");
		res = -EFAULT;
		goto fail_h2cmmctrl;
	}

	// map PIDX update register to re-arm DMA interrupts
	// (use the in the QDMA case unused ack_register_aws)
	pdev->ack_register_aws = ioremap(qdma_bar_start + QDMA_PIDX_UPD_OFF, 2 * sizeof(uint32_t));
	if (!pdev->ack_register_aws) {
		DEVERR(dev->dev_id, "Failed to map QDMA PIDX update registers");
		res = -EFAULT;
		goto fail_ackregs;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DMA, "Clear and program QDMA contexts");
	res = qdma_clear_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_C2H);
	res |= qdma_clear_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_HW_C2H);
	res |= qdma_clear_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_CR_C2H);
	res |= qdma_clear_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_H2C);
	res |= qdma_clear_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_HW_H2C);
	res |= qdma_clear_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_CR_H2C);
	if (res) {
		DEVERR(dev->dev_id, "Failed to clear QDMA indirect contexts");
		res = -EACCES;
		goto fail_ctxtclear;
	}

	// clear host profile
	for (i = 0; i < 8; ++i) {
		mask[i] = 0xFFFFFFFF;
		data[i] = 0;
	}
	if (qdma_program_ind_context(ctxt_regs, mask, data, QDMA_CTXT_SELC_HOST_PROFILE)) {
		DEVERR(dev->dev_id, "Failed to program QDMA host profile context");
		res = -EACCES;
		goto fail_hostprofile;
	}

	// setup SW context
	data[0] = QDMA_IRQ_ARM;
	data[1] = QDMA_SW_DESC_CTXT_QEN | QDMA_SW_DESC_CTXT_BYPASS
		  | QDMA_SW_DESC_CTXT_IRQ_EN | QDMA_SW_DESC_CTXT_IS_MM;
	data[2] = data[3] = 0;
	data[4] = QDMA_IRQ_VEC_C2H;
	data[5] = data[6] = data[7] = 0;
	if (qdma_program_ind_context(ctxt_regs, mask, data, QDMA_CTXT_SELC_DEC_SW_C2H)) {
		DEVERR(dev->dev_id, "Failed to program QDMA C2H software context");
		res = -EACCES;
		goto fail_swc2h;
	}
	data[4] = QDMA_IRQ_VEC_H2C;
	if (qdma_program_ind_context(ctxt_regs, mask, data, QDMA_CTXT_SELC_DEC_SW_H2C)) {
		DEVERR(dev->dev_id, "Failed to program QDMA H2C software context");
		res = -EACCES;
		goto fail_swh2c;
	}

	// map queue to physical function PF0
	data[0] = 0;
	data[1] = 1;
	for (i = 2; i < 8; ++i)
		data[i] = 0;
	if (qdma_program_ind_context(ctxt_regs, mask, data, QDMA_CTXT_SELC_FMAP)) {
		DEVERR(dev->dev_id, "Failed to map QDMA queue to PF");
		res = -EACCES;
		goto fail_fmap;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DMA, "Enable QDMA engines");
	iowrite32(1, c2h_mm_ctrl);
	iowrite32(1, h2c_mm_ctrl);

	iounmap(h2c_mm_ctrl);
	iounmap(c2h_mm_ctrl);
	iounmap(ctxt_regs);

	return 0;

fail_fmap:
	qdma_inv_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_H2C);
fail_swh2c:
	qdma_inv_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_C2H);
fail_swc2h:
fail_hostprofile:
fail_ctxtclear:
	iounmap(pdev->ack_register_aws);
fail_ackregs:
	iounmap(h2c_mm_ctrl);
fail_h2cmmctrl:
	iounmap(c2h_mm_ctrl);
fail_c2hmmctrl:
	iounmap(ctxt_regs);
fail_ctxtregs:
fail_barlen:
fail_id:
	return res;
}

/**
 * Disable QDMA on exit
 * @param pdev TLKM PCIe device structure
 * @return Returns zero on success, and an error code in case of failure
 */
int pcie_qdma_exit(struct tlkm_pcie_device *pdev)
{
	int r, res;
	uint32_t *c2h_mm_ctrl, *h2c_mm_ctrl;
	resource_size_t qdma_bar_start;
	struct qdma_ctxt_reg *ctxt_regs;
	struct tlkm_device *dev = pdev->parent;
	struct desc_gen_regs *desc_gen_regs =
		(struct desc_gen_regs *)(dev->mmap.plat +
					 tlkm_status_get_component_base(
						 dev, "PLATFORM_COMPONENT_DMA0"));

	if ((readq(&desc_gen_regs->id) & 0xFFFFFFFF) != DESC_GEN_ID) {
		DEVWRN(dev->dev_id, "descriptor generator not found");
		return -ENODEV;
	}

	res = 0;
	iounmap(pdev->ack_register_aws);

	qdma_bar_start = pci_resource_start(pdev->pdev, 2);
	h2c_mm_ctrl = ioremap(qdma_bar_start + QDMA_H2C_MM_CTRL_OFF, sizeof(uint32_t));
	if (!h2c_mm_ctrl) {
		DEVERR(dev->dev_id, "Failed to map QDMA H2C MM channel control register");
		res = -EFAULT;
	} else {
		iowrite32(0, h2c_mm_ctrl);
		iounmap(h2c_mm_ctrl);
	}

	c2h_mm_ctrl = ioremap(qdma_bar_start + QDMA_C2H_MM_CTRL_OFF, sizeof(uint32_t));
	if (!c2h_mm_ctrl) {
		DEVERR(dev->dev_id, "Failed to map QDMA C2H MM channel control register");
		res = -EFAULT;
	} else {
		iowrite32(0, c2h_mm_ctrl);
		iounmap(c2h_mm_ctrl);
	}

	ctxt_regs = ioremap(qdma_bar_start + QDMA_CTXT_REG_OFF, sizeof(*ctxt_regs));
	if (!ctxt_regs) {
		DEVERR(dev->dev_id, "Failed to map QDMA context registers");
		res = -EFAULT;
	} else {
		r = qdma_inv_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_C2H);
		r |= qdma_inv_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_H2C);
		if (r) {
			DEVERR(dev->dev_id, "Failed to invalidate QDMA SW context");
			res = -EACCES;
		}
		iounmap(ctxt_regs);
	}
	return res;
}