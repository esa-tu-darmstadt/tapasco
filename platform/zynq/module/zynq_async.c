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

static struct {
	struct miscdevice	miscdev;
	wait_queue_head_t	read_q;
	u32			out_slots[PLATFORM_NUM_SLOTS << 2];
	u32			out_r_idx;
	u32			out_w_idx;
	struct mutex		out_mutex;
} zynq_async;

ssize_t read(struct file *file, char __user *usr, size_t sz, loff_t *loff)
{
	ssize_t out = 0;
	u32 out_val = 0;
	mutex_lock(&zynq_async.out_mutex);
	out = zynq_async.out_w_idx - zynq_async.out_r_idx;
	if (out > 0) {
		out_val = zynq_async.out_slots[zynq_async.out_r_idx];
		zynq_async.out_r_idx = (zynq_async.out_r_idx + 1) %
				(PLATFORM_NUM_SLOTS << 2);
	}
	mutex_unlock(&zynq_async.out_mutex);
	if (out > 0) {
		out = copy_to_user(usr, &out_val, sizeof(out_val));
	}
	return out;
}

ssize_t write(struct file *file, const char __user *usr, size_t sz, loff_t *loff)
{
	u32 in_val = 0;
	ssize_t in = copy_from_user(&in_val, usr, sizeof(in_val));
	if (in > 0) {
		mutex_lock(&zynq_async.out_mutex);
		zynq_async.out_slots[zynq_async.out_w_idx] = in_val;
		zynq_async.out_w_idx = (zynq_async.out_w_idx + 1) %
				(PLATFORM_NUM_SLOTS << 2);
		mutex_unlock(&zynq_async.out_mutex);
	}
	return in;
}

static struct file_operations zynq_async_fops = {
	.owner = THIS_MODULE,
	.read  = read,
};

static
int init_async_dev(void)
{
	zynq_async.miscdev.minor = MISC_DYNAMIC_MINOR;
	zynq_async.miscdev.name  = "tapasco_async";
	zynq_async.miscdev.fops  = &zynq_async_fops;
	return misc_register(&zynq_async.miscdev);
}

int zynq_async_init(void)
{
	int retval;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	init_waitqueue_head(&zynq_async.read_q);
	zynq_async.out_r_idx = 0;
	zynq_async.out_w_idx = 0;
	mutex_init(&zynq_async.out_mutex);
	retval = init_async_dev();
	if (retval < 0) {
		ERR("async device init failed");
		goto err_asyncdev;
	}
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
