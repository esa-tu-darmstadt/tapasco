#ifndef ZYNQ_DEVICE_H__
#define ZYNQ_DEVICE_H__

#include "tlkm_device.h"

int  zynq_device_init(struct tlkm_device_inst *inst);
void zynq_device_exit(struct tlkm_device_inst *inst);

#endif /* ZYNQ_DEVICE_H__ */
