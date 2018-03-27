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
//! @file	tlkm_async.c
//! @brief	Defines the asynchronous job completion device file for the
//!             unified TaPaSCo loadable kernel module.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/types.h>
#include <linux/fs.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/miscdevice.h>
#include <linux/sched/signal.h>
#include "tlkm_logging.h"
#include "tlkm_perfc.h"
#include "tlkm_async.h"

#define TLKM_ASYNC_BUFFER_SZ					1024U

static struct {
	struct miscdevice	miscdev;
	wait_queue_head_t	read_q;
	wait_queue_head_t	write_q;
	u32			out_slots[TLKM_ASYNC_BUFFER_SZ];
	u32			out_r_idx;
	u32			out_w_idx;
	struct mutex		out_mutex;
	u32			outstanding;
} tlkm_async;

static
int open(struct inode *inod, struct file *file)
{
	LOG(TLKM_LF_ASYNC, "opening async file");
	tlkm_perfc_async_open_inc();
	return 0;
}

static
int release(struct inode *inod, struct file *file)
{
	LOG(TLKM_LF_ASYNC, "releasing async file: outstanding = %u",
			tlkm_async.outstanding);
	tlkm_perfc_async_release_inc();
	return 0;
}

static
ssize_t read(struct file *file, char __user *usr, size_t sz, loff_t *loff)
{
	ssize_t out = 0;
	u32 out_val = 0;
	do {
		mutex_lock(&tlkm_async.out_mutex);
		out = tlkm_async.out_w_idx != tlkm_async.out_r_idx;
		if (out) {
			out_val = tlkm_async.out_slots[tlkm_async.out_r_idx];
			tlkm_async.out_r_idx = (tlkm_async.out_r_idx + 1) %
					TLKM_ASYNC_BUFFER_SZ;
			--tlkm_async.outstanding;
			tlkm_perfc_async_read_inc();
		}
		mutex_unlock(&tlkm_async.out_mutex);
		if (! out) {
			LOG(TLKM_LF_ASYNC, "waiting on data ...");
			wait_event_interruptible(tlkm_async.read_q,
					tlkm_async.out_w_idx !=
					tlkm_async.out_r_idx);
			if (signal_pending(current)) return -ERESTARTSYS;
		} else {
			LOG(TLKM_LF_ASYNC, "read %zd bytes, out_val = %u",
					sz, out_val);
			wake_up_interruptible(&tlkm_async.write_q);
		}
	} while (! out);
	out = copy_to_user(usr, &out_val, sizeof(out_val));
	if (out) return -EFAULT;
	return sizeof(out_val);
}

ssize_t tlkm_async_signal_slot_interrupt(const u32 s_id)
{
	mutex_lock(&tlkm_async.out_mutex);
	while (tlkm_async.outstanding > TLKM_ASYNC_BUFFER_SZ - 2) {
		WRN("buffer thrashing, throttling write ...");
		mutex_unlock(&tlkm_async.out_mutex);
		wait_event_interruptible(tlkm_async.write_q,
				tlkm_async.outstanding <=
				(TLKM_ASYNC_BUFFER_SZ/2));
		if (signal_pending(current)) return -ERESTARTSYS;
		mutex_lock(&tlkm_async.out_mutex);
	}
	mutex_unlock(&tlkm_async.out_mutex);
	LOG(TLKM_LF_ASYNC, "signaling slot #%u", s_id);
	mutex_lock(&tlkm_async.out_mutex);
	tlkm_async.out_slots[tlkm_async.out_w_idx] = s_id;
	tlkm_async.out_w_idx = (tlkm_async.out_w_idx + 1) % TLKM_ASYNC_BUFFER_SZ;
	++tlkm_async.outstanding;
	tlkm_perfc_async_signaled_inc();
#ifndef NDEBUG
	if (tlkm_async.outstanding >= TLKM_ASYNC_BUFFER_SZ)
		WRN("buffer size exceeded! expect missing data!");
#endif
	mutex_unlock(&tlkm_async.out_mutex);
	wake_up_interruptible(&tlkm_async.read_q);
	return sizeof(u32);
}

static
ssize_t write(struct file *file, const char __user *usr, size_t sz, loff_t *o)
{
	u32 in_val = 0;
	ssize_t in;
	in = copy_from_user(&in_val, usr, sizeof(in_val));
	tlkm_perfc_async_written_inc();
	LOG(TLKM_LF_ASYNC, "received job %u as write", in_val);
	if (in) return -EFAULT;
	return tlkm_async_signal_slot_interrupt(in_val);
}

static const struct file_operations tlkm_async_fops = {
	.owner   = THIS_MODULE,
	.read    = read,
	.write   = write,
	.open    = open,
	.release = release,
};

static
int init_async_dev(void)
{
	tlkm_async.miscdev.minor = MISC_DYNAMIC_MINOR;
	tlkm_async.miscdev.name  = TLKM_ASYNC_FILENAME;
	tlkm_async.miscdev.fops  = &tlkm_async_fops;
	return misc_register(&tlkm_async.miscdev);
}

int tlkm_async_init(void)
{
	int retval;
	init_waitqueue_head(&tlkm_async.read_q);
	init_waitqueue_head(&tlkm_async.write_q);
	tlkm_async.out_r_idx = 0;
	tlkm_async.out_w_idx = 0;
	tlkm_async.outstanding = 0;
	mutex_init(&tlkm_async.out_mutex);
	retval = init_async_dev();
	if (retval < 0) {
		WRN("async device init failed");
		goto err_asyncdev;
	}
	LOG(TLKM_LF_ASYNC, "async initialized");

	return 0;

err_asyncdev:
	return retval;
}

void tlkm_async_exit(void)
{
	LOG(TLKM_LF_ASYNC, "removing async dev file");
	misc_deregister(&tlkm_async.miscdev);
}
