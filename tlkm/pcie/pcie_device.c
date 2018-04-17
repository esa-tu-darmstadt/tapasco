#include <linux/pci.h>
#include <linux/version.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/list.h>
#include "platform_global.h"
#include "pcie.h"
#include "pcie_device.h"
#include "pcie_irq.h"
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_bus.h"

#define TLKM_DEV_ID(pdev) \
	(((struct tlkm_pcie_device *)dev_get_drvdata(&(pdev)->dev))->dev_id)

static size_t num_devices = 0;
ssize_t pcie_enumerate(void) { return num_devices; }

static struct tlkm_device devices[PLATFORM_MAX_DEVS];

static int  tlkm_pcie_init(struct tlkm_device_inst *d) { return 0; }
static void tlkm_pcie_exit(struct tlkm_device_inst *d) {}

static struct tlkm_device tlkm_pcie_dev = {
	.device 	= LIST_HEAD_INIT(tlkm_pcie_dev.device),
	.vendor_id 	= XILINX_VENDOR_ID,
	.product_id 	= XILINX_DEVICE_ID,
	.status_base	= 0x02800000ULL,
	.name   	= TLKM_PCI_NAME,
	.init   	= tlkm_pcie_init,
	.exit   	= tlkm_pcie_exit,
	.pirq           = pcie_irqs_request_platform_irq,
	.rirq 		= pcie_irqs_release_platform_irq,
};

/**
 * @brief Enables pcie-device and claims/remaps neccessary bar resources
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int claim_device(struct pci_dev *pdev)
{
	int err = 0;
	struct tlkm_pcie_device *pci_data;

	/* wake up the pci device */
	err = pci_enable_device(pdev);
	if (err) {
		WRN("failed to enable PCIe-device: %d", err);
		goto error_pci_en;
	}

	/* set busmaster bit in config register */
	pci_set_master(pdev);

	/* setup BAR memory regions */
	err = pci_request_regions(pdev, TLKM_PCI_NAME);
	if (err) {
		WRN("failed to setup bar regions for pci device %d", err);
		goto error_pci_req;
	}

	pci_data = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	if (! pci_data) {
		pci_data = (struct tlkm_pcie_device *)kzalloc(sizeof(*pci_data), GFP_KERNEL);
		if (! pci_data) {
			ERR("could not allocate private PCI data struct");
			goto error_pci_req;
		}
		dev_set_drvdata(&pdev->dev, pci_data);
	}

	/* read out pci bar 0 settings */
	pci_data->pdev			= pdev;
	pci_data->phy_addr_bar0 	= pci_resource_start(pdev, 0);
	pci_data->phy_len_bar0		= pci_resource_len(pdev, 0);
	pci_data->phy_flags_bar0	= pci_resource_flags(pdev, 0);

	LOG(TLKM_LF_PCIE, "PCI bar 0: address= 0x%08llx length: 0x%08llx",
			pci_data->phy_addr_bar0, pci_data->phy_len_bar0);

	/* map physical address to kernel space */
	pci_data->kvirt_addr_bar0 = ioremap(pci_data->phy_addr_bar0, pci_data->phy_len_bar0);
	if (IS_ERR(pci_data->kvirt_addr_bar0)) {
		ERR("could not remap bar 0 address to kernel space");
		goto error_pci_remap;
	}
	LOG(TLKM_LF_PCIE, "remapped bar 0 address: 0x%08llx", (u64)pci_data->kvirt_addr_bar0);

	tlkm_pcie_dev.base_offset = pci_data->phy_addr_bar0;
	LOG(TLKM_LF_PCIE, "status core base: 0x%08llx", (u64)tlkm_pcie_dev.status_base);

	tlkm_bus_add_device(&tlkm_pcie_dev);
	pci_data->dev_id = tlkm_pcie_dev.dev_id;
	devices[pci_data->dev_id] = tlkm_pcie_dev;
	tlkm_perfc_link_speed_set(pci_data->dev_id, pci_data->link_speed);
	tlkm_perfc_link_width_set(pci_data->dev_id, pci_data->link_width);
	num_devices++;

	return 0;

error_pci_remap:
	pci_release_regions(pdev);
	kfree(pci_data);
error_pci_req:
	pci_disable_device(pdev);
error_pci_en:
	return -ENODEV;
}

static void release_device(struct pci_dev *pdev)
{
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	BUG_ON(! dev);
	iounmap(dev->kvirt_addr_bar0);
	kfree(dev);
	pci_release_regions(pdev);
	pci_disable_device(pdev);
}

/**
 * @brief Configures pcie-device and bit_mask settings
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int configure_device(struct pci_dev *pdev)
{
	dev_id_t id = TLKM_DEV_ID(pdev);
	DEVLOG(id, TLKM_LF_PCIE, "MPS: %d, Maximum Read Requests %d",
			pcie_get_mps(pdev), pcie_get_readrq(pdev));

	if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))) {
		DEVLOG(id, TLKM_LF_PCIE, "dma_set_mask: using 64 bit DMA addresses");
		dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(64));
	} else if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(32))) {
		DEVLOG(id, TLKM_LF_PCIE, "dma_set_mask: using 32 bit DMA addresses");
		dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(32));
	} else {
		DEVERR(id, "no suitable DMA bitmask available");
		return -ENODEV;
	}
	return 0;
}

/**
 * @brief Initializes msi-capable structure and binds to irq_functions
 * @param pci_dev device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int claim_msi(struct pci_dev *pdev)
{
	int err = 0, i;
	struct tlkm_pcie_device *pci_data = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	dev_id_t id;
	BUG_ON(! pci_data);
	id = pci_data->dev_id;

	for (i = 0; i < REQUIRED_INTERRUPTS; i++) {
		pci_data->irq_mapping[i] = -1;
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
		pci_data->msix_entries[i].entry = i;
#endif
	}

#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	err = pci_enable_msix_range(pdev,
			pci_data->msix_entries,
			REQUIRED_INTERRUPTS,
			REQUIRED_INTERRUPTS);
#else
	/* set up MSI interrupt vector to max size */
	err = pci_alloc_irq_vectors(pdev,
			REQUIRED_INTERRUPTS,
			REQUIRED_INTERRUPTS,
			PCI_IRQ_MSIX);
#endif

	if (err <= 0) {
		DEVERR(id, "cannot set MSI vector (%d)", err);
		return -ENOSPC;
	} else {
		DEVLOG(id, TLKM_LF_IRQ, "got %d MSI vectors", err);
	}

	if ((err = pcie_irqs_init(pdev))) {
		DEVERR(id, "failed to register interrupts: %d", err);
		return -ENOSPC;
	}
	return 0;
}

static void report_link_status(struct pci_dev *pdev)
{
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	dev_id_t id;
	u16 ctrl_reg = 0;
	int gts = 0;

	BUG_ON(! dev);
	id = dev->dev_id;
	pcie_capability_read_word(pdev, PCI_EXP_LNKSTA, &ctrl_reg);

	dev->link_width = (ctrl_reg & PCI_EXP_LNKSTA_NLW) >> PCI_EXP_LNKSTA_NLW_SHIFT;
	dev->link_speed = ctrl_reg & PCI_EXP_LNKSTA_CLS;

	switch (dev->link_speed) {
	case PCI_EXP_LNKSTA_CLS_8_0GB:	gts = 80;	break;
	case PCI_EXP_LNKSTA_CLS_5_0GB:	gts = 50;	break;
	case PCI_EXP_LNKSTA_CLS_2_5GB:	gts = 25;	break;
	default: 		 	gts =  0;	break;
	}

	DEVLOG(id, TLKM_LF_PCIE, "PCIe link width: x%d", dev->link_width);
	DEVLOG(id, TLKM_LF_PCIE, "PCIe link speed: %d.%d GT/s", gts / 10, gts % 10);
}

int tlkm_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	LOG(TLKM_LF_PCIE, "init pcie-dev for bus mastering");

	if (claim_device(pdev)) {
		goto error_no_device;
	}
	if (configure_device(pdev)) {
		goto error_cannot_configure;
	}
	if (claim_msi(pdev)) {
		goto error_cannot_configure;
	}

	report_link_status(pdev);

	if (0/*char_dma_register()*/) {
		DEVLOG(TLKM_DEV_ID(pdev), TLKM_LF_PCIE, "could not register dma char device(s)");
		goto error_cannot_configure;
	}

	if (0/*char_user_register()*/) {
		DEVLOG(TLKM_DEV_ID(pdev), TLKM_LF_PCIE, "could not register user char device(s)");
		goto error_user_register;
	}

	return 0;

	//char_user_unregister();
error_user_register:
	//char_dma_unregister();
error_cannot_configure:
	release_device(pdev);
error_no_device:
	return -ENOSPC;
}

void tlkm_pcie_remove(struct pci_dev *pdev)
{
	DEVLOG(TLKM_DEV_ID(pdev), TLKM_LF_PCIE, "unload pcie-device");
	//char_dma_unregister();
	//char_user_unregister();
	pcie_irqs_deinit(pdev);
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	pci_disable_msix(pdev);
#else
	pci_free_irq_vectors(pdev);
#endif
	release_device(pdev);
}
