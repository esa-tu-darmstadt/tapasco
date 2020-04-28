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
#include <linux/of.h>
#include <linux/of_irq.h>
#include "tlkm_logging.h"
#include "tlkm_slots.h"
#include "zynq_irq.h"

#define ZYNQ_IRQ_BASE_IRQ 45
#define ZYNQ_MAX_NUM_INTCS 4

#define INTERRUPT_CONTROLLERS                                                  \
	_INTC(0)                                                               \
	_INTC(1)                                                               \
	_INTC(2)                                                               \
	_INTC(3)

#define _INTC(N) 1 +
#if (INTERRUPT_CONTROLLERS 0 != ZYNQ_MAX_NUM_INTCS)
#error "when changing maximum number of interrupt controllers, you must change " \
"both the INTERRUPT_CONTROLLERS and ZYNQ_MAX_NUM_INTCS macros"
#endif
#undef _INTC

#ifndef STR
#define STR(v) #v
#endif

typedef struct {
	u32 base;
} intc_t;

static const struct of_device_id tapasco_ids[] = {
	{
		.compatible = "tapasco",
	},
	{},
};

static struct {
	struct tlkm_control *ctrl;
    int requested_irq_num;
#define _INTC(N) intc_t intc_##N;
	INTERRUPT_CONTROLLERS
#undef _INTC
} zynq_irq;

// one work struct per slot: ack's that slot's interrupt only
static struct work_struct zynq_irq_work_slot[PLATFORM_NUM_SLOTS];

#define _SLOT(N)                                                               \
	static void zynq_irq_work_slot_##N##_func(struct work_struct *work)    \
	{                                                                      \
		LOG(TLKM_LF_IRQ, "slot interrupt #%d", N);                     \
		tlkm_control_signal_slot_interrupt(zynq_irq.ctrl, N);          \
	}
TLKM_SLOTS
#undef _SLOT

static void init_work_structs(void)
{
#define _SLOT(N)                                                               \
	INIT_WORK(&zynq_irq_work_slot[N], zynq_irq_work_slot_##N##_func);
	TLKM_SLOTS
#undef _SLOT
}

#define _INTC(N)                                                                  \
	static irqreturn_t zynq_irq_handler_##N(int irq, void *dev_id)            \
	{                                                                         \
		u32 status;                                                       \
		static const u32 s_off = (N * 32U);                               \
		struct zynq_device *zynq_dev = (struct zynq_device *)dev_id;      \
		u32 *intc = (u32 *)zynq_dev->parent->mmap.plat +                  \
			    zynq_irq.intc_##N.base;                               \
		while ((status = ioread32(intc))) {                               \
			iowrite32(status, intc + (0x0c >> 2));                    \
			do {                                                      \
				const u32 slot = __builtin_ffs(status) - 1;       \
				const int ok = schedule_work(                     \
					&zynq_irq_work_slot[s_off + slot]);       \
				if (!ok)                                          \
					tlkm_perfc_irq_error_already_pending_inc( \
						zynq_dev->parent->dev_id);        \
				tlkm_perfc_total_irqs_inc(                        \
					zynq_dev->parent->dev_id);                \
				status ^= (1U << slot);                           \
			} while (status);                                         \
		}                                                                 \
		return IRQ_HANDLED;                                               \
	}
INTERRUPT_CONTROLLERS
#undef _INTC

static void zynq_init_intc(struct zynq_device *zynq_dev, u32 const base)
{
	u32 *intc = (u32 *)zynq_dev->parent->mmap.plat + base;
	iowrite32((u32)-1, intc + (0x08 >> 2));
	iowrite32((u32)3, intc + (0x1c >> 2));
	ioread32(intc);
}

int zynq_irq_init(struct zynq_device *zynq_dev)
{
	int retval = 0, rirq = 0;
	u32 base;
    zynq_irq.requested_irq_num = 0;

	init_work_structs();
#define _INTC(N)                                                               \
	rirq = irq_of_parse_and_map(of_find_matching_node(NULL, tapasco_ids), zynq_irq.requested_irq_num);   \
	base = tlkm_status_get_component_base(zynq_dev->parent,                \
					      "PLATFORM_COMPONENT_INTC" #N);   \
	if (base != -1) {                                                      \
		zynq_irq.intc_##N.base = (base >> 2);                          \
		LOG(TLKM_LF_IRQ, "controller for IRQ #%d at 0x%08llx", rirq,   \
		    (zynq_irq.intc_##N.base << 2) +                            \
			    zynq_dev->parent->status.platform_base.base);      \
		zynq_init_intc(zynq_dev, zynq_irq.intc_##N.base);              \
		LOG(TLKM_LF_IRQ, "registering IRQ #%d", rirq);                 \
		retval = request_irq(rirq, zynq_irq_handler_##N,               \
				     IRQF_EARLY_RESUME,                        \
				     "tapasco_zynq_" STR(N), zynq_dev);        \
        ++zynq_irq.requested_irq_num;                       \
		if (retval) {                                                  \
			ERR("could not register IRQ #%d!", rirq);              \
			goto err;                                              \
		}                                                              \
	}
	INTERRUPT_CONTROLLERS
#undef _X
	zynq_irq.ctrl = zynq_dev->parent->ctrl;

	return retval;

err:
	while (--zynq_irq.requested_irq_num >= 0) {
		disable_irq(rirq);
		free_irq(rirq, zynq_dev);
	}
	return retval;
}

void zynq_irq_exit(struct zynq_device *zynq_dev)
{
	int rirq = 0;
	while (zynq_irq.requested_irq_num) {
		--zynq_irq.requested_irq_num;
		rirq = irq_of_parse_and_map(
			of_find_matching_node(NULL, tapasco_ids), zynq_irq.requested_irq_num);
		LOG(TLKM_LF_IRQ, "releasing IRQ #%d", rirq);
		disable_irq(rirq);
		free_irq(rirq, zynq_dev);
	}
}

int zynq_irq_request_platform_irq(struct tlkm_device *dev, int irq_no,
				  irq_handler_t h, void *data)
{
	int err = 0;
	if (irq_no >= dev->cls->npirqs) {
		DEVERR(dev->dev_id,
		       "invalid platform interrupt number: %d (must be < %zd",
		       irq_no, dev->cls->npirqs);
		return -ENXIO;
	}
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "requesting platform irq #%d", irq_no);
	if ((err = request_irq(ZYNQ_IRQ_BASE_IRQ + irq_no, h, IRQF_EARLY_RESUME,
			       "tapasco_zynq_platform", data))) {
		DEVERR(dev->dev_id, "could not request interrupt #%d: %d",
		       ZYNQ_IRQ_BASE_IRQ + irq_no, err);
		return err;
	}
	DEVLOG(dev->dev_id, TLKM_LF_IRQ, "registered platform irq #%d", irq_no);
	return 0;
}

void zynq_irq_release_platform_irq(struct tlkm_device *dev, int irq_no)
{
	struct zynq_device *zdev = (struct zynq_device *)dev->private_data;
	if (irq_no >= dev->cls->npirqs) {
		DEVERR(dev->dev_id,
		       "invalid platform interrupt number: %d (must be < %zd)",
		       irq_no, dev->cls->npirqs);
		return;
	}
	DEVLOG(dev->dev_id, TLKM_LF_IRQ,
	       "freeing platform interrupt #%d with mapping %d", irq_no,
	       ZYNQ_IRQ_BASE_IRQ + irq_no);
	free_irq(ZYNQ_IRQ_BASE_IRQ + irq_no, zdev);
}
