/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
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
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/device.h>
#include <linux/version.h>
#include <linux/atomic.h>
#include <linux/eventfd.h>
#include "tlkm_logging.h"
#include "tlkm_control.h"
#include "pcie/pcie.h"
#include "pcie/pcie_irq_aws.h"
#include "pcie/pcie_device.h"

#define IRQS_PER_CONTROLLER 32
#define NUM_DIRECT_IRQS 4

uint32_t get_xdma_reg_addr(uint32_t target, uint32_t channel, uint32_t offset)
{
	return ((target << 12) | (channel << 8) | offset);
}

static int aws_ec2_configure_xdma(struct tlkm_pcie_device *pdev)
{
	dev_id_t const did = pdev->parent->dev_id;
	struct pci_dev *dev = pdev->pdev;

	void __iomem *bar2;
	uint32_t val;

	DEVLOG(did, TLKM_LF_PCIE, "Mapping BAR2 and configuring XDMA core");
	bar2 = ioremap(pci_resource_start(dev, 2), pci_resource_len(dev, 2));

	if (!bar2) {
		DEVERR(did, "XDMA ioremap failed");
		return -ENODEV;
	}

	DEVLOG(did, TLKM_LF_PCIE, "XDMA addr: %p", bar2);
	DEVLOG(did, TLKM_LF_PCIE, "XDMA len: %x",
	       (int)pci_resource_len(dev, 2));

	val = ioread32(bar2 + get_xdma_reg_addr(2, 0, 0));
	DEVLOG(did, TLKM_LF_PCIE, "XDMA IRQ block identifier: %x", val);

	/* set user interrupt vectors */
	iowrite32(0x03020100, bar2 + get_xdma_reg_addr(2, 0, 0x80));
	iowrite32(0x07060504, bar2 + get_xdma_reg_addr(2, 0, 0x84));
	iowrite32(0x0b0a0908, bar2 + get_xdma_reg_addr(2, 0, 0x88));
	iowrite32(0x0f0e0d0c, bar2 + get_xdma_reg_addr(2, 0, 0x8c));

	/* set user interrupt enable mask */
	iowrite32(0xffff, bar2 + get_xdma_reg_addr(2, 0, 0x04));
	wmb();

	val = ioread32(bar2 + get_xdma_reg_addr(2, 0, 0x04));
	DEVLOG(did, TLKM_LF_PCIE, "XDMA user IER: %x", val);

	DEVLOG(did, TLKM_LF_PCIE,
	       "Finished configuring XDMA core, unmapping BAR2");
	iounmap(bar2);
	return 0;
}

irqreturn_t aws_irq_handler(int irq, void *data)
{
	struct zynq_irq_mapping *mapping = (struct zynq_irq_mapping *)data;
	struct tlkm_irq_mapping *m_start = mapping->mapping;

	u32 status;
	u32 s_off = mapping->start;

	volatile u32 *intc = mapping->intc;

	if (!m_start) {
		LOG(TLKM_LF_IRQ, "IRQ %d not initialized", mapping->id);
		return IRQ_HANDLED;
	}

	while ((status = intc[0])) {
		do {
			u32 slot = __builtin_ffs(status) - 1;
			u32 slot_shifted = slot + s_off;

			while (m_start->irq_no < slot_shifted) {
				if (m_start->list.next !=
				    mapping->mapping_base) {
					m_start = list_entry(
						m_start->list.next,
						struct tlkm_irq_mapping, list);
				} else {
					break;
				}
			}
			if (m_start->irq_no == slot_shifted) {
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)
				eventfd_signal(m_start->eventfd, 1);
#else
				// Linux commit 3652117 removes argument from eventfd_signal
				eventfd_signal(m_start->eventfd);
#endif
			} else {
				// Got interrupt for unregistered interrupt
				LOG(TLKM_LF_IRQ,
				    "Got interrupt %d which is not registered",
				    slot_shifted);
			}

			status ^= (1U << slot);
		} while (status);
	}

	return IRQ_HANDLED;
}

int pcie_aws_irqs_init(struct tlkm_device *dev, struct list_head *interrupts)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

	int err = 0, i;
	char *namebuf;
	int rirq;

	err = aws_ec2_configure_xdma(pdev);

	pcie_irqs_init(dev, interrupts);

	pdev->ack_register_aws =
		(volatile uint32_t *)(dev->mmap.plat +
				      tlkm_status_get_component_base(
					      dev, "PLATFORM_COMPONENT_INTC0") +
				      0x8124);

	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "registering %d interrupts ...",
	       AWS_NUM_IRQ_CONTROLLERS);

	pdev->requested_irq_num = 0;

	for (i = 0; i < AWS_NUM_IRQ_CONTROLLERS; ++i) {
		rirq = NUM_DIRECT_IRQS + i;

		pdev->intc_bases[i].intc = &pdev->ack_register_aws[i];
		pdev->intc_bases[i].mapping_base = interrupts;
		pdev->intc_bases[i].mapping = 0;
		pdev->intc_bases[i].start =
			i * IRQS_PER_CONTROLLER + NUM_DIRECT_IRQS;
		pdev->intc_bases[i].id = i;

		LOG(TLKM_LF_IRQ, "controller for IRQ #%d at 0x%p", rirq,
		    pdev->intc_bases[i].intc);

		LOG(TLKM_LF_IRQ, "registering IRQ #%d", rirq);

		namebuf = kzalloc(128, GFP_KERNEL);
		snprintf(namebuf, 128, "tapasco_pcie_%d", i);

#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 12, 0)
		pdev->intc_bases[i].name = namebuf;
#endif

		err = request_irq(pci_irq_vector(pdev->pdev, rirq),
				  aws_irq_handler, IRQF_EARLY_RESUME, namebuf,
				  &pdev->intc_bases[i]);

		++pdev->requested_irq_num;

		if (err) {
			ERR("could not register IRQ #%d!", rirq);
			goto err;
		}
	}
	return err;

err:
	while (--pdev->requested_irq_num >= 0) {
		free_irq(pci_irq_vector(pdev->pdev, rirq),
			 &pdev->intc_bases[pdev->requested_irq_num]);
	}
	return err;
}

void pcie_aws_irqs_exit(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	int rirq = 0;
	int irq = 0;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 12, 0)
	const char *namebuf;
#endif

	pcie_irqs_exit(dev);

	while (pdev->requested_irq_num) {
		--pdev->requested_irq_num;
		irq = NUM_DIRECT_IRQS + pdev->requested_irq_num;
		rirq = pci_irq_vector(pdev->pdev, irq);
		LOG(TLKM_LF_IRQ, "releasing IRQ %d -> #%d", irq, rirq);
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 12, 0)
		free_irq(rirq, &pdev->intc_bases[pdev->requested_irq_num]);
		kfree(pdev->intc_bases[pdev->requested_irq_num].name);
#else
		namebuf = free_irq(rirq,
				   &pdev->intc_bases[pdev->requested_irq_num]);
		if (namebuf)
			kfree(namebuf);
#endif
	}
}

int pcie_aws_irqs_request_platform_irq(struct tlkm_device *dev,
				       struct tlkm_irq_mapping *mapping)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	int irq_no_request = mapping->irq_no;
	int shifted_irq_no = irq_no_request - NUM_DIRECT_IRQS;
	int irq_controller = shifted_irq_no / IRQS_PER_CONTROLLER;

	if (mapping->irq_no < NUM_DIRECT_IRQS) {
		pcie_irqs_request_platform_irq(dev, mapping);
	} else {
		LOG(TLKM_LF_IRQ,
		    "Got request to add IRQ %d belonging to controller %d",
		    irq_no_request, irq_controller);

		if (!pdev->intc_bases[irq_controller].mapping) {
			LOG(TLKM_LF_IRQ,
			    "Added first mapping for controller %d",
			    irq_controller);
			pdev->intc_bases[irq_controller].mapping = mapping;
		} else if (pdev->intc_bases[irq_controller].mapping->irq_no >
			   irq_no_request) {
			pdev->intc_bases[irq_controller].mapping = mapping;
			LOG(TLKM_LF_IRQ,
			    "Replaced previous mapping for controller %d",
			    irq_controller);
		} else {
			LOG(TLKM_LF_IRQ, "Mapping already part of mapping %d",
			    irq_controller);
		}
	}

	return 0;
}

void pcie_aws_irqs_release_platform_irq(struct tlkm_device *dev,
					struct tlkm_irq_mapping *mapping)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	int irq_no_request = mapping->irq_no;
	int shifted_irq_no = irq_no_request - NUM_DIRECT_IRQS;
	int irq_controller = shifted_irq_no / IRQS_PER_CONTROLLER;

	struct tlkm_irq_mapping *m_start = mapping;

	if (mapping->irq_no < NUM_DIRECT_IRQS) {
		pcie_irqs_release_platform_irq(dev, mapping);
	} else {
		LOG(TLKM_LF_IRQ,
		    "Got request to remove IRQ %d belonging to controller %d",
		    irq_no_request, irq_controller);

		if (!pdev->intc_bases[irq_controller].mapping) {
			LOG(TLKM_LF_IRQ, "Controller %d is already empty",
			    irq_controller);
		} else if (pdev->intc_bases[irq_controller].mapping->irq_no ==
			   irq_no_request) {
			if (m_start->list.next !=
			    pdev->intc_bases[irq_controller].mapping_base) {
				m_start = list_entry(m_start->list.next,
						     struct tlkm_irq_mapping,
						     list);

				if (((m_start->irq_no - NUM_DIRECT_IRQS) /
				     IRQS_PER_CONTROLLER) == irq_controller) {
					pdev->intc_bases[irq_controller]
						.mapping = m_start;
					LOG(TLKM_LF_IRQ,
					    "Controller %d start has been updated",
					    irq_controller);
				} else {
					LOG(TLKM_LF_IRQ,
					    "Controller %d is now empty",
					    irq_controller);
					pdev->intc_bases[irq_controller]
						.mapping = 0;
				}
			} else {
				LOG(TLKM_LF_IRQ, "Controller %d is now empty",
				    irq_controller);
				pdev->intc_bases[irq_controller].mapping = 0;
			}

		} else {
			LOG(TLKM_LF_IRQ, "Mapping not first of controller %d",
			    irq_controller);
		}
	}
}