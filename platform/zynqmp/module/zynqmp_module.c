//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	zynqmp_module.c
//! @brief	Tapasco support module: Device driver implementation
//!		for Zynq-7000 series devices. Provides support functions to
//!		implement Platform API upon.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/module.h>
#define LOGGING_MODULE_INCLUDE
#include "zynqmp_logging.h"
#undef LOGGING_MODULE_INCLUDE
#include "zynqmp_dmamgmt.h"
#include "zynqmp_device.h"
#include "zynqmp_irq.h"
#include "zynqmp_ioctl.h"

extern struct zynqmp_device zynqmp_dev;

static int __init zynqmp_module_init(void)
{
	int retval = 0;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	LOG(ZYNQ_LL_MODULE, "module loaded");

	retval = zynqmp_ioctl_init();
	if (retval < 0) {
		ERR("ioctl init failed!");
		goto exit;
	}

	retval = zynqmp_dmamgmt_init();
	if (retval < 0) {
		ERR("DMA management init failed!");
		goto err_dmamgmt;
	}

	retval = zynqmp_device_init();
	if (retval < 0) {
		ERR("device init failed!");
		goto err_chardev;
	}

	retval = zynqmp_irq_init();
	if (retval < 0) {
		ERR("irq init failed!");
		goto err_irq;
	}

	LOG(ZYNQ_LL_ENTEREXIT, "exit");
	return retval;

err_irq:
	zynqmp_device_exit();
err_chardev:
	zynqmp_dmamgmt_exit(zynqmp_ioctl_get_device());
err_dmamgmt:
	zynqmp_ioctl_exit();
exit:
	LOG(ZYNQ_LL_ENTEREXIT, "exit with error");
	return retval;
}

static void __exit zynqmp_module_exit(void)
{
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	zynqmp_irq_exit();
	zynqmp_device_exit();
	zynqmp_dmamgmt_exit(zynqmp_ioctl_get_device());
	zynqmp_ioctl_exit();
	LOG(ZYNQ_LL_MODULE, "unloading module");
	LOG(ZYNQ_LL_ENTEREXIT, "exit");
}

module_init(zynqmp_module_init);
module_exit(zynqmp_module_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)");
MODULE_DESCRIPTION("Tapasco Platform Module: Zynq-7000 series");
MODULE_VERSION("1.1");
