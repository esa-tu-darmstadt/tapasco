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
#ifndef ZYNQMP_H__
#define ZYNQMP_H__

#include "tlkm_platform.h"

#define ZYNQMP_NAME "xlnx,zynqmp"
#define ZYNQMP_CLASS_NAME "zynqmp"

#define ZYNQMP_DEF INIT_PLATFORM(0xB0000000, 0x0002000 /* status */)

static const struct platform zynqmp_def = ZYNQMP_DEF;

#ifdef __KERNEL__
#include "tlkm_class.h"
#include "zynq_device.h"
#include "zynq_ioctl.h"
#include "zynq_irq.h"

static inline void zynqmp_remove(struct tlkm_class *cls)
{
}

static const struct tlkm_class zynqmp_cls = {
	.name = ZYNQMP_CLASS_NAME,
	.create = zynq_device_init,
	.destroy = zynq_device_exit,
	.init_subsystems = zynq_device_init_subsystems,
	.exit_subsystems = zynq_device_exit_subsystems,
	.probe = zynqmp_device_probe,
	.remove = zynq_remove,
	.ioctl = zynq_ioctl,
	.pirq = zynq_irq_request_platform_irq,
	.rirq = zynq_irq_release_platform_irq,
	.npirqs = 16,
	.platform = ZYNQMP_DEF,
	.private_data = NULL,
};
#endif /* __KERNEL__ */

#endif /* ZYNQMP_H__ */
