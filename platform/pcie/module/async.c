#include <linux/types.h>
#include <linux/fs.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/miscdevice.h>
#include <linux/sched/signal.h>
#include "common/debug_print.h"
#include "async.h"

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
} async;

static
int open(struct inode *inod, struct file *file)
{
	fflink_info("opening async file");
	return 0;
}

static
int release(struct inode *inod, struct file *file)
{
	fflink_info("releasing async file: outstanding = %u", async.outstanding);
	return 0;
}

static
ssize_t read(struct file *file, char __user *usr, size_t sz, loff_t *loff)
{
	ssize_t out = 0;
	u32 out_val = 0;
	do {
		mutex_lock(&async.out_mutex);
		out = async.out_w_idx != async.out_r_idx;
		if (out) {
			out_val = async.out_slots[async.out_r_idx];
			async.out_r_idx = (async.out_r_idx + 1) %
					ASYNC_BUFFER_SZ;
			--async.outstanding;
		}
		mutex_unlock(&async.out_mutex);
		if (! out) {
			fflink_info("waiting on data ...");
			wait_event_interruptible(async.read_q,
					async.out_w_idx !=
					async.out_r_idx);
			if (signal_pending(current)) return -ERESTARTSYS;
		} else {
			fflink_notice("read %zd bytes, out_val = %u",
					sz, out_val);
			wake_up_interruptible(&async.write_q);
		}
	} while (! out);
	out = copy_to_user(usr, &out_val, sizeof(out_val));
	if (out) return -EFAULT;
	return sizeof(out_val);
}

ssize_t async_signal_slot_interrupt(const u32 s_id)
{
	mutex_lock(&async.out_mutex);
	while (async.outstanding > ASYNC_BUFFER_SZ - 2) {
		fflink_warn("buffer thrashing, throttling write ...");
		mutex_unlock(&async.out_mutex);
		wait_event_interruptible(async.write_q,
				async.outstanding <= (ASYNC_BUFFER_SZ/2));
		if (signal_pending(current)) return -ERESTARTSYS;
		mutex_lock(&async.out_mutex);
	}
	mutex_unlock(&async.out_mutex);
	fflink_info("signaling slot #%u", s_id);
	mutex_lock(&async.out_mutex);
	async.out_slots[async.out_w_idx] = s_id;
	async.out_w_idx = (async.out_w_idx + 1) % ASYNC_BUFFER_SZ;
	++async.outstanding;
#ifndef NDEBUG
	if (async.outstanding >= ASYNC_BUFFER_SZ)
		fflink_warn("buffer size exceeded! expect missing data!");
#endif
	mutex_unlock(&async.out_mutex);
	wake_up_interruptible(&async.read_q);
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

static const struct file_operations async_fops = {
	.owner   = THIS_MODULE,
	.read    = read,
	.write   = write,
	.open    = open,
	.release = release,
};

static
int init_async_dev(void)
{
	async.miscdev.minor = MISC_DYNAMIC_MINOR;
	async.miscdev.name  = PLATFORM_WAITFILENAME;
	async.miscdev.fops  = &async_fops;
	return misc_register(&async.miscdev);
}

int async_init(void)
{
	int retval;
	init_waitqueue_head(&async.read_q);
	init_waitqueue_head(&async.write_q);
	async.out_r_idx = 0;
	async.out_w_idx = 0;
	async.outstanding = 0;
	mutex_init(&async.out_mutex);
	retval = init_async_dev();
	if (retval < 0) {
		fflink_warn("async device init failed");
		goto err_asyncdev;
	}
	fflink_info("async initialized");

	return 0;

err_asyncdev:
	fflink_info("exit with error %d", retval);
	return retval;
}

void async_exit(void)
{
	fflink_info("removing async dev file");
	misc_deregister(&async.miscdev);
}

/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
