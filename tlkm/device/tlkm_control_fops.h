#ifndef TLKM_CONTROL_FOPS_H__
#define TLKM_CONTROL_FOPS_H__

#include <linux/fs.h>

ssize_t tlkm_control_fops_read(struct file *fp, char __user *d, size_t sz, loff_t *off);
ssize_t tlkm_control_fops_write(struct file *fp, const char __user *d, size_t sz, loff_t *off);
long tlkm_control_fops_ioctl(struct file *fp, unsigned int ioctl, unsigned long data);

#endif /* TLKM_CONTROL_FOPS_H__ */
