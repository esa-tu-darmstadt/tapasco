#ifndef ZYNQ_DEVICE_H__
#define ZYNQ_DEVICE_H__

#include "tlkm_types.h"
#include "tlkm_device.h"
#include "zynq_platform.h"

struct zynq_device {
	dev_id_t		dev_id;
	void __iomem 		*gp_map[2];
	void __iomem		*tapasco_status;
};

int  zynq_device_init(struct tlkm_device_inst *inst);
void zynq_device_exit(struct tlkm_device_inst *inst);

#endif /* ZYNQ_DEVICE_H__ */
