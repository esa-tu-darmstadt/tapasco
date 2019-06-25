#include <linux/pci.h>
#include <linux/module.h>
#include "tlkm_logging.h"
#include "pcie/pcie.h"
#include "pcie/pcie_device.h"

static const struct pci_device_id tlkm_pcie_id[] = {
	{ PCI_DEVICE( XILINX_VENDOR_ID , XILINX_DEVICE_ID ) },
	{},
};

// struct representation of functions above similiar to fops
static struct pci_driver tlkm_pcie_driver = {
	.name			= TLKM_PCI_NAME,
	.id_table		= tlkm_pcie_id,
	.probe			= tlkm_pcie_probe,
	.remove			= tlkm_pcie_remove,
};

int pcie_init(struct tlkm_class *cls)
{
	int err = 0;
	LOG(TLKM_LF_PCIE, "registering TLKM PCIe driver ...");
	if ((err = pci_register_driver(&tlkm_pcie_driver))) {
		LOG(TLKM_LF_PCIE, "no PCIe TaPaSCo devices found");
	}
	return 0;
}

void pcie_exit(struct tlkm_class *cls)
{
	pci_unregister_driver(&tlkm_pcie_driver);
	LOG(TLKM_LF_PCIE, "deregistered TLKM PCIe driver");
}

MODULE_DEVICE_TABLE(pci, tlkm_pcie_id);
