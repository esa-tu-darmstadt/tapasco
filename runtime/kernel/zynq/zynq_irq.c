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

#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/sched.h>
#include <linux/of.h>
#include <linux/of_irq.h>
#include <linux/eventfd.h>
#include "tlkm_logging.h"
#include "tlkm_slots.h"
#include "zynq_irq.h"

#define IRQS_PER_CONTROLLER 32

static irqreturn_t zynq_irq_handler(int irq, void *data)
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
		intc[3] = status;
		do {
			u32 slot = __builtin_ffs(status) - 1;
			slot += s_off;

			while (m_start->irq_no < slot) {
				if (m_start->list.next !=
				    mapping->mapping_base) {
					m_start = list_entry(
						m_start->list.next,
						struct tlkm_irq_mapping, list);
				} else {
					break;
				}
			}
			if (m_start->irq_no == slot) {
				eventfd_signal(m_start->eventfd, 1);
			} else {
				// Got interrupt for unregistered interrupt
				LOG(TLKM_LF_IRQ,
				    "Got interrupt %d which is not registered",
				    slot);
			}

			status ^= (1U << slot);
		} while (status);
	}
	return IRQ_HANDLED;
}

static void zynq_init_intc(struct zynq_device *zynq_dev, volatile u32 *intc)
{
	u32 status;
	intc[2] = -1;
	intc[7] = 3;
	status = intc[0];
}

void zynq_irq_exit(struct tlkm_device *dev)
{
	struct zynq_device *zdev = (struct zynq_device *)dev->private_data;
	int rirq = 0;
	const char *namebuf;
	while (zdev->requested_irq_num) {
		--zdev->requested_irq_num;
		rirq = irq_of_parse_and_map(of_find_node_by_name(NULL,
								 "tapasco"),
					    zdev->requested_irq_num);
		LOG(TLKM_LF_IRQ, "releasing IRQ #%d", rirq);
		disable_irq(rirq);
		namebuf = free_irq(rirq,
				   &zdev->intc_bases[zdev->requested_irq_num]);
		if (namebuf)
			kfree(namebuf);
	}
}

int zynq_irq_init(struct tlkm_device *dev, struct list_head *interrupts)
{
	struct zynq_device *zdev = (struct zynq_device *)dev->private_data;
	int retval = 0, rirq = 0;
	int i = 0;
	char buffer[128];
	char *namebuf;
	dev_addr_t offset;
	zdev->requested_irq_num = 0;

	for (i = 0; i < ZYNQ_MAX_NUM_INTCS; ++i) {
		rirq = irq_of_parse_and_map(of_find_node_by_name(NULL,
								 "tapasco"),
					    zdev->requested_irq_num);
		snprintf(buffer, 128, "PLATFORM_COMPONENT_INTC%d", i);
		offset = tlkm_status_get_component_base(dev, buffer);
		LOG(TLKM_LF_IRQ, "INTC%d offset is 0x%lx", i, offset);

		if (offset != -1) {
			zdev->intc_bases[i].intc =
				(u32 *)((uintptr_t)dev->mmap.plat +
					(uintptr_t)offset);
			zdev->intc_bases[i].mapping_base = interrupts;
			zdev->intc_bases[i].mapping = 0;
			zdev->intc_bases[i].start = i * IRQS_PER_CONTROLLER;
			zdev->intc_bases[i].id = i;

			LOG(TLKM_LF_IRQ, "controller for IRQ #%d at 0x%p", rirq,
			    zdev->intc_bases[i].intc);
			zynq_init_intc(zdev, zdev->intc_bases[i].intc);
			LOG(TLKM_LF_IRQ, "registering IRQ #%d", rirq);

			namebuf = kzalloc(128, GFP_KERNEL);
			snprintf(namebuf, 128, "tapasco_zynq_%d", i);

			retval = request_irq(rirq, zynq_irq_handler,
					     IRQF_EARLY_RESUME, namebuf,
					     &zdev->intc_bases[i]);

			++zdev->requested_irq_num;

			if (retval) {
				ERR("could not register IRQ #%d!", rirq);
				goto err;
			}
		}
	}
	return retval;

err:
	while (--zdev->requested_irq_num >= 0) {
		disable_irq(rirq);
		free_irq(rirq, &zdev->intc_bases[zdev->requested_irq_num]);
	}
	return retval;
}

int zynq_irq_request_platform_irq(struct tlkm_device *dev,
				  struct tlkm_irq_mapping *mapping)
{
	struct zynq_device *zdev = (struct zynq_device *)dev->private_data;
	int irq_no_request = mapping->irq_no;
	int irq_controller = irq_no_request / IRQS_PER_CONTROLLER;

	LOG(TLKM_LF_IRQ, "Got request to add IRQ %d belonging to controller %d",
	    irq_no_request, irq_controller);

	if (!zdev->intc_bases[irq_controller].mapping) {
		LOG(TLKM_LF_IRQ, "Added first mapping for controller %d",
		    irq_controller);
		zdev->intc_bases[irq_controller].mapping = mapping;
	} else if (zdev->intc_bases[irq_controller].mapping->irq_no >
		   mapping->irq_no) {
		zdev->intc_bases[irq_controller].mapping = mapping;
		LOG(TLKM_LF_IRQ, "Replaced previous mapping for controller %d",
		    irq_controller);
	} else {
		LOG(TLKM_LF_IRQ, "Mapping already part of mapping %d",
		    irq_controller);
	}

	return 0;
}

void zynq_irq_release_platform_irq(struct tlkm_device *dev,
				   struct tlkm_irq_mapping *mapping)
{
	struct zynq_device *zdev = (struct zynq_device *)dev->private_data;
	int irq_no_request = mapping->irq_no;
	int irq_controller = irq_no_request / IRQS_PER_CONTROLLER;
	struct tlkm_irq_mapping *m_start = mapping;

	LOG(TLKM_LF_IRQ,
	    "Got request to remove IRQ %d belonging to controller %d",
	    irq_no_request, irq_controller);

	if (!zdev->intc_bases[irq_controller].mapping) {
		LOG(TLKM_LF_IRQ, "Controller %d is already empty",
		    irq_controller);
	} else if (zdev->intc_bases[irq_controller].mapping->irq_no ==
		   mapping->irq_no) {
		if (m_start->list.next !=
		    zdev->intc_bases[irq_controller].mapping_base) {
			m_start = list_entry(m_start->list.next,
					     struct tlkm_irq_mapping, list);

			if ((m_start->irq_no / IRQS_PER_CONTROLLER) ==
			    irq_controller) {
				zdev->intc_bases[irq_controller].mapping =
					m_start;
				LOG(TLKM_LF_IRQ,
				    "Controller %d start has been updated",
				    irq_controller);
			} else {
				LOG(TLKM_LF_IRQ, "Controller %d is now empty",
				    irq_controller);
				zdev->intc_bases[irq_controller].mapping = 0;
			}
		} else {
			LOG(TLKM_LF_IRQ, "Controller %d is now empty",
			    irq_controller);
			zdev->intc_bases[irq_controller].mapping = 0;
		}

	} else {
		LOG(TLKM_LF_IRQ, "Mapping not first of controller %d",
		    irq_controller);
	}
}
