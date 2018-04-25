//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/sched.h>
#include "tlkm_logging.h"
#include "zynq_irq.h"
#include "zynq_platform.h"

#define ZYNQ_IRQ_BASE_IRQ					45
#define ZYNQ_MAX_NUM_INTCS					4	

#define INTERRUPT_CONTROLLERS \
		_INTC(0) \
		_INTC(1) \
		_INTC(2) \
		_INTC(3)

#define _INTC(N) 1 +
#if (INTERRUPT_CONTROLLERS 0 != ZYNQ_MAX_NUM_INTCS)
#error "when changing maximum number of interrupt controllers, you must change " \
		"both the INTERRUPT_CONTROLLERS and ZYNQ_MAX_NUM_INTCS macros"
#endif
#undef _INTC

#ifndef STR
	#define STR(v)						#v
#endif

typedef struct {
	u32 base;
	u32 status;
} intc_t;

#ifdef _INTC
	#undef _INTC
#endif

static struct {
	struct tlkm_control *ctrl;
#define		_INTC(N) intc_t intc_ ## N;
	INTERRUPT_CONTROLLERS
#undef _INTC
} zynq_irq;

#define		_INTC(N) \
static void zynq_irq_func_ ## N(struct work_struct *work); \
\
static DECLARE_WORK(zynq_irq_work_ ## N, zynq_irq_func_ ## N); \
\
static void zynq_irq_func_ ## N(struct work_struct *work) \
{ \
	u32 s_off = (N * 32U); \
	u32 status = zynq_irq.intc_ ## N.status; \
	struct tlkm_control *ctrl = zynq_irq.ctrl; \
	LOG(TLKM_LF_IRQ, "intcn = %d, status = 0x%08x, ctrl = 0x%px", N, status, ctrl); \
	while (ctrl && status > 0) { \
		if (status & 1) { \
			tlkm_control_signal_slot_interrupt(ctrl, s_off++); \
		} \
		status >>= 1; \
	} \
} \
\
static irqreturn_t zynq_irq_handler_ ## N(int irq, void *dev_id) \
{ \
	u32 status; \
	struct zynq_device *zynq_dev = (struct zynq_device *)dev_id; \
	u32 *intc = (u32 *)zynq_dev->parent->mmap.plat + zynq_irq.intc_ ## N.base; \
	status = ioread32(intc); \
	LOG(TLKM_LF_IRQ, "intcn = %d, status = 0x%08x, intc = 0x%px", N, status, intc); \
	iowrite32(status, intc + (0x0c >> 2)); \
	zynq_irq.intc_ ## N.status |= status; \
	schedule_work(&zynq_irq_work_ ## N); \
	return IRQ_HANDLED; \
}

INTERRUPT_CONTROLLERS
#undef _INTC

static
void zynq_init_intc(struct zynq_device *zynq_dev, u32 const base)
{
	u32 *intc = (u32 *)zynq_dev->parent->mmap.plat + base;
	iowrite32((u32)-1, intc + (0x08 >> 2));
	iowrite32((u32) 3, intc + (0x1c >> 2));
	ioread32(intc);
}


int zynq_irq_init(struct zynq_device *zynq_dev)
{
	int retval = 0, irqn = 0, rirq = 0;
	u32 base;

#define	_INTC(N)	\
	rirq = ZYNQ_IRQ_BASE_IRQ + zynq_dev->parent->cls->npirqs + irqn; \
	base = ioread32(zynq_dev->parent->mmap.status + (0x1010 >> 2) + N * 2); \
	if (base) { \
		zynq_irq.intc_ ## N.base = (base - zynq_dev->parent->cls->platform.plat.base) >> 2; \
		zynq_irq.intc_ ## N.status = 0; \
		if (zynq_irq.intc_ ## N.base) { \
			LOG(TLKM_LF_IRQ, "controller for IRQ #%d at 0x%08x", \
					rirq, zynq_irq.intc_ ## N.base << 2); \
			zynq_init_intc(zynq_dev, zynq_irq.intc_ ## N.base); \
		} \
		LOG(TLKM_LF_IRQ, "registering IRQ #%d", rirq); \
		retval = request_irq(rirq, \
				zynq_irq_handler_ ## N, \
				IRQF_TRIGGER_NONE | IRQF_ONESHOT, \
				"tapasco_zynq_" STR(N), \
				zynq_dev); \
		++irqn; \
		if (retval) { \
			ERR("could not register IRQ #%d!", rirq); \
			goto err; \
		} \
	}

	INTERRUPT_CONTROLLERS
#undef _X
	zynq_irq.ctrl = zynq_dev->parent->ctrl;

	return retval;

err:
	while (--irqn <= 0) {
		disable_irq(rirq);
		free_irq(rirq, zynq_dev);
	}
	return retval;
}

void zynq_irq_exit(struct zynq_device *zynq_dev)
{
	int irqn = ZYNQ_MAX_NUM_INTCS, rirq = 0;
	while (irqn) {
		--irqn;
		rirq = ZYNQ_IRQ_BASE_IRQ + zynq_dev->parent->cls->npirqs + irqn;
		LOG(TLKM_LF_IRQ, "releasing IRQ #%d", rirq);
		disable_irq(rirq);
		free_irq(rirq, zynq_dev);
	}
}
