#ifndef PCIE_H__
#define PCIE_H__

#include "tlkm_platform.h"

#define TLKM_PCI_NAME			"tlkm"
#define PCIE_CLS_NAME			"pcie"
#define XILINX_VENDOR_ID   		0x10EE
#define XILINX_DEVICE_ID   		0x7038

#define PCIE_DEF 			INIT_PLATFORM(0x0ULL, 0x00002000  /* status */)

static const
struct platform pcie_def = PCIE_DEF;

#ifdef __KERNEL__
#include "tlkm_class.h"
#include "pcie/pcie_device.h"
#include "pcie/pcie_irq.h"
#include "pcie/pcie_ioctl.h"

int  pcie_init(struct tlkm_class *cls);
void pcie_exit(struct tlkm_class *cls);

static const
struct tlkm_class pcie_cls = {
	.name 			= PCIE_CLS_NAME,
	.create			= pcie_device_create,
	.destroy		= pcie_device_destroy,
	.init_subsystems	= pcie_device_init_subsystems,
	.exit_subsystems	= pcie_device_exit_subsystems,
	.probe			= pcie_init,
	.remove			= pcie_exit,
	.pirq			= pcie_irqs_request_platform_irq,
	.rirq			= pcie_irqs_release_platform_irq,
	.ioctl			= pcie_ioctl,
	.npirqs			= 4,
	.platform		= PCIE_DEF,
	.private_data		= NULL,
};
#endif /* __KERNEL__ */

#endif /* PCIE_H__ */
