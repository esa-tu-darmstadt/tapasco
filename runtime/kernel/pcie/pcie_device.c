/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo 
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
#include <linux/pci.h>
#include <linux/version.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/list.h>
#include "pcie.h"
#include "pcie_device.h"
#include "pcie_irq.h"
#include "pcie_qdma.h"
#include "pcie_svm.h"
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_bus.h"

#define TLKM_DEV_ID(pdev)                                                      \
	(((struct tlkm_pcie_device *)dev_get_drvdata(&(pdev)->dev))            \
		 ->parent->dev_id)
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
	BUG_ON(!dev);

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
		DEVWRN(did, "failed to setup bar regions for pci device %d",
		       err);
		goto error_pci_req;
	}

	INIT_LIST_HEAD(&pdev->gp_buffer);
	dev_set_drvdata(&dev->dev, pdev);

	/* read out pci bar 0 settings */
	pdev->phy_addr_bar0 = pci_resource_start(dev, 0);
	pdev->phy_len_bar0 = pci_resource_len(dev, 0);
	pdev->phy_flags_bar0 = pci_resource_flags(dev, 0);

	DEVLOG(did, TLKM_LF_PCIE, "PCI bar 0: address= 0x%zx length: 0x%zx",
	       (size_t)pdev->phy_addr_bar0, (size_t)pdev->phy_len_bar0);

	pdev->parent->base_offset = pdev->phy_addr_bar0;
	DEVLOG(did, TLKM_LF_PCIE, "status core base: 0x%8p => 0x%8p",
	       (void *)pdev->parent->cls->platform.status.base,
	       (void *)pdev->parent->cls->platform.status.base +
		       pdev->parent->base_offset);

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
 * @brief Tries to find the maximum MPS supported by the device and
 *		  its parent as well as the ReadRQ Size. Finally, it turns on
 *		  extended tags if necessary.
 * @param pdev Pointer to pci-device for which the MPS should be set
 * @return No return value as failure to set MPS is not critical
 * */
void tune_pcie_parameters(struct pci_dev *pdev)
{
	dev_id_t id = TLKM_DEV_ID(pdev);
	int ret = -1;
	struct pci_dev *parent = pdev->bus->self;

	int mps_m = 128 << pdev->pcie_mpss;

	int readrq_m = 4096;
	int readrq_c = pcie_get_readrq(pdev);

	uint16_t ectl = 0;

	while (parent) {
		int mps_p = 128 << parent->pcie_mpss;
		DEVLOG(id, TLKM_LF_PCIE, "Current MPS %d/%d.",
		       pcie_get_mps(parent), mps_p);
		mps_m = min(mps_m, mps_p);

		if (pci_is_root_bus(parent->bus)) {
			DEVLOG(id, TLKM_LF_PCIE, "Found the parent.");
			break;
		}
		parent = parent->bus->self;
	}

	parent = pdev->bus->self;

	while (parent) {
		int mps_p = pcie_get_mps(parent);
		if (mps_p < mps_m) {
			pcie_set_mps(parent, mps_m);
		}
		DEVLOG(id, TLKM_LF_PCIE, "Set MPS %d/%d.", pcie_get_mps(parent),
		       128 << parent->pcie_mpss);

		if (pci_is_root_bus(parent->bus)) {
			DEVLOG(id, TLKM_LF_PCIE, "Set MPS up to the parent.");
			break;
		}
		parent = parent->bus->self;
	}

	pcie_set_mps(pdev, mps_m);
	DEVLOG(id, TLKM_LF_PCIE, "Current MPS device %d/%d.",
	       pcie_get_mps(pdev), 128 << pdev->pcie_mpss);

	ret = pcie_set_readrq(pdev, readrq_m);

	if (ret) {
		DEVERR(id, "Failed to set ReadRQ to %d. Staying at ReadRQ %d.",
		       readrq_m, readrq_c);
	} else {
		DEVLOG(id, TLKM_LF_PCIE, "Set ReadRQ to %d from ReadRQ %d.",
		       readrq_c, readrq_m);
	}

	// Turn on extended tags
	ret = pcie_capability_read_word(pdev, PCI_EXP_DEVCTL, &ectl);
	if ((!ret) && !(ectl & PCI_EXP_DEVCTL_EXT_TAG)) {
		DEVLOG(id, TLKM_LF_PCIE, "Enabling PCIe extended tags");
		ectl |= PCI_EXP_DEVCTL_EXT_TAG;
		ret = pcie_capability_write_word(pdev, PCI_EXP_DEVCTL, ectl);
		if (ret)
			DEVERR(id,
			       "Unable to write to PCI config to enable extended tags");
	}
}

/**
 * @brief Configures pcie-device and bit_mask settings
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int configure_device(struct pci_dev *pdev)
{
	dev_id_t id = TLKM_DEV_ID(pdev);

	tune_pcie_parameters(pdev);

	if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))) {
		DEVLOG(id, TLKM_LF_PCIE,
		       "dma_set_mask: using 64 bit DMA addresses");
		dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(64));
	} else if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(32))) {
		DEVLOG(id, TLKM_LF_PCIE,
		       "dma_set_mask: using 32 bit DMA addresses");
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
	int err = 0;
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 8, 0)
	int i;
#endif
	struct pci_dev *dev = pdev->pdev;
	dev_id_t const did = pdev->parent->dev_id;

	int no_int = pdev->parent->cls->number_of_interrupts;

#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 8, 0)
	pdev->msix_entries =
		kzalloc(sizeof(struct msix_entry) * no_int, GFP_KERNEL);
	for (i = 0; i < no_int; i++) {
		pdev->msix_entries[i].entry = i;
	}
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 8, 0)
	err = pci_enable_msix_range(dev, pdev->msix_entries, no_int, no_int);
#else
	/* set up MSI interrupt vector to max size */
	err = pci_alloc_irq_vectors(dev, no_int, no_int, PCI_IRQ_MSIX);
#endif

	if (err <= 0) {
		DEVERR(did, "cannot set MSI vector (%d)", err);
		return -ENOSPC;
	} else {
		DEVLOG(did, TLKM_LF_IRQ, "got %d MSI vectors", err);
	}

	return 0;
}

static void release_msi(struct tlkm_pcie_device *pdev)
{
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 8, 0)
	pci_disable_msix(pdev->pdev);
	kfree(pdev->msix_entries);
	pdev->msix_entries = 0;
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

	pdev->link_width =
		(ctrl_reg & PCI_EXP_LNKSTA_NLW) >> PCI_EXP_LNKSTA_NLW_SHIFT;
	pdev->link_speed = ctrl_reg & PCI_EXP_LNKSTA_CLS;

	switch (pdev->link_speed) {
	case PCI_EXP_LNKSTA_CLS_8_0GB:
		gts = 80;
		break;
	case PCI_EXP_LNKSTA_CLS_5_0GB:
		gts = 50;
		break;
	case PCI_EXP_LNKSTA_CLS_2_5GB:
		gts = 25;
		break;
	default:
		gts = 0;
		break;
	}

	DEVLOG(pdev->parent->dev_id, TLKM_LF_PCIE, "PCIe link width: x%d",
	       pdev->link_width);
	DEVLOG(pdev->parent->dev_id, TLKM_LF_PCIE,
	       "PCIe link speed: %d.%d GT/s", gts / 10, gts % 10);

	tlkm_perfc_link_speed_set(pdev->parent->dev_id, pdev->link_speed);
	tlkm_perfc_link_width_set(pdev->parent->dev_id, pdev->link_width);
}

int tlkm_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct tlkm_device *dev;
	LOG(TLKM_LF_PCIE, "found TaPaSCo PCIe device, registering ...");

	if (pdev->vendor == AWS_EC2_VENDOR_ID &&
	    pdev->device == AWS_EC2_DEVICE_ID) {
		dev = tlkm_bus_new_device((struct tlkm_class *)&pcie_aws_cls,
					  id->vendor, id->device, pdev);
	} else if (pdev->vendor == XILINX_VENDOR_ID &&
		   pdev->device == VERSAL_DEVICE_ID) {
		dev = tlkm_bus_new_device((struct tlkm_class *)&pcie_versal_cls,
					  id->vendor, id->device, pdev);
	} else {
		dev = tlkm_bus_new_device((struct tlkm_class *)&pcie_cls,
					  id->vendor, id->device, pdev);
	}

	if (!dev) {
		ERR("could not add device to bus");
		return -ENOMEM;
	}
	return 0;
}

void tlkm_pcie_remove(struct pci_dev *pdev)
{
	struct tlkm_pcie_device *dev =
		(struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev);
	LOG(TLKM_LF_PCIE, "removing TaPaSCo PCIe device ...");
	if (dev) {
		tlkm_bus_delete_device(dev->parent);
	}
}

int pcie_device_create(struct tlkm_device *dev, void *data)
{
	int ret = 0;
	struct pci_dev *pci_dev = (struct pci_dev *)data;
	struct tlkm_pcie_device *pdev;
	BUG_ON(!dev);
	BUG_ON(!pci_dev);

	pdev = (struct tlkm_pcie_device *)kzalloc(sizeof(*pdev), GFP_KERNEL);
	if (!pdev) {
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

	memset(pdev->dma_buffer, 0,
	       TLKM_PCIE_NUM_DMA_BUFFERS * sizeof(pdev->dma_buffer[0]));

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
		struct tlkm_pcie_device *pdev =
			(struct tlkm_pcie_device *)dev->private_data;
		BUG_ON(!pdev);
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
	uint32_t status, c;
#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	dev_addr_t mmu_base;
#endif
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

	dev_addr_t gpio_base = tlkm_status_get_component_base(
		dev, "PLATFORM_COMPONENT_MEM_GPIO");
	if (gpio_base != -1) {
		volatile uint32_t *ddr_ready = (dev->mmap.plat + gpio_base);
		status = ddr_ready[0];
		for (c = 0; c < 4; c++) {
			if (!(status & (1 << c))) {
				DEVWRN(dev->dev_id,
				       "memory channel %c is not available or not ready",
				       65 + c);
			}
		}
	}

	if (pcie_is_qdma_in_use(dev)) {
		DEVLOG(dev->dev_id, TLKM_LF_PCIE, "initializing QDMA ...");
		ret = pcie_qdma_init(pdev);
		if (ret) {
			DEVERR(dev->dev_id, "failed to initialize QDMA: %d", ret);
			goto pcie_qdma_init_err;
		}
	}

	DEVLOG(dev->dev_id, TLKM_LF_PCIE, "claiming MSI-X interrupts ...");
	if ((ret = claim_msi(pdev))) {
		DEVERR(dev->dev_id, "failed to claim MSI-X interrupts: %d",
		       ret);
		goto pcie_subsystem_err;
	}

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	mmu_base =
		tlkm_status_get_component_base(dev, "PLATFORM_COMPONENT_MMU");
	if (mmu_base != -1) {
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "initializing SVM");
		ret = pcie_init_svm(pdev);
		if (ret) {
			DEVERR(dev->dev_id, "failed to initialize SVM");
			goto pcie_init_svm_err;
		}
	}
#endif

	DEVLOG(dev->dev_id, TLKM_LF_DEVICE,
	       "successfully initialized subsystems");

	return 0;

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
pcie_init_svm_err:
	release_msi(pdev);
#endif
pcie_subsystem_err:
pcie_qdma_init_err:
	return ret;
}

void pcie_device_exit_subsystems(struct tlkm_device *dev)
{
#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	dev_addr_t mmu_base;
#endif
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	mmu_base = tlkm_status_get_component_base(dev, "PLATFORM_COMPONENT_MMU");
	if (mmu_base != -1) {
		pcie_exit_svm(pdev);
	}
#endif

	release_msi(pdev);
	if (pcie_is_qdma_in_use(dev)) {
		if (pcie_qdma_exit(pdev)) {
			DEVERR(dev->dev_id, "could not disable QDMA properly");
		}
	}
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "exited subsystems");
}

void pcie_device_miscdev_close(struct tlkm_device *dev)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;

	int i;
	struct gp_buf *buf, *tmp;

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	dev_addr_t mmu_base;
#endif

	for (i = 0; i < TLKM_PCIE_NUM_DMA_BUFFERS; ++i) {
		if (pdev->dma_buffer[i].ptr != 0) {
			pcie_device_dma_free_buffer(
				dev->dev_id, dev, &pdev->dma_buffer[i].ptr,
				&pdev->dma_buffer[i].ptr_dev,
				pdev->dma_buffer[i].direction,
				pdev->dma_buffer[i].size);
			pdev->dma_buffer[i].size = 0;
		}
	}
	list_for_each_entry_safe(buf, tmp, &pdev->gp_buffer, list) {
		if (buf->dev_addr)
			dma_unmap_single(&pdev->pdev->dev, buf->dev_addr,
					 buf->size, DMA_FROM_DEVICE);
		kfree(buf->buf);
		list_del(&buf->list);
		devm_kfree(&pdev->pdev->dev, buf);
	}

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	mmu_base =
		tlkm_status_get_component_base(dev, "PLATFORM_COMPONENT_MMU");
	if (mmu_base != -1) {
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "tear down SVM");
		pcie_teardown_svm(dev);
	}
#endif
}

int pcie_device_dma_allocate_buffer(dev_id_t dev_id, struct tlkm_device *dev,
				    void **buffer, dma_addr_t *dev_handle,
				    dma_direction_t direction, size_t size)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	int err = 0;
	*buffer = kmalloc(size, 0);
	DEVLOG(dev_id, TLKM_LF_DEVICE,
	       "Allocated %zd bytes at kernel address %p trying to map into DMA space...",
	       size, *buffer);
	if (*buffer) {
		memset(*buffer, 0, size);
		*dev_handle =
			dma_map_single(&pdev->pdev->dev, *buffer, size,
				       direction == FROM_DEV ? DMA_FROM_DEVICE :
							       DMA_TO_DEVICE);
		if (dma_mapping_error(&pdev->pdev->dev, *dev_handle)) {
			DEVERR(dev_id, "DMA Mapping error");
			err = -EFAULT;
		}
	} else {
		DEVERR(dev_id, "Couldn't retrieve enough memory");
		err = -EFAULT;
	}

	DEVLOG(dev_id, TLKM_LF_DEVICE, "Mapped buffer to device address %p",
	       (void *)*dev_handle);

	return err;
}

void pcie_device_dma_free_buffer(dev_id_t dev_id, struct tlkm_device *dev,
				 void **buffer, dma_addr_t *dev_handle,
				 dma_direction_t direction, size_t size)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	DEVLOG(dev_id, TLKM_LF_DEVICE, "Unmapping buffer %p", *buffer);
	if (*dev_handle) {
		dma_unmap_single(&pdev->pdev->dev, *dev_handle, size,
				 direction == FROM_DEV ? DMA_FROM_DEVICE :
							 DMA_TO_DEVICE);
		*dev_handle = 0;
	}
	if (*buffer) {
		kfree(*buffer);
		*buffer = 0;
	}
}

inline int
pcie_device_dma_sync_buffer_cpu(dev_id_t dev_id, struct tlkm_device *dev,
				void **buffer, dma_addr_t *dev_handle,
				dma_direction_t direction, size_t size)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	dma_sync_single_for_cpu(&pdev->pdev->dev, *dev_handle, size,
				direction == FROM_DEV ? DMA_FROM_DEVICE :
							DMA_TO_DEVICE);
	return 0;
}

inline int
pcie_device_dma_sync_buffer_dev(dev_id_t dev_id, struct tlkm_device *dev,
				void **buffer, dma_addr_t *dev_handle,
				dma_direction_t direction, size_t size)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	dma_sync_single_for_device(&pdev->pdev->dev, *dev_handle, size,
				   direction == FROM_DEV ? DMA_FROM_DEVICE :
							   DMA_TO_DEVICE);
	return 0;
}

inline void *pcie_device_addr2map_off(struct tlkm_device *dev,
				      dev_addr_t const addr)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)dev->private_data;
	void *ptr = 0;
	size_t buffer_requested = (addr / 4096) - 4;
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "Request for offset to buffer %zu",
	       buffer_requested);

	if (pdev->dma_buffer[buffer_requested].ptr != 0) {
		DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "Found offset as %p",
		       pdev->dma_buffer[buffer_requested].ptr);
		ptr = (void *)virt_to_phys(
			pdev->dma_buffer[buffer_requested].ptr);
	}
	return ptr;
}