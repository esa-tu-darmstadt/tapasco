#ifndef TLKM_IOCTL_H__
#define TLKM_IOCTL_H__

#include <linux/fs.h>

long tlkm_ioctl_ioctl(struct file *fp, unsigned int ioctl, unsigned long data);

#endif /* TLKM_IOCTL_H__ */
