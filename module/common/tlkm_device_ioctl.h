#ifndef TLKM_DEVICE_IOCTL_H__
#define TLKM_DEVICE_IOCTL_H__

#include <linux/fs.h>

long tlkm_device_ioctl(struct file *fp, unsigned int ioctl, unsigned long data);

#endif /* TLKM_DEVICE_IOCTL_H__ */
