#ifndef ZYNQ_H__
#define ZYNQ_H__

#include "tlkm_class.h"
#include "zynq_device.h"

#define ZYNQ_CLASS_NAME					"zynq"

static const
struct tlkm_class zynq_cls = {
	.name 			= ZYNQ_CLASS_NAME,
	.create			= zynq_device_init,
	.destroy		= zynq_device_exit,
	.probe			= zynq_device_probe,
	.remove			= NULL,
	.status_base		= 0x77770000ULL,
	.npirqs			= 0,
	.private_data		= NULL,
};

#endif /* ZYNQ_H__ */
