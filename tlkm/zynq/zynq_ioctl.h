#ifndef ZYNQ_IOCTL_H__
#define ZYNQ_IOCTL_H__

#include "tlkm_device.h"

long zynq_ioctl(struct tlkm_device_inst *inst, unsigned ioctl, unsigned long data);

#endif /* ZYNQ_IOCTL_H__ */
