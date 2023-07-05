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
#include "pcie/pcie.h"
#include "tlkm_logging.h"
#include "tlkm_perfc.h"
#include "pcie/pcie_device.h"

// register offsets of QDMA core
#define QDMA_TRQ_SEL_FMAP	0x400UL
#define QDMA_CTXT_REG_OFF	0x800UL
#define QDMA_QID2VEC_REG_OFF	0xA80UL
#define QDMA_C2H_MM_CTRL_OFF	0x1004UL
#define QDMA_H2C_MM_CTRL_OFF	0x1204UL
#define QDMA_PIDX_UPD_OFF	0x6404UL

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
	uint64_t rsvd[26];
	uint64_t dma_reset;
} __packed;

// structure of QDMA indirect context programming registers
struct qdma_ctxt_reg {
	uint32_t reserved;
	uint32_t ctxt_data[4];
	uint32_t ctxt_mask[4];
	uint32_t ctxt_cmd;
} __packed;

struct qdma_qid2vec_reg {
	uint32_t qid;
	uint32_t map;
};

/**
 * check whether QDMA is used by checking for the QDMA interrupt controller
 * @param dev TLKM device
 * @return 1 if QDMA is in use, 0 otherwise
 */
int pcie_is_qdma_in_use(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	return (pdev->pdev->vendor == XILINX_VENDOR_ID &&
		pdev->pdev->device == VERSAL_DEVICE_ID);
}

/*
 * interrupt handlers when QDMA is in use
 */
irqreturn_t qdma_intr_handler_read(int irq, void *data)
{
	struct tlkm_irq_mapping *mapping = (struct tlkm_irq_mapping *)data;
	struct tlkm_pcie_device *pdev = mapping->dev->private_data;

	if (mapping->eventfd != 0) {
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)
		eventfd_signal(mapping->eventfd, 1);
#else
		// Linux commit 3652117 removes argument from eventfd_signal
		eventfd_signal(mapping->eventfd);
#endif
	}
	pdev->ack_register_aws[1] = QDMA_IRQ_ARM;
	return IRQ_HANDLED;
}

irqreturn_t qdma_intr_handler_write(int irq, void *data)
{
	struct tlkm_irq_mapping *mapping = (struct tlkm_irq_mapping *)data;
	struct tlkm_pcie_device *pdev = mapping->dev->private_data;

	if (mapping->eventfd != 0) {
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)
		eventfd_signal(mapping->eventfd, 1);
#else
		// Linux commit 3652117 removes argument from eventfd_signal
		eventfd_signal(mapping->eventfd);
#endif
	}
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
static int qdma_program_ind_context(struct qdma_ctxt_reg *ctxt_regs, uint32_t mask[4], uint32_t data[4], uint32_t ctxt_sel)
{
	int i;
	uint32_t w_val;
	for (i = 0; i < 4; ++i)
		iowrite32(mask[i], &ctxt_regs->ctxt_mask[i]);

	for (i = 0; i < 4; ++i)
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
	int res;
	uint32_t data[4], mask[4], *c2h_mm_ctrl, *h2c_mm_ctrl, *fmap_reg;
	resource_size_t qdma_bar_start, qdma_bar_len;
	struct qdma_ctxt_reg *ctxt_regs;
	struct qdma_qid2vec_reg *qid2vec_regs;
	struct tlkm_device *dev = pdev->parent;
	struct desc_gen_regs *desc_gen_regs =
		(struct desc_gen_regs *)(dev->mmap.plat +
					 tlkm_status_get_component_base(
						 dev, "PLATFORM_COMPONENT_DMA0"));

#ifdef CONFIG_ARM
	if ((ioread32(&desc_gen_regs->id) & 0xFFFFFFFF) != DESC_GEN_ID) {
#else
	if ((readq(&desc_gen_regs->id) & 0xFFFFFFFF) != DESC_GEN_ID) {
#endif
		DEVERR(dev->dev_id, "could not find QDMA descriptor generator");
		res = -ENODEV;
		goto fail_id;
	}

	// reset QDMA
#ifdef CONFIG_ARM
	iowrite32(1, &desc_gen_regs->dma_reset);
#else
	writeq(1, &desc_gen_regs->dma_reset);
#endif

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

	qid2vec_regs = ioremap(qdma_bar_start + QDMA_QID2VEC_REG_OFF, sizeof(*qid2vec_regs));
	if (!qid2vec_regs) {
		DEVERR(dev->dev_id, "Failed to map QDMA QID2VEC registers");
		res = -EFAULT;
		goto fail_qid2vecregs;
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

	fmap_reg = ioremap(qdma_bar_start + QDMA_TRQ_SEL_FMAP, sizeof(uint32_t));
	if (!fmap_reg) {
		DEVERR(dev->dev_id, "Failed to map QDMA FMAP selection register");
		res = -EFAULT;
		goto fail_fmap_remap;
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

	// setup SW context
	data[0] = QDMA_IRQ_ARM;
	data[1] = QDMA_SW_DESC_CTXT_QEN | QDMA_SW_DESC_CTXT_BYPASS
		  | QDMA_SW_DESC_CTXT_IRQ_EN | QDMA_SW_DESC_CTXT_IS_MM;
	data[2] = data[3] = 0;
	mask[0] = mask[1] = mask[2] = mask[3] = 0xFFFFFFFF;
	if (qdma_program_ind_context(ctxt_regs, mask, data, QDMA_CTXT_SELC_DEC_SW_C2H)) {
		DEVERR(dev->dev_id, "Failed to program QDMA C2H software context");
		res = -EACCES;
		goto fail_swc2h;
	}
	if (qdma_program_ind_context(ctxt_regs, mask, data, QDMA_CTXT_SELC_DEC_SW_H2C)) {
		DEVERR(dev->dev_id, "Failed to program QDMA H2C software context");
		res = -EACCES;
		goto fail_swh2c;
	}

	// program QID to vector table
	iowrite32(0, &qid2vec_regs->qid);
	iowrite32(QDMA_IRQ_VEC_C2H | (QDMA_IRQ_VEC_H2C << 9), &qid2vec_regs->map);

	// map queue to physical function PF0
	iowrite32(1 << 11, fmap_reg);

	DEVLOG(dev->dev_id, TLKM_LF_DMA, "Enable QDMA engines");
	iowrite32(1, c2h_mm_ctrl);
	iowrite32(1, h2c_mm_ctrl);

	iounmap(fmap_reg);
	iounmap(h2c_mm_ctrl);
	iounmap(c2h_mm_ctrl);
	iounmap(qid2vec_regs);
	iounmap(ctxt_regs);

	return 0;

fail_swh2c:
	qdma_inv_ind_context(ctxt_regs, QDMA_CTXT_SELC_DEC_SW_C2H);
fail_swc2h:
fail_ctxtclear:
	iounmap(pdev->ack_register_aws);
fail_ackregs:
	iounmap(fmap_reg);
fail_fmap_remap:
	iounmap(h2c_mm_ctrl);
fail_h2cmmctrl:
	iounmap(c2h_mm_ctrl);
fail_c2hmmctrl:
	iounmap(qid2vec_regs);
fail_qid2vecregs:
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

#ifdef CONFIG_ARM
	if ((ioread32(&desc_gen_regs->id) & 0xFFFFFFFF) != DESC_GEN_ID) {
#else
	if ((readq(&desc_gen_regs->id) & 0xFFFFFFFF) != DESC_GEN_ID) {
#endif
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