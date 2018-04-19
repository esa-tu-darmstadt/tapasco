#ifndef PCIE_H__
#define PCIE_H__

#include "tlkm_class.h"
#include "pcie/pcie_device.h"
#include "pcie/pcie_irq.h"

#define TLKM_PCI_NAME					"tlkm"
#define XILINX_VENDOR_ID   				0x10EE
#define XILINX_DEVICE_ID   				0x7038

int  pcie_init(struct tlkm_class *cls);
void pcie_exit(struct tlkm_class *cls);

static const
struct tlkm_class pcie_cls = {
	.name 			= TLKM_PCI_NAME,
	.create			= pcie_device_create,
	.destroy		= pcie_device_destroy,
	.probe			= pcie_init,
	.remove			= pcie_exit,
	.pirq			= pcie_irqs_request_platform_irq,
	.rirq			= pcie_irqs_release_platform_irq,
	.npirqs			= 4,
	.status_base		= 0x02800000ULL,
	.private_data		= NULL,
};

#endif /* PCIE_H__ */
