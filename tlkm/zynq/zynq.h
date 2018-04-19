#ifndef ZYNQ_H__
#define ZYNQ_H__

#include "tlkm_class.h"
#include "zynq_device.h"

#define ZYNQ_CLASS_NAME					"zynq"

static inline void zynq_remove(struct tlkm_class *cls) {}

static const
struct tlkm_class zynq_cls = {
	.name 			= ZYNQ_CLASS_NAME,
	.create			= zynq_device_init,
	.destroy		= zynq_device_exit,
	.probe			= zynq_device_probe,
	.remove			= zynq_remove,
	.status_base		= 0x77770000ULL,
	.npirqs			= 0,
	.private_data		= NULL,
};

#endif /* ZYNQ_H__ */
