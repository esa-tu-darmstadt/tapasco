#ifndef ZYNQ_MMAP_H__
#define ZYNQ_MMAP_H__

#include <linux/fs.h>
#include "tlkm_device.h"

int zynq_mmap(struct tlkm_device_inst *dp, struct vm_area_struct *vm);

#endif /* ZYNQ_MMAP_H__ */
