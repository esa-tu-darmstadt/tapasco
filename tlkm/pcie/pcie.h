#ifndef PCIE_H__
#define PCIE_H__

#include "tlkm_class.h"
#include "pcie/pcie_device.h"
#include "pcie/pcie_irq.h"

#define TLKM_PCI_NAME					"tlkm"
#define TLKM_CLS_NAME					"pcie"
#define XILINX_VENDOR_ID   				0x10EE
#define XILINX_DEVICE_ID   				0x7038

int  pcie_init(struct tlkm_class *cls);
void pcie_exit(struct tlkm_class *cls);

// FIXME implement ioctl_f
// FIXME implement mmap_f

static const
struct tlkm_class pcie_cls = {
	.name 			= TLKM_CLS_NAME,
	.create			= pcie_device_create,
	.destroy		= pcie_device_destroy,
	.probe			= pcie_init,
	.remove			= pcie_exit,
	.pirq			= pcie_irqs_request_platform_irq,
	.rirq			= pcie_irqs_release_platform_irq,
	.npirqs			= 4,
	.platform		= INIT_PLATFORM(0x02800000ULL, 0x00002000,  /* status */
						0x02000000ULL, 0x02000000,  /* arch */
						0x03000000ULL, 0x02000000), /* platf */
	.private_data		= NULL,
};

#endif /* PCIE_H__ */
