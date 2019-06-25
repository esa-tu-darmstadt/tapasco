#ifndef PCIE_IOCTL_H__
#define PCIE_IOCTL_H__

#include "tlkm_device.h"

long pcie_ioctl(struct tlkm_device *inst, unsigned int ioctl, unsigned long data);

#endif /* PCIE_IOCTL_H__ */
