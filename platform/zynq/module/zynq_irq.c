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
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/version.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/io.h>
#include <linux/sched.h>
#include "zynq_irq.h"
#include "zynq_logging.h"
#include "zynq_device.h"

#define ZYNQ_IRQ_BASE_IRQ					(45)

extern struct zynq_device zynq_dev;

static irqreturn_t zynq_irq_handler(int irq, void *dev_id)
{
	u32 status;
	struct zynq_device *zynq_dev = (struct zynq_device *)dev_id;
	s32 *intc = (s32 *)zynq_dev->gp_map[1];
	long intcn = irq - ZYNQ_IRQ_BASE_IRQ, irq_no = 0;

	intc += (intcn * ZYNQ_DEVICE_INTC_OFFS) >> 2;
	status = ioread32(intc); // read ISR
	iowrite32(status, intc + (0x0c >> 2));
	intcn <<= 5; // * 32
	LOG(ZYNQ_LL_IRQ, "irq = %d, status = 0x%08x, intcn = %ld", irq, status, intcn);
	while (status > 0) {
		if (status & 1) {
			__atomic_fetch_add(&zynq_dev->pending_ev[intcn + irq_no], 1, __ATOMIC_SEQ_CST);
			__atomic_fetch_add(&zynq_dev->total_ev, 1, __ATOMIC_SEQ_CST);
			// wake up sleepers
			wake_up_interruptible(&zynq_dev->ev_q[intcn + irq_no]);
		}
		status >>= 1;
		++irq_no;
	}
	return IRQ_HANDLED;
}

int zynq_irq_init(void)
{
	int retval = 0, irqn = ZYNQ_DEVICE_INTC_NUM, i;
	s32 *intc = (s32 *)zynq_dev.gp_map[1];
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	for (i = 0; i < ZYNQ_DEVICE_THREADS_NUM; ++i)
		zynq_dev.pending_ev[i] = 0; // clear pending events

	while (! retval && irqn) {
		--irqn;
		LOG(ZYNQ_LL_IRQ, "registering IRQ #%d", ZYNQ_IRQ_BASE_IRQ + irqn);
		retval = request_irq(ZYNQ_IRQ_BASE_IRQ + irqn, zynq_irq_handler,
				IRQF_TRIGGER_NONE | IRQF_ONESHOT,
				ZYNQ_DEVICE_CLSNAME "_" ZYNQ_DEVICE_DEVNAME,
				&zynq_dev);
		// enable all irqs
		iowrite32(0xffffffffUL, intc + ((irqn * ZYNQ_DEVICE_INTC_OFFS + 0x08) >> 2));
		iowrite32(0xffffffffUL, intc + ((irqn * ZYNQ_DEVICE_INTC_OFFS + 0x1c) >> 2));
		ioread32(intc); // read ISR
		intc += ZYNQ_DEVICE_INTC_OFFS >> 2; // next INTC
	}

	if (retval) {
		ERR("could not register IRQ #%d!", ZYNQ_IRQ_BASE_IRQ + irqn);
		goto err;
	}

	LOG(ZYNQ_LL_ENTEREXIT, "exit");
	return retval;

err:
	while (++irqn < ZYNQ_DEVICE_INTC_NUM) {
		disable_irq(ZYNQ_IRQ_BASE_IRQ + irqn);
		free_irq(ZYNQ_IRQ_BASE_IRQ + irqn, &zynq_dev);
	}
	LOG(ZYNQ_LL_ENTEREXIT, "exit with error");
	return retval;
}

void zynq_irq_exit(void)
{
	int irqn = ZYNQ_DEVICE_INTC_NUM;
	u32 *intc = (u32 *)zynq_dev.gp_map[1];
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	while (irqn) {
		--irqn;
		LOG(ZYNQ_LL_IRQ, "releasing IRQ #%d", ZYNQ_IRQ_BASE_IRQ + irqn);
		// ack all ints
		iowrite32(0xffffffffUL, intc + ((irqn * ZYNQ_DEVICE_INTC_OFFS) >> 2));
		// mask all ints
		iowrite32(0, intc + ((irqn * ZYNQ_DEVICE_INTC_OFFS + 0x08) >> 2));
		iowrite32(0, intc + ((irqn * ZYNQ_DEVICE_INTC_OFFS + 0x1C) >> 2));
		disable_irq(ZYNQ_IRQ_BASE_IRQ + irqn);
		free_irq(ZYNQ_IRQ_BASE_IRQ + irqn, &zynq_dev);
	}
	LOG(ZYNQ_LL_ENTEREXIT, "exit");
}
