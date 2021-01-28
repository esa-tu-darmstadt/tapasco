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
#include "pcie/pcie_irq.h"
#include "pcie/pcie_device.h"

int pcie_irqs_init(struct tlkm_device *dev, struct list_head *interrupts)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

	pdev->ack_register =
		(volatile uint32_t *)(dev->mmap.plat +
				      tlkm_status_get_component_base(
					      dev, "PLATFORM_COMPONENT_INTC0") +
				      0x8120);
	return 0;
}

void pcie_irqs_exit(struct tlkm_device *dev)
{
}

irqreturn_t intr_handler_platform(int irq, void *data)
{
	struct tlkm_irq_mapping *mapping = (struct tlkm_irq_mapping *)data;
	struct tlkm_pcie_device *dev = mapping->dev->private_data;
	eventfd_signal(mapping->eventfd, 1);
	dev->ack_register[0] = mapping->irq_no;
	return IRQ_HANDLED;
}

int pcie_irqs_request_platform_irq(struct tlkm_device *dev,
				   struct tlkm_irq_mapping *mapping)
{
	int err = 0;
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "requesting platform irq #%d",
	       mapping->irq_no);
	if ((err = request_irq(pci_irq_vector(pdev->pdev, mapping->irq_no),
			       intr_handler_platform, IRQF_EARLY_RESUME,
			       TLKM_PCI_NAME, (void *)mapping))) {
		DEVERR(dev->dev_id, "could not request interrupt #%d: %d",
		       mapping->irq_no, err);
		return err;
	}

	DEVLOG(dev->dev_id, TLKM_LF_IRQ,
	       "interrupt line %d/%d assigned with return value %d",
	       mapping->irq_no, pci_irq_vector(pdev->pdev, mapping->irq_no),
	       err);
	return err;
}

void pcie_irqs_release_platform_irq(struct tlkm_device *dev,
				    struct tlkm_irq_mapping *mapping)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "freeing interrupt #%d",
	       mapping->irq_no);
	free_irq(pci_irq_vector(pdev->pdev, mapping->irq_no), (void *)mapping);
}
