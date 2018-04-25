#ifndef ZYNQ_H__
#define ZYNQ_H__

#include "tlkm_class.h"
#include "zynq_device.h"
#include "zynq_platform.h"
#include "zynq_ioctl.h"
#include "zynq_mmap.h"

static inline void zynq_remove(struct tlkm_class *cls) {}

// FIXME implement rirq
// FIXME implement pirq

static const
struct tlkm_class zynq_cls = {
	.name 			= ZYNQ_CLASS_NAME,
	.create			= zynq_device_init,
	.destroy		= zynq_device_exit,
	.probe			= zynq_device_probe,
	.remove			= zynq_remove,
	.ioctl			= zynq_ioctl,
	.mmap			= zynq_mmap,
	.status_base		= 0x77770000ULL,
	.npirqs			= 8,
	.platform		= INIT_PLATFORM(0x77770000, 0x000020000,  /* status */
	                                        0x43000000, 0x020000000,  /* arch */
						0x81000000, 0x020000000), /* plat */
	.private_data		= NULL,
};

#endif /* ZYNQ_H__ */
