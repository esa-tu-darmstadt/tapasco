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
#ifndef TLKM_CLASS_H__
#define TLKM_CLASS_H__

#include <linux/interrupt.h>
#include "tlkm_types.h"
#include "tlkm_platform.h"

#define TLKM_CLASS_NAME_LEN 30

struct tlkm_device;
struct tlkm_class;

typedef int (*tlkm_class_create_f)(struct tlkm_device *, void *data);
typedef void (*tlkm_class_destroy_f)(struct tlkm_device *);
typedef int (*tlkm_class_init_subsystems_f)(struct tlkm_device *, void *data);
typedef void (*tlkm_class_exit_subsystems_f)(struct tlkm_device *);
typedef int (*tlkm_class_probe_f)(struct tlkm_class *);
typedef void (*tlkm_class_remove_f)(struct tlkm_class *);

typedef long (*tlkm_device_ioctl_f)(struct tlkm_device *, unsigned int ioctl,
				    unsigned long data);
typedef int (*tlkm_device_pirq_f)(struct tlkm_device *, int irq_no,
				  irq_handler_t h, void *data);
typedef void (*tlkm_device_rirq_f)(struct tlkm_device *, int irq_no);

struct tlkm_class {
	char name[TLKM_CLASS_NAME_LEN];
	tlkm_class_create_f create;
	tlkm_class_destroy_f destroy;
	tlkm_class_init_subsystems_f init_subsystems;
	tlkm_class_exit_subsystems_f exit_subsystems;
	tlkm_class_probe_f probe;
	tlkm_class_remove_f remove;
	tlkm_device_ioctl_f ioctl; /* ioctl implementation */
	tlkm_device_pirq_f pirq; /* request platform IRQ */
	tlkm_device_rirq_f rirq; /* release platform IRQ */
	size_t npirqs; /* number of platform interrupts */
	struct platform platform; /* register space definitions */
	void *private_data;
};

#endif /* TLKM_CLASS_H__ */
