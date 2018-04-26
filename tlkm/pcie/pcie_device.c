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
	(((struct tlkm_pcie_device *)dev_get_drvdata(&(pdev)->dev))->parent->dev_id)

/**
 * @brief Enables pcie-device and claims/remaps neccessary bar resources
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int claim_device(struct tlkm_pcie_device *pdev)
{
	int err = 0;
	dev_id_t const did = pdev->parent->dev_id;
	struct pci_dev *dev = pdev->pdev;
	BUG_ON(! dev);

	/* wake up the pci device */
	err = pci_enable_device(dev);
	if (err) {
		DEVWRN(did, "failed to enable PCIe-device: %d", err);
		goto error_pci_en;
	}

	/* set busmaster bit in config register */
	pci_set_master(dev);

	/* setup BAR memory regions */
	err = pci_request_regions(dev, TLKM_PCI_NAME);
	if (err) {
		DEVWRN(did, "failed to setup bar regions for pci device %d", err);
		goto error_pci_req;
	}

	dev_set_drvdata(&dev->dev, pdev);

	/* read out pci bar 0 settings */
	pdev->phy_addr_bar0 	= pci_resource_start(dev, 0);
	pdev->phy_len_bar0	= pci_resource_len(dev, 0);
	pdev->phy_flags_bar0	= pci_resource_flags(dev, 0);

	DEVLOG(did, TLKM_LF_PCIE, "PCI bar 0: address= 0x%08llx length: 0x%08llx",
			pdev->phy_addr_bar0, pdev->phy_len_bar0);

	/* map physical address to kernel space */
	pdev->kvirt_addr_bar0 = ioremap(pdev->phy_addr_bar0, pdev->phy_len_bar0);
	if (IS_ERR(pdev->kvirt_addr_bar0)) {
		DEVERR(did, "could not remap bar 0 address to kernel space");
		goto error_pci_remap;
	}
	DEVLOG(did, TLKM_LF_PCIE, "remapped bar 0 address: 0x%px", pdev->kvirt_addr_bar0);

	pdev->parent->base_offset = pdev->phy_addr_bar0;
	DEVLOG(did, TLKM_LF_PCIE, "status core base: 0x%08llx => 0x%08llx",
		(u64)pcie_cls.platform.status.base, (u64)pcie_cls.platform.status.base + pdev->parent->base_offset);

	return 0;

	iounmap(pdev->kvirt_addr_bar0);
error_pci_remap:
	pci_release_regions(pdev->pdev);
error_pci_req:
	pci_disable_device(pdev->pdev);
error_pci_en:
	return -ENODEV;
}

static void release_device(struct tlkm_pcie_device *pdev)
{
	iounmap(pdev->kvirt_addr_bar0);
	pci_release_regions(pdev->pdev);
	pci_disable_device(pdev->pdev);
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
static int claim_msi(struct tlkm_pcie_device *pdev)
{
	int err = 0, i;
	struct pci_dev *dev = pdev->pdev;
	dev_id_t const did = pdev->parent->dev_id;

	for (i = 0; i < REQUIRED_INTERRUPTS; i++) {
		pdev->irq_mapping[i] = -1;
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
		pdev->msix_entries[i].entry = i;
#endif
	}

#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	err = pci_enable_msix_range(dev,
			pdev->msix_entries,
			REQUIRED_INTERRUPTS,
			REQUIRED_INTERRUPTS);
#else
	/* set up MSI interrupt vector to max size */
	err = pci_alloc_irq_vectors(dev,
			REQUIRED_INTERRUPTS,
			REQUIRED_INTERRUPTS,
			PCI_IRQ_MSIX);
#endif

	if (err <= 0) {
		DEVERR(did, "cannot set MSI vector (%d)", err);
		return -ENOSPC;
	} else {
		DEVLOG(did, TLKM_LF_IRQ, "got %d MSI vectors", err);
	}

	if ((err = pcie_irqs_init(pdev->parent))) {
		DEVERR(did, "failed to register interrupts: %d", err);
		return -ENOSPC;
	}
	return 0;
}

static void release_msi(struct tlkm_pcie_device *pdev)
{
	pcie_irqs_exit(pdev->parent);
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	pci_disable_msix(pdev->pdev);
#else
	pci_free_irq_vectors(pdev->pdev);
#endif

}

static void report_link_status(struct tlkm_pcie_device *pdev)
{
	struct pci_dev *dev = pdev->pdev;
	u16 ctrl_reg = 0;
	int gts = 0;

	pcie_capability_read_word(dev, PCI_EXP_LNKSTA, &ctrl_reg);

	pdev->link_width = (ctrl_reg & PCI_EXP_LNKSTA_NLW) >> PCI_EXP_LNKSTA_NLW_SHIFT;
	pdev->link_speed = ctrl_reg & PCI_EXP_LNKSTA_CLS;

	switch (pdev->link_speed) {
	case PCI_EXP_LNKSTA_CLS_8_0GB:	gts = 80;	break;
	case PCI_EXP_LNKSTA_CLS_5_0GB:	gts = 50;	break;
	case PCI_EXP_LNKSTA_CLS_2_5GB:	gts = 25;	break;
	default: 		 	gts =  0;	break;
	}

	DEVLOG(pdev->parent->dev_id, TLKM_LF_PCIE, "PCIe link width: x%d", pdev->link_width);
	DEVLOG(pdev->parent->dev_id, TLKM_LF_PCIE, "PCIe link speed: %d.%d GT/s", gts / 10, gts % 10);

	tlkm_perfc_link_speed_set(pdev->parent->dev_id, pdev->link_speed);
	tlkm_perfc_link_width_set(pdev->parent->dev_id, pdev->link_width);
}

int tlkm_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct tlkm_device *dev;
	LOG(TLKM_LF_PCIE, "found TaPaSCo PCIe device, registering ...");
	dev = tlkm_bus_new_device((struct tlkm_class *)&pcie_cls,
			XILINX_VENDOR_ID,
			XILINX_DEVICE_ID,
			pdev);
	if (! dev) {
		ERR("could not add device to bus");
		return -ENOMEM;
	}
	return 0;
}

void tlkm_pcie_remove(struct pci_dev *pdev)
{
}

int pcie_device_create(struct tlkm_device *dev, void *data)
{
	int ret = 0;
	struct pci_dev *pci_dev = (struct pci_dev *)data;
	struct tlkm_pcie_device *pdev;
	BUG_ON(! dev);
	BUG_ON(! pci_dev);

	pdev = (struct tlkm_pcie_device *)kzalloc(sizeof(*pdev), GFP_KERNEL);
	if (! pdev) {
		DEVERR(dev->dev_id, "could not allocate private data struct");
		ret = -ENOMEM;
		goto err_pd;
	}

	pdev->parent = dev;
	pdev->pdev = pci_dev;
	dev->private_data = pdev;

	DEVLOG(dev->dev_id, TLKM_LF_PCIE, "claiming PCIe device ...");
	if ((ret = claim_device(pdev))) {
		DEVERR(dev->dev_id, "failed to claim PCIe device: %d", ret);
		goto err_no_device;
	}
	DEVLOG(dev->dev_id, TLKM_LF_PCIE, "configuring PCIe device ...");
	if ((ret = configure_device(pdev->pdev))) {
		DEVERR(dev->dev_id, "failed to configure device: %d", ret);
		goto err_configure;
	}
	DEVLOG(dev->dev_id, TLKM_LF_PCIE, "claiming MSI-X interrupts ...");
	if ((ret = claim_msi(pdev))) {
		DEVERR(dev->dev_id, "failed to claim MSI-X interrupts: %d", ret);
		goto err_configure;
	}

	report_link_status(pdev);
	return 0;

	release_msi(pdev);
err_configure:
	release_device(pdev);
err_no_device:
	kfree(pdev);
	dev->private_data = NULL;
err_pd:
	return ret;
}

void pcie_device_destroy(struct tlkm_device *dev)
{
	if (dev) {
		struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
		BUG_ON(! pdev);
		release_msi(pdev);
		release_device(pdev);
		kfree(pdev);
		dev->private_data = NULL;
	} else {
		WRN("called with NULL device!");
	}
}
