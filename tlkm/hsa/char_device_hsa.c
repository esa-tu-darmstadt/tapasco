//
// Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file char_device_dma.c
 * @brief TODO
 * */

/******************************************************************************/

/* Includes from linux headers */
#include <linux/module.h>
#include <linux/version.h>
#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/kdev_t.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <asm/io.h>
#include <asm/atomic.h>
#include <linux/aio.h>
#include <linux/uio.h>
#include <linux/highmem.h>
#include <linux/interrupt.h>
#include <linux/mutex.h>
#include <linux/semaphore.h>
#include <linux/spinlock.h>
#include <linux/errno.h>
#include <asm/uaccess.h>
#include <linux/delay.h>
#include <linux/pci.h>
#include <linux/sched.h>

#include "tlkm/tlkm_device.h"
#include "tlkm/tlkm_class.h"
#include "pcie/pcie_device.h"
#include "pcie/pcie_irq.h"

#include "char_device_hsa.h"

#define TLKM_HSA_MAJOR 421

/******************************************************************************/
/* global struct and variable declarations */

/******************************************************************************/
/* functions for user-space interaction */
static int hsa_open(struct inode *, struct file *);
static int hsa_close(struct inode *, struct file *);
static long hsa_ioctl(struct file *, unsigned int, unsigned long);
static int hsa_mmap(struct file *, struct vm_area_struct *vma);

/******************************************************************************/
/* helper functions called for sys-calls */
static int hsa_alloc_queue(void** p, dma_addr_t *handle);
static void hsa_free_queue(void *p, dma_addr_t handle);

/* file operations for sw-calls as a char device */
static struct file_operations hsa_fops = {
	.owner          = THIS_MODULE,
	.open           = hsa_open,
	.release        = hsa_close,
	.unlocked_ioctl = hsa_ioctl,
	.mmap           = hsa_mmap
};

struct priv_data_struct dev;

struct device* extractDevice(struct tlkm_device *dev) {
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)dev->private_data;
	return &pdev->pdev->dev;
}

/******************************************************************************/
/* helper functions used by sys-calls */

static void enable_queue_fetcher(uint64_t update_rate) {
	struct hsa_mmap_space *dma_mem = (struct hsa_mmap_space*)dev.dma_shared_mem;

	dev.arbiter_base[HSA_ARBITER_REGISTER_HOST_ADDR] = (uint64_t)&dma_mem->queue;
	dev.arbiter_base[HSA_ARBITER_REGISTER_READ_INDEX_ADDR] = (uint64_t)&dma_mem->read_index;
	dev.arbiter_base[HSA_ARBITER_REGISTER_PASID_ADDR] = (uint64_t)&dma_mem->pasids;
	dev.arbiter_base[HSA_ARBITER_REGISTER_QUEUE_SIZE] = HSA_QUEUE_LENGTH_MOD2;
	dev.arbiter_base[HSA_ARBITER_REGISTER_FPGA_ADDR] = HSA_MEMORY_BASE_ADDR;

	dev.arbiter_base[HSA_ARBITER_REGISTER_UPDATE_RATE] = update_rate;
}

static void disable_queue_fetcher(void) {
	dev.arbiter_base[HSA_ARBITER_REGISTER_WRITE_INDEX_ADDR] = -1;
	dev.arbiter_base[HSA_ARBITER_REGISTER_UPDATE_RATE] = 0;
}

static int hsa_alloc_queue(void** p, dma_addr_t *handle)
{
	size_t mem_size = sizeof(struct hsa_mmap_space);

	*p = dma_alloc_coherent(extractDevice(dev.dev), mem_size, handle, 0);
	if (*p == 0) {
		DEVERR(dev.dev->dev_id, "Couldn't allocate %zu bytes coherent memory for the HSA Queue", mem_size);
		return -1;
	}
	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Got dma memory at dma address %llx and virtual address %p", *handle, *p);

	return 0;
}

/**
 * @brief Free kernel buffers
 * @param p Array of kernel pages for buffer
 * @param handle Array of dma bus addresses for buffer
 * @param direction Whether writeable or readable
 * @return none
 * */
static void hsa_free_queue(void *p, dma_addr_t handle)
{
	if (p != 0) {
		size_t mem_size = sizeof(struct hsa_mmap_space);
		dma_free_coherent(extractDevice(dev.dev), mem_size, p, handle);
	}
}

static int hsa_dma_alloc_mem(void** p, dma_addr_t *handle, size_t *mem_size)
{
	int err = 0;

	for (*mem_size = HSA_DUMMY_DMA_BUFFER_SIZE; *mem_size > 0; *mem_size = *mem_size / 2) {
		*p = dma_alloc_coherent(extractDevice(dev.dev), *mem_size, handle, 0);
		if (*p == 0) {
			DEVLOG(dev.dev->dev_id, TLKM_LF_HSA, "Couldn't allocate %lu bytes coherent memory for the HSA Queue", *mem_size);
		} else {
			DEVLOG(dev.dev->dev_id, TLKM_LF_HSA, "Got %lu bytes dma memory at dma address %llx and kvirt address %p", *mem_size, *handle, *p);
			break;
		}
	}
	if (*mem_size == 0)
		err = -1;

	return err;
}

static void hsa_dma_free_mem(void *p, dma_addr_t handle, size_t mem_size)
{
	if (p != 0) {
		dma_free_coherent(extractDevice(dev.dev), mem_size, p, handle);
	}
}

static int hsa_initialize(void) {
	int i;

	dev.kvirt_shared_mem = 0;

	dev.dma_shared_mem = 0;

	for (i = 0; i < HSA_SIGNALS; ++i) {
		dev.signal_allocated[i] = 0;
	}

	dev.signal_base = 0;
	dev.arbiter_base = 0;

	atomic64_set(&dev.device_opened, 0);
	mutex_init(&dev.ioctl_mutex);

	dev.arbiter_base = (uint64_t *)ioremap_nocache(dev.dev->base_offset + HSA_ARBITER_BASE_ADDR, HSA_ARBITER_SIZE);
	if (dev.arbiter_base == 0) {
		DEVERR(dev.dev->dev_id, "could not map arbiter");
		goto arbiter_map_failed;
	}

	if (dev.arbiter_base[HSA_ARBITER_REGISTER_ID] != HSA_ARBITER_ID) {
		DEVERR(dev.dev->dev_id, "could not find queue fetcher core");
		goto arbiter_find_failed;
	}

	dev.signal_base = (uint64_t *)ioremap_nocache(dev.dev->base_offset + HSA_SIGNAL_BASE_ADDR, HSA_SIGNAL_SIZE);
	if (dev.signal_base == 0) {
		DEVERR(dev.dev->dev_id, "could not map arbiter");
		goto arbiter_find_failed;
	}

	if (dev.signal_base[HSA_SIGNAL_REGISTER_ID] != HSA_SIGNAL_ID) {
		DEVERR(dev.dev->dev_id, "could not find queue fetcher core");
		goto signal_find_failed;
	}

	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Fetcher core and arbiter found");

	if (hsa_alloc_queue((void**)&dev.kvirt_shared_mem, &dev.dma_shared_mem)) {
		DEVERR(dev.dev->dev_id, "Failed to allocate memory for the queue.");
		goto signal_find_failed;
	}

	if (hsa_dma_alloc_mem((void**)&dev.dummy_kvirt, &dev.dummy_dma, &dev.dummy_mem_size)) {
		DEVERR(dev.dev->dev_id, "Failed to allocate dummy memory.");
		goto hsa_dma_mem_failed;
	}

	// Invalidate all packages in the queue
	for (i = 0; i < HSA_QUEUE_LENGTH; ++i) {
		dev.kvirt_shared_mem->queue[i][0] = 1;
	}
	dev.kvirt_shared_mem->read_index = 0;

	enable_queue_fetcher(HSA_UPDATE_RATE);

	return 0;

hsa_dma_mem_failed:
	hsa_free_queue(dev.kvirt_shared_mem, dev.dma_shared_mem);
	dev.kvirt_shared_mem = 0;
signal_find_failed:
	iounmap(dev.signal_base);
	dev.signal_base = 0;
arbiter_find_failed:
	iounmap(dev.arbiter_base);
	dev.arbiter_base = 0;
arbiter_map_failed:
	return -1;
}

static void hsa_deinit(void) {
	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA, "Device not used anymore, removing it.");
	disable_queue_fetcher();
	hsa_free_queue(dev.kvirt_shared_mem, dev.dma_shared_mem);
	dev.kvirt_shared_mem = 0;
	hsa_dma_free_mem(dev.dummy_kvirt, dev.dummy_dma, dev.dummy_mem_size);
	dev.dummy_kvirt = 0;
	iounmap(dev.signal_base);
	dev.signal_base = 0;
	iounmap(dev.arbiter_base);
	dev.arbiter_base = 0;
}

/******************************************************************************/
/* functions for user-space interaction */

/**
 * @brief When minor node is opened, kernel buffers will be allocated,
    performs dma-mappings and registeres these in filp for further calls
 * @param inode Representation of node in /dev, used to get major-/minor-number
 * @param filp Mostly used to allocate private data for consecutive calls
 * @return Zero, if char-device could be opened, error code otherwise
 * */
static int hsa_open(struct inode *inode, struct file *filp)
{
	filp->private_data = &dev;
	atomic64_inc(&dev.device_opened);
	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Already %lld files in use.", (long long int)atomic64_read(&dev.device_opened));
	return 0;
}

/**
 * @brief Tidy up code, when device isn't needed anymore
 * @param inode Representation of node in /dev, used to get major-/minor-number
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @return Zero, if char-device could be closed, error code otherwise
 * */
static int hsa_close(struct inode *inode, struct file *filp)
{
	atomic64_dec(&dev.device_opened);
	DEVERR(dev.dev->dev_id, "Still %lld files in use.", (long long int)atomic64_read(&dev.device_opened));
	return 0;
}

irqreturn_t intr_handler_hsa_signals(int irq, void * dev_id)
{
	struct hsa_mmap_space *dma_mem = (struct hsa_mmap_space*)dev.dma_shared_mem;
	uint64_t signal = dev.signal_base[HSA_SIGNAL_ADDR];
	uint64_t *signal_kvirt = (uint64_t*)dev.kvirt_shared_mem->signals;
	signal -= (uint64_t)dma_mem->signals;
	signal /= sizeof(uint64_t);
	--signal_kvirt[signal];
	dev.signal_base[HSA_SIGNAL_ACK] = 1;
	return IRQ_HANDLED;
}

/******************************************************************************/
/* function for user-space interaction */

void assign_doorbell(int offset) {
	struct hsa_mmap_space *dma_mem = (struct hsa_mmap_space*)dev.dma_shared_mem;
	dev.arbiter_base[HSA_ARBITER_REGISTER_WRITE_INDEX_ADDR] = (uint64_t)&dma_mem->signals[offset];
}

void unassign_doorbell(void) {
	dev.arbiter_base[HSA_ARBITER_REGISTER_WRITE_INDEX_ADDR] = -1;
}

/**
 * */
static long hsa_ioctl(struct file *filp, unsigned int ioctl_num, unsigned long ioctl_param)
{
	int i;
	int err = 0;
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	struct hsa_ioctl_params params;
	struct hsa_mmap_space *dma_mem = (struct hsa_mmap_space*)dev.dma_shared_mem;
	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Called with number %X for minor %u\n", ioctl_num, 0);

	if (_IOC_SIZE(ioctl_num) != sizeof(struct hsa_ioctl_params)) {
		DEVERR(dev.dev->dev_id, "Wrong size to read out registers %d vs %ld\n", _IOC_SIZE(ioctl_num), sizeof(struct hsa_ioctl_params));
		return -EACCES;
	}
	if (copy_from_user(&params, (void *)ioctl_param, _IOC_SIZE(ioctl_num))) {
		DEVERR(dev.dev->dev_id, "Couldn't copy all bytes\n");
		return -EACCES;
	}

	mutex_lock(&dev.ioctl_mutex);
	switch (ioctl_num) {
	case IOCTL_CMD_HSA_SIGNAL_ALLOC:
		for (i = 0; i < HSA_SIGNALS; ++i) {
			if (p->signal_allocated[i] == 0) {
				params.addr = (void*)&dma_mem->signals[i];
				params.offset = i;
				p->signal_allocated[i] = 1;
				DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Allocated signal %d at 0x%llx", (int)params.offset, (uint64_t)params.addr);
				if (copy_to_user((void*)ioctl_param, &params, _IOC_SIZE(ioctl_num))) {
					DEVERR(dev.dev->dev_id, "Couldn't copy all bytes back to userspace\n");
					err = -EACCES;
					goto err_handler;
				}
				break;
			}
		}
		if (i == HSA_SIGNALS) {
			DEVERR(dev.dev->dev_id, "No signals left.");
			err = -EACCES;
			goto err_handler;
		}
		break;
	case IOCTL_CMD_HSA_SIGNAL_DEALLOC:
		p->signal_allocated[params.offset] = 0;
		DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Deallocated signal %d", (int)params.offset);
		break;
	case IOCTL_CMD_HSA_DOORBELL_ASSIGN:
		DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Assign doorbell to signal %d", (int)params.offset);
		assign_doorbell(params.offset);
		break;
	case IOCTL_CMD_HSA_DOORBELL_UNASSIGN:
		DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Unassign doorbell");
		unassign_doorbell();
		break;
	case IOCTL_CMD_HSA_DMA_ADDR:
		params.data = (uint64_t)p->dummy_dma;
		if (copy_to_user((void*)ioctl_param, &params, _IOC_SIZE(ioctl_num))) {
			DEVERR(dev.dev->dev_id, "Couldn't copy all bytes back to userspace\n");
			err = -EACCES;
			goto err_handler;
		}
		break;
	case IOCTL_CMD_HSA_DMA_SIZE:
		params.data = (uint64_t)p->dummy_mem_size;
		if (copy_to_user((void*)ioctl_param, &params, _IOC_SIZE(ioctl_num))) {
			DEVERR(dev.dev->dev_id, "Couldn't copy all bytes back to userspace\n");
			err = -EACCES;
			goto err_handler;
		}
		break;
	}

err_handler:
	mutex_unlock(&dev.ioctl_mutex);
	return err;

}

static int hsa_mmap(struct file *filp, struct vm_area_struct *vma)
{
	int ret = 0;
	if (vma->vm_pgoff == 0) {
		if (dev.kvirt_shared_mem == 0)
			return -EAGAIN;
		DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "MMapping queue memory to user space");
		ret = dma_mmap_coherent(extractDevice(dev.dev), vma, dev.kvirt_shared_mem, dev.dma_shared_mem, vma->vm_end - vma->vm_start);
	} else if (vma->vm_pgoff == 1) {
		if (dev.dummy_kvirt == 0)
			return -EAGAIN;
		vma->vm_pgoff = 0;
		DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "MMapping dummy memory to user space %llx %p %ld", dev.dummy_dma, dev.dummy_kvirt, vma->vm_end - vma->vm_start);
		ret = dma_mmap_coherent(extractDevice(dev.dev), vma, dev.dummy_kvirt, dev.dummy_dma, vma->vm_end - vma->vm_start);
	} else if (vma->vm_pgoff == 2) {
		struct tlkm_device *dp = dev.dev;

		DEVLOG(dp->dev_id, TLKM_LF_HSA,
		       "mapping %u bytes from physical address 0x%lx to user space 0x%lx-0x%lx", HSA_ARBITER_SIZE,
		       dp->base_offset + HSA_ARBITER_BASE_ADDR, vma->vm_start, vma->vm_end);
		vma->vm_pgoff = 0;
		vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
		if (io_remap_pfn_range(vma, vma->vm_start, (dp->base_offset + HSA_ARBITER_BASE_ADDR) >> PAGE_SHIFT, HSA_ARBITER_SIZE, vma->vm_page_prot)) {
			DEVWRN(dp->dev_id, "io_remap_pfn_range failed!");
			return -EAGAIN;
		}
		DEVLOG(dp->dev_id, TLKM_LF_HSA, "register space mapping successful");
	} else if (vma->vm_pgoff == 3) {
		struct tlkm_device *dp = dev.dev;

		DEVLOG(dp->dev_id, TLKM_LF_HSA,
		       "mapping %u bytes from physical address 0x%lx to user space 0x%lx-0x%lx", HSA_SIGNAL_SIZE,
		       dp->base_offset + HSA_ARBITER_BASE_ADDR, vma->vm_start, vma->vm_end);
		vma->vm_pgoff = 0;
		vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
		if (io_remap_pfn_range(vma, vma->vm_start, (dp->base_offset + HSA_SIGNAL_BASE_ADDR) >> PAGE_SHIFT, HSA_SIGNAL_SIZE, vma->vm_page_prot)) {
			DEVWRN(dp->dev_id, "io_remap_pfn_range failed!");
			return -EAGAIN;
		}
		DEVLOG(dp->dev_id, TLKM_LF_HSA, "register space mapping successful");
	}
	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA, "Return code %d", ret);
	return ret;
}

/******************************************************************************/
/* helper functions externally called e.g. to (un/)load this char device */

/**
 * @brief Registers char device with multiple minor nodes in /dev
 * @param none
 * @return Returns error code or zero if successful
 * */
int char_hsa_register(struct tlkm_device *tlkm_dev)
{
	int err = 0;

	dev.dev = tlkm_dev;

	DEVLOG(dev.dev->dev_id, TLKM_LF_HSA,  "Trying to create chardev for HSA queue handling.");

	/* create device class to register under sysfs */
	err = register_chrdev_region(MKDEV(TLKM_HSA_MAJOR, 0), 1, TLKM_HSA_NAME);
	if (err != 0) {
		DEVERR(dev.dev->dev_id, "Failed to create char device");
		goto error_no_device;
	}

	dev.dev_class = class_create(THIS_MODULE, TLKM_HSA_NAME);
	if (dev.dev_class == NULL) {
		DEVERR(dev.dev->dev_id, "Failed to create device class");
		goto class_failed;
	}

	if (device_create(dev.dev_class, NULL, MKDEV(TLKM_HSA_MAJOR, 0), NULL, TLKM_HSA_NAME"_0") == NULL) {
		DEVERR(dev.dev->dev_id, "Failed to create device");
		goto device_create_failed;
	}

	/* initialize char dev with fops to prepare for adding */
	cdev_init(&dev.cdev, &hsa_fops);
	if (cdev_add(&dev.cdev, MKDEV(TLKM_HSA_MAJOR, 0), 1) == -1) {
		DEVERR(dev.dev->dev_id, "Failed to add chardev");
		goto cdev_add_failed;
	}

	if (hsa_initialize() != 0) {
		DEVERR(dev.dev->dev_id, "Failed to initialize HSA queue/HSA infrastructure not available.");
		goto error_device_create;
	}

	pcie_irqs_request_platform_irq(tlkm_dev, 2, intr_handler_hsa_signals, 0);

	return 0;

error_device_create:
	cdev_del(&dev.cdev);
cdev_add_failed:
	device_destroy(dev.dev_class, MKDEV(TLKM_HSA_MAJOR, 0));
device_create_failed:
	class_destroy(dev.dev_class);
class_failed:
	unregister_chrdev_region(MKDEV(TLKM_HSA_MAJOR, 0), 1);
error_no_device:
	dev.dev = NULL;
	return 0;
}

/**
 * @brief Unregisters char device, which was initialized with dma_register before
 * @param none
 * @return none
 * */
void char_hsa_unregister(void)
{
	if (dev.dev) {
		hsa_deinit();

		pcie_irqs_release_platform_irq(dev.dev, 2);

		cdev_del(&dev.cdev);
		device_destroy(dev.dev_class, MKDEV(TLKM_HSA_MAJOR, 0));
		class_destroy(dev.dev_class);
		unregister_chrdev_region(MKDEV(TLKM_HSA_MAJOR, 0), 1);
	}
}

/******************************************************************************/
