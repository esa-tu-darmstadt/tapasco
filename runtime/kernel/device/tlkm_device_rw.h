#ifndef TLKM_DEVICE_RW_H__
#define TLKM_DEVICE_RW_H__

#include <linux/fs.h>

ssize_t tlkm_device_read(struct file *fp, char __user *d, size_t sz,
			 loff_t *off);
ssize_t tlkm_device_write(struct file *fp, const char __user *d, size_t sz,
			  loff_t *off);

#endif /* TLKM_DEVICE_RW_H__ */
