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

#include "char_device_hsa_dma.h"

/******************************************************************************/
/* global struct and variable declarations */

/* file operations for sw-calls as a char device */
static struct file_operations hsa_dma_fops = {
	.owner          = THIS_MODULE,
	.open           = hsa_dma_open,
	.release        = hsa_dma_close,
	.unlocked_ioctl = hsa_dma_ioctl,
	.read           = hsa_dma_read,
	.write          = hsa_dma_write,
	.mmap           = hsa_dma_mmap
};

/* private data used to hold additional information throughout multiple system calls */
static struct priv_data_struct priv_data;

/* char device structure basically for dev_t and fops */
static struct cdev char_hsa_dma_cdev;
/* char device number for f3_char_driver major and minor number */
static dev_t char_hsa_dma_dev_t;
/* device class entry for sysfs */
struct class *char_hsa_dma_class;

static int device_opened = 0;
static DEFINE_SPINLOCK(device_open_close_mutex);
static DEFINE_SPINLOCK(ioctl_mutex);

static int hsa_dma_alloc_mem(void** p, dma_addr_t *handle, size_t *mem_size)
{
	int err = 0;

	for(*mem_size = HSA_DUMMY_DMA_BUFFER_SIZE; *mem_size > 0; *mem_size = *mem_size / 2) {
		*p = dma_alloc_coherent(&get_pcie_dev()->dev, *mem_size, handle, GFP_KERNEL | __GFP_HIGHMEM);
		if (*p == 0) {
			fflink_warn("Couldn't allocate %lu bytes coherent memory for the HSA Queue\n", *mem_size);
		} else {
			fflink_warn("Got %lu bytes dma memory at dma address %llx and kvirt address %llx \n", *mem_size, *handle, (uint64_t) *p);
			break;
		}
	}
	if(*mem_size == 0)
		err = -1;

	return err;
}

/**
 * @brief Free kernel buffers
 * @param p Array of kernel pages for buffer
 * @param handle Array of dma bus addresses for buffer
 * @param direction Whether writeable or readable
 * @return none
 * */
static void hsa_dma_free_mem(void *p, dma_addr_t handle, size_t mem_size)
{
	if (p != 0) {
		dma_free_coherent(&get_pcie_dev()->dev, mem_size, p, handle);
	}
}

/**
 * @brief Initializes priv_data for corresponding minor node
 * @param p Pointer to privade data for minor node
 * @param node Minor number
 * @return none
 * */
static void hsa_dma_init_pdata(struct priv_data_struct * p)
{
	p->kvirt_shared_mem = 0;

	p->dma_shared_mem = 0;

	p->mem_size = 0;
}

static int hsa_dma_initialize(void) {
	hsa_dma_init_pdata(&priv_data);

	return hsa_dma_alloc_mem((void**)&priv_data.kvirt_shared_mem, &priv_data.dma_shared_mem, &priv_data.mem_size);
}

static void hsa_dma_deinit(void) {
	fflink_notice("Device not used anymore, removing it.\n");
	hsa_dma_free_mem(priv_data.kvirt_shared_mem, priv_data.dma_shared_mem, priv_data.mem_size);
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
static int hsa_dma_open(struct inode *inode, struct file *filp)
{

	spin_lock(&device_open_close_mutex);

	fflink_notice("Already %d files in use.\n", device_opened);

	++device_opened;
	/* set filp for further sys calls to this minor number */
	filp->private_data = &priv_data;
	spin_unlock(&device_open_close_mutex);
	return 0;
}

/**
 * @brief Tidy up code, when device isn't needed anymore
 * @param inode Representation of node in /dev, used to get major-/minor-number
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @return Zero, if char-device could be closed, error code otherwise
 * */
static int hsa_dma_close(struct inode *inode, struct file *filp)
{
	spin_lock(&device_open_close_mutex);
	--device_opened;
	fflink_notice("Still %d files in use.\n", device_opened);
	spin_unlock(&device_open_close_mutex);
	return 0;
}

/******************************************************************************/
/* functions for user-space interaction */

/**
 * */
static ssize_t hsa_dma_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos)
{
	// TODO
	return -EACCES;
}

/**
 * */
static ssize_t hsa_dma_write(struct file *filp, const char __user *buf, size_t count, loff_t *f_pos)
{
	// TODO

	return -EACCES;
}

/******************************************************************************/
/* function for user-space interaction *
*/

static long hsa_dma_ioctl(struct file *filp, unsigned int ioctl_num, unsigned long ioctl_param)
{
	int err = 0;
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	struct hsa_dma_ioctl_params params;
	fflink_notice("Called with number %X for minor %u\n", ioctl_num, 0);

	if (_IOC_SIZE(ioctl_num) != sizeof(struct hsa_dma_ioctl_params)) {
		fflink_warn("Wrong size to read out registers %d vs %ld\n", _IOC_SIZE(ioctl_num), sizeof(struct hsa_dma_ioctl_params));
		return -EACCES;
	}
	if (copy_from_user(&params, (void *)ioctl_param, _IOC_SIZE(ioctl_num))) {
		fflink_warn("Couldn't copy all bytes\n");
		return -EACCES;
	}

	spin_lock(&ioctl_mutex);
	switch (ioctl_num) {
	case IOCTL_CMD_HSA_DMA_ADDR:
		params.data = (uint64_t)p->dma_shared_mem;
		break;
	case IOCTL_CMD_HSA_DMA_SIZE:
		params.data = (uint64_t)p->mem_size;
		break;
	}
	if(copy_to_user((void*)ioctl_param, &params, _IOC_SIZE(ioctl_num))) {
		fflink_warn("Couldn't copy all bytes back to userspace\n");
		err = -EACCES;
		goto err_handler;
	}
	err_handler:
	spin_unlock(&ioctl_mutex);
	return err;
}

static int hsa_dma_mmap(struct file *filp, struct vm_area_struct *vma)
{
	if (priv_data.kvirt_shared_mem == 0)
		return -EAGAIN;
	return dma_mmap_coherent(&get_pcie_dev()->dev, vma, priv_data.kvirt_shared_mem, priv_data.dma_shared_mem, vma->vm_end - vma->vm_start);
}

/******************************************************************************/
/* helper functions externally called e.g. to (un/)load this char device */

/**
 * @brief Registers char device with multiple minor nodes in /dev
 * @param none
 * @return Returns error code or zero if successful
 * */
int char_hsa_dma_register(void)
{
	int err = 0;
	struct device *device = NULL;

	fflink_info("Try to add char_device to /dev\n");

	/* create device class to register under sysfs */
	err = alloc_chrdev_region(&char_hsa_dma_dev_t, 0, 1, FFLINK_HSA_DMA_NAME);
	if (err < 0 || MINOR(char_hsa_dma_dev_t) != 0) {
		fflink_warn("failed to allocate chrdev with %d minors\n", 1);
		goto error_no_device;
	}

	/* create device class to register under udev/sysfs */
	if (IS_ERR((char_hsa_dma_class = class_create(THIS_MODULE, FFLINK_HSA_DMA_NAME)))) {
		fflink_warn("failed to create class\n");
		goto error_class_invalid;
	}

	/* initialize char dev with fops to prepare for adding */
	cdev_init(&char_hsa_dma_cdev, &hsa_dma_fops);
	char_hsa_dma_cdev.owner = THIS_MODULE;

	/* try to add char dev */
	err = cdev_add(&char_hsa_dma_cdev, char_hsa_dma_dev_t, 1);
	if (err) {
		fflink_warn("failed to add char dev\n");
		goto error_add_to_system;
	}

	/* create device file via udev */
	device = device_create(char_hsa_dma_class, NULL, MKDEV(MAJOR(char_hsa_dma_dev_t), MINOR(char_hsa_dma_dev_t)), NULL, FFLINK_HSA_DMA_NAME "_%d", MINOR(char_hsa_dma_dev_t));
	if (IS_ERR(device)) {
		err = PTR_ERR(device);
		fflink_warn("failed while device create %d\n", MINOR(char_hsa_dma_dev_t));
		goto error_device_create;
	}

	return hsa_dma_initialize();

	/* tidy up for everything successfully allocated */
error_device_create:
	device_destroy(char_hsa_dma_class, MKDEV(MAJOR(char_hsa_dma_dev_t), MINOR(char_hsa_dma_dev_t)));
	cdev_del(&char_hsa_dma_cdev);
error_add_to_system:
	class_destroy(char_hsa_dma_class);
error_class_invalid:
	unregister_chrdev_region(char_hsa_dma_dev_t, 1);
error_no_device:
	return -ENODEV;
}

/**
 * @brief Unregisters char device, which was initialized with dma_register before
 * @param none
 * @return none
 * */
void char_hsa_dma_unregister(void)
{
	fflink_info("Tidy up\n");

	hsa_dma_deinit();

	device_destroy(char_hsa_dma_class, MKDEV(MAJOR(char_hsa_dma_dev_t), MINOR(char_hsa_dma_dev_t)));

	cdev_del(&char_hsa_dma_cdev);

	class_destroy(char_hsa_dma_class);

	unregister_chrdev_region(char_hsa_dma_dev_t, 1);
}

/******************************************************************************/
