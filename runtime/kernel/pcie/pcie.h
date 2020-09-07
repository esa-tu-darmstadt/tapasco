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
#ifndef PCIE_H__
#define PCIE_H__

#include "tlkm_platform.h"

#define TLKM_PCI_NAME "tlkm"
#define PCIE_CLS_NAME "pcie"
#define XILINX_VENDOR_ID 0x10EE
#define XILINX_DEVICE_ID 0x7038
#define AWS_EC2_VENDOR_ID 0x1D0F
#define AWS_EC2_DEVICE_ID 0xF000

#define PCIE_DEF INIT_PLATFORM(0x0ULL, 0x00002000 /* status */)

static const struct platform pcie_def = PCIE_DEF;

#ifdef __KERNEL__
#include "tlkm_class.h"
#include "pcie/pcie_device.h"
#include "pcie/pcie_irq.h"
#include "pcie/pcie_ioctl.h"

int pcie_init(struct tlkm_class *cls);
void pcie_exit(struct tlkm_class *cls);

static const struct tlkm_class pcie_cls = {
	.name = PCIE_CLS_NAME,
	.create = pcie_device_create,
	.destroy = pcie_device_destroy,
	.init_subsystems = pcie_device_init_subsystems,
	.exit_subsystems = pcie_device_exit_subsystems,
	.probe = pcie_init,
	.remove = pcie_exit,
	.pirq = pcie_irqs_request_platform_irq,
	.rirq = pcie_irqs_release_platform_irq,
	.ioctl = pcie_ioctl,
	.addr2map = pcie_device_addr2map_off,
	.npirqs = 4,
	.platform = PCIE_DEF,
	.private_data = NULL,
};
#endif /* __KERNEL__ */

#endif /* PCIE_H__ */
