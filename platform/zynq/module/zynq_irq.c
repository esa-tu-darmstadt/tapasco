//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
#include "zynq_async.h"

#define ZYNQ_IRQ_BASE_IRQ					(45)

#if (ZYNQ_PLATFORM_INTC_MAX_NUM != 4)
#error "must update zynq_irq.c when changing ZYNQ_PLATFORM_INTC_MAX_NUM"
#endif

#define INTERRUPT_CONTROLLERS \
		_X(0) \
		_X(1) \
		_X(2) \
		_X(3)

extern struct zynq_device zynq_dev;

typedef struct {
	u32 base;
	u32 status;
} intc_t;

#ifdef _X
	#undef _X
#endif

#define		_X(N) intc_t intc_ ## N;
static struct {
	INTERRUPT_CONTROLLERS
} zynq_irq;
#undef _X

#define		_X(N) \
static void zynq_irq_func_ ## N(struct work_struct *work) \
{ \
	u32 s_off = (N * 32U); \
	u32 status = zynq_irq.intc_ ## N.status; \
	LOG(ZYNQ_LL_IRQ, "status = 0x%08x, intcn = %d", status, N); \
	while (status > 0) { \
		if (status & 1) { \
			async_signal_slot_interrupt(s_off++); \
		} \
		status >>= 1; \
	} \
} \
\
static DECLARE_WORK(zynq_irq_work_ ## N, zynq_irq_func_ ## N); \
\
static irqreturn_t zynq_irq_handler_ ## N(int irq, void *dev_id) \
{ \
	u32 status; \
	struct zynq_device *zynq_dev = (struct zynq_device *)dev_id; \
	u32 *intc = (u32 *)zynq_dev->gp_map[1] + zynq_irq.intc_ ## N.base; \
	status = ioread32(intc); \
	LOG(ZYNQ_LL_IRQ, "intcn = %d, status = 0x%08x", N, status); \
	iowrite32(status, intc + (0x0c >> 2)); \
	zynq_irq.intc_ ## N.status |= status; \
	schedule_work(&zynq_irq_work_ ## N); \
	return IRQ_HANDLED; \
}

INTERRUPT_CONTROLLERS
#undef _X

static
void zynq_init_intc(u32 const base)
{
	u32 *intc = (u32 *)zynq_dev.gp_map[1] + base;
	iowrite32((u32)-1, intc + (0x08 >> 2));
	iowrite32((u32) 3, intc + (0x1c >> 2));
	ioread32(intc);
}


int zynq_irq_init(void)
{
	int retval = 0, irqn = 0;
	u32 *status = (u32 *)zynq_dev.tapasco_status;

	LOG(ZYNQ_LL_ENTEREXIT, "enter");

#define	_X(N)	\
	zynq_irq.intc_ ## N.base = (ioread32(status + (0x1010 >> 2) + N * 2) - \
			ZYNQ_PLATFORM_GP1_BASE) >> 2; \
	zynq_irq.intc_ ## N.status = 0; \
	if (zynq_irq.intc_ ## N.base) { \
		LOG(ZYNQ_LL_IRQ, "controller for IRQ #%d at 0x%08x", \
				ZYNQ_IRQ_BASE_IRQ + irqn, \
				zynq_irq.intc_ ## N.base << 2); \
		zynq_init_intc(zynq_irq.intc_ ## N.base); \
	} \
	LOG(ZYNQ_LL_IRQ, "registering IRQ #%d", ZYNQ_IRQ_BASE_IRQ + irqn); \
	retval = request_irq(ZYNQ_IRQ_BASE_IRQ + irqn, zynq_irq_handler_ ## N, \
			IRQF_TRIGGER_NONE | IRQF_ONESHOT, \
			ZYNQ_DEVICE_CLSNAME "_" ZYNQ_DEVICE_DEVNAME, \
			&zynq_dev); \
	++irqn; \
	if (retval) { \
		ERR("could not register IRQ #%d!", ZYNQ_IRQ_BASE_IRQ + irqn); \
		goto err; \
	}

	INTERRUPT_CONTROLLERS
#undef _X

	LOG(ZYNQ_LL_ENTEREXIT, "exit");
	return retval;

err:
	while (--irqn <= 0) {
		disable_irq(ZYNQ_IRQ_BASE_IRQ + irqn);
		free_irq(ZYNQ_IRQ_BASE_IRQ + irqn, &zynq_dev);
	}
	LOG(ZYNQ_LL_ENTEREXIT, "exit with error");
	return retval;
}

void zynq_irq_exit(void)
{
	int irqn = ZYNQ_PLATFORM_INTC_MAX_NUM;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	while (irqn) {
		--irqn;
		LOG(ZYNQ_LL_IRQ, "releasing IRQ #%d", ZYNQ_IRQ_BASE_IRQ + irqn);
		disable_irq(ZYNQ_IRQ_BASE_IRQ + irqn);
		free_irq(ZYNQ_IRQ_BASE_IRQ + irqn, &zynq_dev);
	}
	LOG(ZYNQ_LL_ENTEREXIT, "exit");
}
