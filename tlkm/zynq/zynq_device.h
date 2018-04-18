#ifndef ZYNQ_DEVICE_H__
#define ZYNQ_DEVICE_H__

#include "tlkm_types.h"
#include "tlkm_class.h"
#include "tlkm_device.h"

struct zynq_device {
	struct tlkm_device	*parent;
	dev_id_t		dev_id;
	void __iomem 		*gp_map[2];
	void __iomem		*tapasco_status;
};

int  zynq_device_init(struct tlkm_device *dev);
void zynq_device_exit(struct tlkm_device *dev);

int zynq_device_probe(struct tlkm_class *cls);

#endif /* ZYNQ_DEVICE_H__ */
