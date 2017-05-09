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
//! @file	zynq_module.c
//! @brief	Tapasco support module: Device driver implementation
//!		for Zynq-7000 series devices. Provides support functions to
//!		implement Platform API upon.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/module.h>
#define LOGGING_MODULE_INCLUDE
#include "zynq_logging.h"
#undef LOGGING_MODULE_INCLUDE
#include "zynq_dmamgmt.h"
#include "zynq_device.h"
#include "zynq_irq.h"
#include "zynq_ioctl.h"

extern struct zynq_device zynq_dev;

static int __init zynq_module_init(void)
{
	int retval = 0;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	LOG(ZYNQ_LL_MODULE, "module loaded");
	retval = zynq_dmamgmt_init();
	if (retval < 0) {
		ERR("DMA management init failed!");
		goto exit;
	}

	retval = zynq_device_init();
	if (retval < 0) {
		ERR("device init failed!");
		goto err_chardev;
	}

	retval = zynq_irq_init();
	if (retval < 0) {
		ERR("irq init failed!");
		goto err_irq;
	}

	retval = zynq_ioctl_init();
	if (retval < 0) {
		ERR("ioctl init failed!");
		goto err_ioctl;
	}

	LOG(ZYNQ_LL_ENTEREXIT, "exit");
	return retval;

	zynq_ioctl_exit();
err_ioctl:
	zynq_irq_exit();
err_irq:
	zynq_device_exit();
err_chardev:
	zynq_dmamgmt_exit();
exit:
	LOG(ZYNQ_LL_ENTEREXIT, "exit with error");
	return retval;
}

static void __exit zynq_module_exit(void)
{
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	zynq_ioctl_exit();
	zynq_irq_exit();
	zynq_device_exit();
	zynq_dmamgmt_exit();
	LOG(ZYNQ_LL_MODULE, "unloading module");
	LOG(ZYNQ_LL_ENTEREXIT, "exit");
}

module_init(zynq_module_init);
module_exit(zynq_module_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)");
MODULE_DESCRIPTION("Tapasco Platform Module: Zynq-7000 series");
MODULE_VERSION("1.1");
