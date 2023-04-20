/*
 * Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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
//! @file	sim_device.c
//! @brief	Unified driver as a loadable kernel module (LKM) for Linux.
//!
#ifndef SIM_DEVICE_H__
#define SIM_DEVICE_H__

#include <linux/version.h>

#include "tlkm_types.h"
#include "tlkm_class.h"
#include "tlkm_device.h"

struct sim_device {
	struct tlkm_device *parent;
	struct list_head *interrupts;
};

int sim_device_init(struct tlkm_device *dev, void *data);
void sim_device_exit(struct tlkm_device *dev);
int sim_device_init_subsystems(struct tlkm_device *dev, void *data);
void sim_device_exit_subsystems(struct tlkm_device *dev);

int sim_device_probe(struct tlkm_class *cls);

#endif /* SIM_DEVICE_H__ */
