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
#ifndef SIM_H__
#define SIM_H__

#include "tlkm_platform.h"

#define SIM_NAME "sim"
#define SIM_CLASS_NAME "sim"

#define SIM_DEF INIT_PLATFORM(0x80000000, 0x00002000 /* status */)

static const struct platform sim_def = SIM_DEF;

#ifdef __KERNEL__
#include "tlkm_class.h"
#include "sim_device.h"
#include "sim_ioctl.h"
#include "sim_irq.h"

static inline void sim_remove(struct tlkm_class *cls)
{
}

static const struct tlkm_class sim_cls = {
  .name = SIM_CLASS_NAME,
  .create = sim_device_init,
  .destroy = sim_device_exit,
  .init_subsystems = sim_device_init_subsystems,
  .exit_subsystems = sim_device_exit_subsystems,
  .probe = sim_device_probe,
  .remove = sim_remove,
  .init_interrupts = sim_irq_init,
  .exit_interrupts = sim_irq_exit,
  .pirq = sim_irq_request_platform_irq,
  .rirq = sim_irq_release_platform_irq,
  .number_of_interrupts = 132,
  .private_data = NULL,
};

#endif /* __KERNEL__ */

#endif /* SIM_H__ */
