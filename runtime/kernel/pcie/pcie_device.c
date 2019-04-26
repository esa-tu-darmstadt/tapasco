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
#include "char_device_hsa.h"

#define TLKM_DEV_ID(pdev) \
	(((struct tlkm_pcie_device *)dev_get_drvdata(&(pdev)->dev))->parent->dev_id)

uint32_t get_xdma_reg_addr(uint32_t target, uint32_t channel, uint32_t offset)
{
	return ((target << 12) | (channel << 8) | offset);
}

static int aws_ec2_configure_xdma(struct tlkm_pcie_device *pdev)
{
	dev_id_t const did = pdev->parent->dev_id;
	struct pci_dev *dev = pdev->pdev;

	void __iomem *bar2;
	uint32_t val;

	DEVLOG(did, TLKM_LF_PCIE, "Mapping BAR2 and configuring XDMA core");
	bar2 = ioremap_nocache(pci_resource_start(dev, 2), pci_resource_len(dev, 2));

	if (!bar2) {
		DEVERR(did, "XDMA ioremap_nocache failed");
		return -ENODEV;
	}

	DEVLOG(did, TLKM_LF_PCIE, "XDMA addr: %p\n", bar2);
	DEVLOG(did, TLKM_LF_PCIE, "XDMA len: %x\n", (int)pci_resource_len(dev, 2));

	val = ioread32(bar2 + get_xdma_reg_addr(2, 0, 0));
	DEVLOG(did, TLKM_LF_PCIE, "XDMA IRQ block identifier: %x\n", val);

	// set user interrupt vectors
	iowrite32(0x03020100, bar2 + get_xdma_reg_addr(2, 0, 0x80));
	iowrite32(0x07060504, bar2 + get_xdma_reg_addr(2, 0, 0x84));
	iowrite32(0x0b0a0908, bar2 + get_xdma_reg_addr(2, 0, 0x88));
	iowrite32(0x0f0e0d0c, bar2 + get_xdma_reg_addr(2, 0, 0x8c));

	// set user interrupt enable mask
	iowrite32(0xffff, bar2 + get_xdma_reg_addr(2, 0, 0x04));
	wmb();

	val = ioread32(bar2 + get_xdma_reg_addr(2, 0, 0x04));
	DEVLOG(did, TLKM_LF_PCIE, "XDMA user IER: %x\n", val);

	DEVLOG(did, TLKM_LF_PCIE, "Finished configuring XDMA core, unmapping BAR2");
	iounmap(bar2);
	return 0;
}

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

	// set up XDMA user interrupts on AWS EC2 platform
	if (dev->vendor == AWS_EC2_VENDOR_ID && dev->device == AWS_EC2_DEVICE_ID) {
		err = aws_ec2_configure_xdma(pdev);
		if (err) {
			DEVERR(did, "failed to configure XDMA core");
			goto error_pci_req;
		}

		pdev->phy_addr_bar0 	= pci_resource_start(dev, 4);
		pdev->phy_len_bar0	= pci_resource_len(dev, 4);
		pdev->phy_flags_bar0	= pci_resource_flags(dev, 4);
	} else {
		/* read out pci bar 0 settings */
		pdev->phy_addr_bar0 	= pci_resource_start(dev, 0);
		pdev->phy_len_bar0	= pci_resource_len(dev, 0);
		pdev->phy_flags_bar0	= pci_resource_flags(dev, 0);
	}

	DEVLOG(did, TLKM_LF_PCIE, "PCI bar 0: address= 0x%zx length: 0x%zx",
	       (size_t) pdev->phy_addr_bar0, (size_t) pdev->phy_len_bar0);

	pdev->parent->base_offset = pdev->phy_addr_bar0;
	DEVLOG(did, TLKM_LF_PCIE, "status core base: 0x%8p => 0x%8p",
	       (void*) pcie_cls.platform.status.base, (void*) pcie_cls.platform.status.base + pdev->parent->base_offset);

	return 0;

error_pci_req:
	pci_disable_device(pdev->pdev);
error_pci_en:
	return -ENODEV;
}

static void release_device(struct tlkm_pcie_device *pdev)
{
	struct pci_dev *dev = pdev->pdev;
	dev_set_drvdata(&dev->dev, NULL);
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

	if (dev->vendor == AWS_EC2_VENDOR_ID && dev->device == AWS_EC2_DEVICE_ID) {
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
		err = pci_enable_msix_range(dev,
		                            pdev->msix_entries,
		                            16,
		                            16);
#else
		/* set up MSI interrupt vector to max size */
		err = pci_alloc_irq_vectors(dev,
		                            16,
		                            16,
		                            PCI_IRQ_MSIX);
#endif
	} else {
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
	}

	if (err <= 0) {
		DEVERR(did, "cannot set MSI vector (%d)", err);
		return -ENOSPC;
	} else {
		DEVLOG(did, TLKM_LF_IRQ, "got %d MSI vectors", err);
	}

	if (dev->vendor == AWS_EC2_VENDOR_ID && dev->device == AWS_EC2_DEVICE_ID) {
		err = aws_ec2_pcie_irqs_init(pdev->parent);
	} else {
		err = pcie_irqs_init(pdev->parent);
	}

	if (err) {
		DEVERR(did, "failed to register interrupts: %d", err);
		return -ENOSPC;
	}
	return 0;
}

static void release_msi(struct tlkm_pcie_device *pdev)
{
	if (pdev->pdev->vendor == AWS_EC2_VENDOR_ID && pdev->pdev->device == AWS_EC2_DEVICE_ID) {
		aws_ec2_pcie_irqs_exit(pdev->parent);
	} else {
		pcie_irqs_exit(pdev->parent);
	}
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
	                          id->vendor,
	                          id->device,
	                          pdev);
	if (! dev) {
		ERR("could not add device to bus");
		return -ENOMEM;
	}
	return 0;
}

void tlkm_pcie_remove(struct pci_dev *pdev)
{
	struct tlkm_pcie_device *dev = (struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	LOG(TLKM_LF_PCIE, "removing TaPaSCo PCIe device ...");
	if(dev) {
		tlkm_bus_delete_device(dev->parent);
	}
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
	report_link_status(pdev);
	return 0;

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

int pcie_device_init_subsystems(struct tlkm_device *dev, void *data)
{
	int ret = 0;
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	DEVLOG(dev->dev_id, TLKM_LF_PCIE, "claiming MSI-X interrupts ...");
	if ((ret = claim_msi(pdev))) {
		DEVERR(dev->dev_id, "failed to claim MSI-X interrupts: %d", ret);
		goto pcie_subsystem_err;
	}
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "initializing HSA subsystems");
	if((ret = char_hsa_register(dev))) {
		DEVERR(dev->dev_id, "failed to initialize HSA subsystem: %d", ret);
		goto pcie_subsystem_err;
	}

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "successfully initialized subsystems");

	return 0;
pcie_subsystem_err:
	return ret;
}

void pcie_device_exit_subsystems(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	char_hsa_unregister();
	release_msi(pdev);
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "exited subsystems");
}

int pcie_device_dma_allocate_buffer(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	// We should really allocate memory and not misuse the void* as dma_addr_t
	// Should be the same size on most systems, however
	dma_addr_t *handle = (dma_addr_t*)dev_handle;
	int err = 0;
	*buffer = kmalloc(size, 0);
	DEVLOG(dev_id, TLKM_LF_DEVICE, "Allocated %zd bytes at kernel address %p trying to map into DMA space...", size, *buffer);
	if (*buffer) {
		memset(*buffer, 0, size);
		*handle = dma_map_single(&pdev->pdev->dev, *buffer, size, direction == FROM_DEV ? DMA_FROM_DEVICE : DMA_TO_DEVICE);
		if (dma_mapping_error(&pdev->pdev->dev, *handle)) {
			DEVERR(dev_id, "DMA Mapping error");
			err = -EFAULT;
		}
	} else {
		DEVERR(dev_id, "Couldn't retrieve enough memory");
		err = -EFAULT;
	}

	DEVLOG(dev_id, TLKM_LF_DEVICE, "Mapped buffer to device address %p", (void*) *handle);

	return err;
}

void pcie_device_dma_free_buffer(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	dma_addr_t *handle = (dma_addr_t*)dev_handle;
	DEVLOG(dev_id, TLKM_LF_DEVICE, "Mapped buffer to device address %p", (void*) *handle);
	if (*handle) {
		dma_unmap_single(&pdev->pdev->dev, *handle, size, direction == FROM_DEV ? DMA_FROM_DEVICE : DMA_TO_DEVICE);
		*handle = 0;
	}
	if (*buffer) {
		kfree(*buffer);
		*buffer = 0;
	}
}

inline int pcie_device_dma_sync_buffer_cpu(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size) {
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	dma_addr_t *handle = (dma_addr_t*)dev_handle;
	DEVLOG(dev_id, TLKM_LF_DEVICE, "Mapping buffer %p for cpu", *dev_handle);
	dma_sync_single_for_cpu(&pdev->pdev->dev, *handle, size, direction == FROM_DEV ? DMA_FROM_DEVICE : DMA_TO_DEVICE);
	return 0;
}

inline int pcie_device_dma_sync_buffer_dev(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size) {
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	dma_addr_t *handle = (dma_addr_t*)dev_handle;
	DEVLOG(dev_id, TLKM_LF_DEVICE, "Mapping buffer %p for device", *dev_handle);
	dma_sync_single_for_device(&pdev->pdev->dev, *handle, size, direction == FROM_DEV ? DMA_FROM_DEVICE : DMA_TO_DEVICE);
	return 0;
}
