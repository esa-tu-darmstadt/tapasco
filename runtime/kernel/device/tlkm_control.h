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
#ifndef TLKM_CONTROL_H__
#define TLKM_CONTROL_H__

#include <linux/types.h>
#include <linux/mutex.h>
#include <linux/sched.h>
#include <linux/miscdevice.h>
#include "tlkm_types.h"
#include "tlkm_slots.h"

#define TLKM_CONTROL_BUFFER_SZ 1024U

struct tlkm_control {
	dev_id_t dev_id;
	struct miscdevice miscdev;
	struct eventfd_ctx *user_interrupts[PLATFORM_NUM_SLOTS];
};

ssize_t tlkm_control_signal_slot_interrupt(struct tlkm_control *pctl,
					   const u32 s_id);
int tlkm_control_init(dev_id_t dev_id, struct tlkm_control **ppctl);
void tlkm_control_exit(struct tlkm_control *pctl);
int tlkm_control_release(struct inode *inode, struct file *file);

#endif /* TLKM_CONTROL_H__ */
