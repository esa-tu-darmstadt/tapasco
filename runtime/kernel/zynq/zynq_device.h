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
#ifndef ZYNQ_DEVICE_H__
#define ZYNQ_DEVICE_H__

#include <linux/version.h>

#include "tlkm_types.h"
#include "tlkm_class.h"
#include "tlkm_device.h"

#define ZYNQ_MAX_NUM_INTCS 4

struct zynq_irq_mapping {
	struct list_head *mapping_base;
	struct tlkm_irq_mapping *mapping;
	volatile u32 *intc;
	u32 start;
	u32 id;
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 12, 0)
	const char *name;
#endif
};

struct zynq_device {
	struct tlkm_device *parent;
	struct list_head *interrupts;
	struct zynq_irq_mapping intc_bases[ZYNQ_MAX_NUM_INTCS];
	int requested_irq_num;
};

int zynq_device_init(struct tlkm_device *dev, void *data);
void zynq_device_exit(struct tlkm_device *dev);
int zynq_device_init_subsystems(struct tlkm_device *dev, void *data);
void zynq_device_exit_subsystems(struct tlkm_device *dev);

int zynq_device_probe(struct tlkm_class *cls);
int zynqmp_device_probe(struct tlkm_class *cls);

#endif /* ZYNQ_DEVICE_H__ */
