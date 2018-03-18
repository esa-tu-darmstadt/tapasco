/**
 *  @file	zynq_async.c
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <linux/types.h>
#include <linux/fs.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/miscdevice.h>
#include <platform_global.h>
#include "zynq_logging.h"
#include "zynq_platform.h"

#define ASYNC_BUFFER_SZ					1024U

#define ASYNC_BUFFER_SZ					1024U

static struct {
	struct miscdevice	miscdev;
	wait_queue_head_t	read_q;
	wait_queue_head_t	write_q;
	u32			out_slots[ASYNC_BUFFER_SZ];
	u32			out_r_idx;
	u32			out_w_idx;
	struct mutex		out_mutex;
	u32			outstanding;
} zynq_async;

static
int open(struct inode *inod, struct file *file)
{
	LOG(ZYNQ_LL_ASYNC, "opening async file");
	return 0;
}

static
int release(struct inode *inod, struct file *file)
{
	ERR("releasing async file: outstanding = %u", zynq_async.outstanding);
	return 0;
}

static
ssize_t read(struct file *file, char __user *usr, size_t sz, loff_t *loff)
{
	ssize_t out = 0;
	u32 out_val = 0;
	do {
		mutex_lock(&zynq_async.out_mutex);
		out = zynq_async.out_w_idx != zynq_async.out_r_idx;
		if (out) {
			out_val = zynq_async.out_slots[zynq_async.out_r_idx];
			zynq_async.out_r_idx = (zynq_async.out_r_idx + 1) %
					ASYNC_BUFFER_SZ;
			--zynq_async.outstanding;
		}
		mutex_unlock(&zynq_async.out_mutex);
		if (! out) {
			LOG(ZYNQ_LL_ASYNC, "waiting on data ...");
			wait_event_interruptible(zynq_async.read_q,
					zynq_async.out_w_idx !=
					zynq_async.out_r_idx);
			if (signal_pending(current)) return -ERESTARTSYS;
		} else {
			LOG(ZYNQ_LL_ASYNC, "read %zd bytes, out_val = %u",
					sz, out_val);
			wake_up_interruptible(&zynq_async.write_q);
		}
	} while (! out);
	out = copy_to_user(usr, &out_val, sizeof(out_val));
	if (out) return -EFAULT;
	return sizeof(out_val);
}

ssize_t async_signal_slot_interrupt(const u32 s_id)
{
	mutex_lock(&zynq_async.out_mutex);
	while (zynq_async.outstanding > ASYNC_BUFFER_SZ - 2) {
		WRN("buffer thrashing, throttling write ...");
		mutex_unlock(&zynq_async.out_mutex);
		wait_event_interruptible(zynq_async.write_q,
				zynq_async.outstanding <= (ASYNC_BUFFER_SZ/2));
		if (signal_pending(current)) return -ERESTARTSYS;
		mutex_lock(&zynq_async.out_mutex);
	}
	mutex_unlock(&zynq_async.out_mutex);
	LOG(ZYNQ_LL_ASYNC, "signaling slot #%u", s_id);
	mutex_lock(&zynq_async.out_mutex);
	zynq_async.out_slots[zynq_async.out_w_idx] = s_id;
	zynq_async.out_w_idx = (zynq_async.out_w_idx + 1) % ASYNC_BUFFER_SZ;
	++zynq_async.outstanding;
#ifndef NDEBUG
	if (zynq_async.outstanding >= ASYNC_BUFFER_SZ)
		ERR("buffer size exceeded! expect missing data!");
#endif
	mutex_unlock(&zynq_async.out_mutex);
	wake_up_interruptible(&zynq_async.read_q);
	return sizeof(u32);
}

static
ssize_t write(struct file *file, const char __user *usr, size_t sz, loff_t *o)
{
	u32 in_val = 0;
	ssize_t in;
	in = copy_from_user(&in_val, usr, sizeof(in_val));
	if (in) return -EFAULT;
	return async_signal_slot_interrupt(in_val);
}

static const struct file_operations zynq_async_fops = {
	.owner   = THIS_MODULE,
	.read    = read,
	.write   = write,
	.open    = open,
	.release = release,
};

static
int init_async_dev(void)
{
	zynq_async.miscdev.minor = MISC_DYNAMIC_MINOR;
	zynq_async.miscdev.name  = ZYNQ_PLATFORM_WAITFILENAME;
	zynq_async.miscdev.fops  = &zynq_async_fops;
	return misc_register(&zynq_async.miscdev);
}

int zynq_async_init(void)
{
	int retval;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	init_waitqueue_head(&zynq_async.read_q);
	init_waitqueue_head(&zynq_async.write_q);
	zynq_async.out_r_idx = 0;
	zynq_async.out_w_idx = 0;
	zynq_async.outstanding = 0;
	mutex_init(&zynq_async.out_mutex);
	retval = init_async_dev();
	if (retval < 0) {
		ERR("async device init failed");
		goto err_asyncdev;
	}
	LOG(ZYNQ_LL_ASYNC, "async initialized");
	LOG(ZYNQ_LL_ENTEREXIT, "exit");

	return 0;

err_asyncdev:
	LOG(ZYNQ_LL_ENTEREXIT, "exit with error %d", retval);
	return retval;
}

void zynq_async_exit(void)
{
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	LOG(ZYNQ_LL_ASYNC, "removing async dev file");
	misc_deregister(&zynq_async.miscdev);
	LOG(ZYNQ_LL_ENTEREXIT, "exit");
}

/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
