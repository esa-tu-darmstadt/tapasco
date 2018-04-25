#ifndef ZYNQ_DEVICE_H__
#define ZYNQ_DEVICE_H__

#include "tlkm_types.h"
#include "tlkm_class.h"
#include "tlkm_device.h"

struct zynq_device {
	struct tlkm_device	*parent;
};

int  zynq_device_init(struct tlkm_device *dev, void *data);
void zynq_device_exit(struct tlkm_device *dev);

int zynq_device_probe(struct tlkm_class *cls);

#endif /* ZYNQ_DEVICE_H__ */
