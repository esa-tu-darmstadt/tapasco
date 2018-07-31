#ifndef TLKM_IOCTL_H__
#define TLKM_IOCTL_H__

#include <linux/fs.h>

typedef struct {
    struct tlkm_device *pdev;
    tlkm_access_t access;
} tlkm_ioctl_data;

long tlkm_ioctl_ioctl(struct file *fp, unsigned int ioctl, unsigned long data);

#endif /* TLKM_IOCTL_H__ */
