//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
//! @file	tlkm_module.c
//! @brief	Unified driver as a loadable kernel module (LKM) for Linux.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!             J. A. Hofmann (jah@esa.cs.tu-darmstadt.de)
//!             D. de la Chevallerie (dc@esa.cs.tu-darmstadt.de)
//!
#include <linux/module.h>
#include "tlkm_module.h"
#include "tlkm_logging.h"
#include "tlkm_bus.h"
#include "tlkm_ioctl.h"

extern
int is_zynq_machine(void);

static
int __init tlkm_module_init(void)
{
	int ret = 0;
	LOG(TLKM_LF_MODULE, "TaPaSCo loadable kernel module v" TLKM_VERSION);
	LOG(TLKM_LF_MODULE, "Zynq: %d", is_zynq_machine());

	if ((ret = tlkm_bus_init())) {
		ERR("failed to initialize TaPaSCo subsystem: %d", ret);
	}
	return ret;
}

static
void __exit tlkm_module_exit(void)
{
	tlkm_bus_exit();
	LOG(TLKM_LF_MODULE, "TaPaSCo loadable kernel module unloaded.");
}

module_init(tlkm_module_init);
module_exit(tlkm_module_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("J. Korinth <jk@esa.cs.tu-darmstadt.de>");
MODULE_AUTHOR("J. Hofmann <jah@esa.cs.tu-darmstadt.de>");
MODULE_AUTHOR("D. de la Chevallerie <dc@esa.cs.tu-darmstadt.de>");
MODULE_DESCRIPTION("Unified device driver for TaPaSCo - the Task Parallel "
		"System Composer.");
MODULE_VERSION(TLKM_VERSION);
MODULE_ALIAS("tapasco");
