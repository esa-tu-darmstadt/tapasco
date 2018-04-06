#ifndef TLKM_DEVICE_MMAP_H__
#define TLKM_DEVICE_MMAP_H__

#include <linux/fs.h>

int tlkm_device_mmap(struct file *fp, struct vm_area_struct *vm);

#endif /* TLKM_DEVICE_MMAP_H__ */
