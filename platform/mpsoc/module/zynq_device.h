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
//! @file	zynq_device.h
//! @brief	Device struct for zynq TPC Platform device.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __ZYNQ_DEVICE_H__
#define __ZYNQ_DEVICE_H__

#include <linux/miscdevice.h>
#include "zynq_platform.h"

#define ZYNQ_DEVICE_CLSNAME					"tapasco_platform"
#define ZYNQ_DEVICE_DEVNAME					"zynq"
#define ZYNQ_DEVICE_THREADS_BASE				(0x43c00000)
#define ZYNQ_DEVICE_THREADS_OFFS				(0x00010000)
#define ZYNQ_DEVICE_THREADS_NUM					(128)
#define ZYNQ_DEVICE_INTC_BASE					ZYNQ_PLATFORM_INTC_BASE
#define ZYNQ_DEVICE_INTC_OFFS					ZYNQ_PLATFORM_INTC_OFFS
#define ZYNQ_DEVICE_INTC_NUM					ZYNQ_PLATFORM_INTC_NUM
#define ZYNQ_DEVICE_TAPASCO_STATUS_BASE				(0x77770000)
#define ZYNQ_DEVICE_TAPASCO_STATUS_SIZE				(0x00001000)

struct zynq_device {
	int			devnum;
	struct miscdevice	miscdev[3];
	void __iomem 		*gp_map[2];
	void __iomem		*tapasco_status;
	volatile long		pending_ev[ZYNQ_DEVICE_THREADS_NUM];
	volatile unsigned long	total_ev;
	wait_queue_head_t	ev_q[ZYNQ_DEVICE_THREADS_NUM];
};

int zynq_device_init(void);
void zynq_device_exit(void);

#endif /* __ZYNQ_DEVICE_H__ */
