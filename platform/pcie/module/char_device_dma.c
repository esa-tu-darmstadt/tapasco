//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
// Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file char_device_dma.c
 * @brief Implementation of char device system calls of the dma engine
	this is the entry point for user-space software (platform_api) to start dma_transfers on the pcie_bus
	the device allocates memory for buffering and mmap and allows to choose between bounce and double buffering
	these methods are implemented in a blocking manner, thus the calling process is put into sleep-state until transfer has finished
	in addition zero-copy is implemented with a mmapped buffer
 * */

/******************************************************************************/

#include "char_device_dma.h"

/******************************************************************************/
/* global struct and variable declarations */

/* file operations for sw-calls as a char device */
static struct file_operations dma_fops = {
	.owner          = THIS_MODULE,
	.open           = dma_open,
	.release        = dma_close,
	.unlocked_ioctl = dma_ioctl,
	.read           = dma_read,
	.write          = dma_write
};

/* private data used to hold additional information throughout multiple system calls */
static struct priv_data_struct priv_data;

/* char device structure basically for dev_t and fops */
static struct cdev char_dma_cdev;
/* char device number for f3_char_driver major and minor number */
static dev_t char_dma_dev_t;
/* device class entry for sysfs */
struct class *char_dma_class;

static atomic64_t device_opened = ATOMIC_INIT(0);

/******************************************************************************/
/* helper functions used by sys-calls */

/**
 * @brief Transmits arbitrary byte sizes to user-space, handles synchronisation with main memory
 * @param user_buffer Buffer in user-space
 * @param kvirt_buffer Buffer in kernel-space
 * @param dma_handle Matching handle for dma synchronisation
 * @param btt Bytes to transfer
 * @return none
 * */
static void transmit_to_user(void * user_buffer, void * kvirt_buffer, dma_addr_t dma_handle, int64_t btt)
{
	int64_t copy_count;
	fflink_info("user_buf %lX kvirt_buf %lX \nsize %lld dma_handle %lX\n", (unsigned long) user_buffer, (unsigned long) kvirt_buffer, btt, (unsigned long) dma_handle);

	dma_sync_single_for_cpu(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_FROMDEVICE);

	copy_count = copy_to_user(user_buffer, kvirt_buffer, btt);
	if (copy_count)
		fflink_warn("left copy %lld bytes - cache flush %lld bytes\n", (s64)copy_count, dma_cache_fit(btt));

	dma_sync_single_for_device(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_FROMDEVICE);
}

/**
 * @brief Transmits arbitrary byte sizes from user-space, handles synchronisation with main memory
 * @param user_buffer Buffer in user-space
 * @param kvirt_buffer Buffer in kernel-space
 * @param dma_handle Matching handle for dma synchronisation
 * @param btt Bytes to transfer
 * @return none
 * */
static void transmit_from_user(void * user_buffer, void * kvirt_buffer, dma_addr_t dma_handle, int64_t btt)
{
	int64_t copy_count;
	fflink_info("user_buf %lX kvirt_buf %lX \nsize %lld dma_handle %lX\n", (unsigned long) user_buffer, (unsigned long) kvirt_buffer, dma_cache_fit(btt), (unsigned long) dma_handle);

	dma_sync_single_for_cpu(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_TODEVICE);
	// copy data from user
	copy_count = copy_from_user(kvirt_buffer, user_buffer, btt);
	if (copy_count)
		fflink_warn("left copy %lld bytes - cache flush %lld bytes\n", (s64)copy_count, dma_cache_fit(btt));

	dma_sync_single_for_device(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_TODEVICE);
}

/**
 * @brief Ensures that return value is always >= btt and multiple of cache_line_size
 * 	to invalidate/flush only complete cache lines
 * @param btt Bytes to transfer
 * @return BTT as multiple of cache_line_size
 * */
static int64_t dma_cache_fit(int64_t btt)
{
	if ((btt & (priv_data.cache_lsize - 1)) > 0)
		return (btt & priv_data.cache_mask) + priv_data.cache_lsize;
	else
		return btt & priv_data.cache_mask;
}

/**
 * @brief Allocate kernel buffers as pages in certain locations
 * 	and check whether the dma-mask is forfilled
 * @param p Array of kernel pages for buffer
 * @param handle Array of dma bus addresses for buffer
 * @param zone Memory space, where to allocate from (see /proc/buddyinfo)
 * @param direction Whether writeable or readable
 * @return Zero, if all buffers could be allocated and mapped
 * */
static int dma_alloc_pbufs(void** p, dma_addr_t *handle, gfp_t zone, int direction)
{
	int err = 0;
	*p = kmalloc(BUFFER_SIZE, zone);
	if (*p) {
		memset(*p, 0, BUFFER_SIZE);
		*handle = dma_map_single(&get_pcie_dev()->dev,  *p, BUFFER_SIZE, direction);
		if (dma_mapping_error(&get_pcie_dev()->dev, *handle)) {
			fflink_warn("DMA Mapping error\n");
			err = -EFAULT;
		}
	} else {
		fflink_warn("Couldn't retrieve enough memory\n");
		err = -EFAULT;
	}

	return err;
}

/**
 * @brief Free kernel buffers
 * @param p Array of kernel pages for buffer
 * @param handle Array of dma bus addresses for buffer
 * @param direction Whether writeable or readable
 * @return none
 * */
static void dma_free_pbufs(void *p, dma_addr_t handle, int direction)
{
	if (handle) {
		dma_unmap_single(&get_pcie_dev()->dev, handle, BUFFER_SIZE, direction);
	}
	if (p) {
		kfree(p);
	}
}

/**
 * @brief Initializes priv_data for corresponding minor node
 * @param p Pointer to privade data for minor node
 * @param node Minor number
 * @return none
 * */
static void dma_init_pdata(struct priv_data_struct * p)
{
	/* cache size and mask needed for alignemt */
	p->cache_lsize = cache_line_size();
	p->cache_mask = ~(cache_line_size() - 1);

	p->dma_handle_h2l = 0;
	p->dma_handle_l2h = 0;

	p->kvirt_h2l = 0;
	p->kvirt_l2h = 0;

	p->ctrl_base_addr = (void *) AXI_CTRL_BASE_ADDR;

	/* init control structures for synchron sys-calls */

	init_waitqueue_head(&p->read_wait_queue);
	init_waitqueue_head(&p->write_wait_queue);
	mutex_init(&p->read_mutex);
	mutex_init(&p->write_mutex);
	atomic64_set(&p->reads_processed, 0);
	atomic64_set(&p->writes_processed, 0);

	p->mem_addr_h2l = (void *) RAM_BASE_ADDR_0;
	p->mem_addr_l2h = (void *) RAM_BASE_ADDR_0;
	p->device_base_addr = (void *) DMA_BASE_ADDR_0;
}

/******************************************************************************/

/**
 * @brief Generic wrapper to choose between double-/bounce-buffering
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static inline int read_device(int64_t count, char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	return read_with_bounce(count, buf, mem_addr, p);
}

/**
 * @brief Bounce-buffering implementation to transfer data from FPGA to Main memory
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static int read_with_bounce(int64_t count, char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	int64_t current_count = count;
	unsigned int copy_size;
	uint64_t expected_val;
	fflink_notice("Using bounce buffering\n");

	while (current_count > 0) {
		fflink_info("outstanding %lld bytes - \n\t\t user addr %lX - mem addr %lx\n", (s64)current_count, (unsigned long) buf, (unsigned long) mem_addr);
		if (current_count <= BUFFER_SIZE)
			copy_size = current_count;
		else
			copy_size = BUFFER_SIZE;

		expected_val = atomic64_read(&p->reads_processed) + 1;
		transmit_from_device(mem_addr, p->dma_handle_l2h, copy_size, p->device_base_addr);
		if (wait_event_interruptible(p->read_wait_queue, atomic64_read(&p->reads_processed) >= expected_val)) {
			fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
		}
		transmit_to_user(buf, p->kvirt_l2h, p->dma_handle_l2h, copy_size);

		buf += BUFFER_SIZE;
		mem_addr += BUFFER_SIZE;
		current_count -= BUFFER_SIZE;
	}
	return 0;
}

/******************************************************************************/

/**
 * @brief Generic wrapper to choose between double-/bounce-buffering
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static inline int write_device(int64_t count, const char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	return write_with_bounce(count, buf, mem_addr, p);
}

/**
 * @brief Bounce-buffering implementation to transfer data from Main to FPGA memory
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static int write_with_bounce(int64_t count, const char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	int64_t current_count = count;
	uint64_t expected_val;
	fflink_notice("Using bounce buffering\n");

	while (current_count > 0) {
		fflink_info("outstanding %lld bytes - \n\t\t user addr %lX - mem addr %lx\n", (s64)current_count, (unsigned long) buf, (unsigned long) mem_addr);
		expected_val = atomic64_read(&p->writes_processed) + 1;
		if (current_count <= BUFFER_SIZE) {
			transmit_from_user((void *) buf, p->kvirt_h2l, p->dma_handle_h2l, current_count);
			transmit_to_device(mem_addr, p->dma_handle_h2l, current_count, p->device_base_addr);
		} else {
			transmit_from_user((void *) buf, p->kvirt_h2l, p->dma_handle_h2l, BUFFER_SIZE);
			transmit_to_device(mem_addr, p->dma_handle_h2l, BUFFER_SIZE , p->device_base_addr);
		}
		buf += BUFFER_SIZE;
		mem_addr += BUFFER_SIZE;
		current_count -= BUFFER_SIZE;

		if (wait_event_interruptible(p->write_wait_queue, atomic64_read(&p->writes_processed) >= expected_val)) {
			fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
		}
	}
	return 0;
}

static int dma_initialize(void) {
	int err_1 = 0, err_2 = 0, err_return = 0;
	gfp_t zone = GFP_DMA32;

	fflink_notice("Initializing private data");

	dma_init_pdata(&priv_data);

	err_1 = dma_alloc_pbufs(&priv_data.kvirt_h2l, &priv_data.dma_handle_h2l, zone, PCI_DMA_TODEVICE);
	err_2 = dma_alloc_pbufs(&priv_data.kvirt_l2h, &priv_data.dma_handle_l2h, zone, PCI_DMA_FROMDEVICE);

	if (err_1 != 0 || err_2 != 0) {
		fflink_warn("Error during device creation. Error codes: Write direction: %d Read direction: %d\n", err_1, err_2);
		err_return = -ENOSPC;
		goto open_failed_deinit;
	}

	return 0;

open_failed_deinit:
	dma_free_pbufs(priv_data.kvirt_h2l, priv_data.dma_handle_h2l, PCI_DMA_TODEVICE);
	dma_free_pbufs(priv_data.kvirt_l2h, priv_data.dma_handle_l2h, PCI_DMA_FROMDEVICE);
	return err_return;
}

static void dma_deinit(void) {
	fflink_notice("Device not used anymore, removing it.\n");

	dma_free_pbufs(priv_data.kvirt_h2l, priv_data.dma_handle_h2l, PCI_DMA_TODEVICE);
	dma_free_pbufs(priv_data.kvirt_l2h, priv_data.dma_handle_l2h, PCI_DMA_FROMDEVICE);
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
static int dma_open(struct inode *inode, struct file *filp)
{
	fflink_notice("Already %lld files in use.\n", (s64)atomic64_read(&device_opened));

	atomic64_inc(&device_opened);
	/* set filp for further sys calls to this minor number */
	filp->private_data = &priv_data;
	return 0;
}

/**
 * @brief Tidy up code, when device isn't needed anymore
 * @param inode Representation of node in /dev, used to get major-/minor-number
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @return Zero, if char-device could be closed, error code otherwise
 * */
static int dma_close(struct inode *inode, struct file *filp)
{
	atomic64_dec(&device_opened);
	fflink_notice("Still %lld files in use.\n", (s64)atomic64_read(&device_opened));
	return 0;
}

/******************************************************************************/
/* functions for user-space interaction */

/**
 * @brief Performs a dma transfer on the pcie-bus from FPGA to Main memory
	this function can be called from user-space as a system call and is thread-safe
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @param buf Pointer to user space buffer
 * @param count Bytes to be transferred
 * @param f_pos Offset in file, currently not supported
 * @return Zero, if transfer was successful, error code otherwise
 * */
static ssize_t dma_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos)
{
	int err = 0;
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	fflink_notice("Called for device minor %d\n", 0);

	if (mutex_lock_interruptible(&p->read_mutex)) {
		fflink_warn("got killed while aquiring the mutex\n");
		return -EACCES;
	}

	err = read_device(count, buf, p->mem_addr_l2h, p);
	mutex_unlock(&p->read_mutex);

	return err;
}

/**
 * @brief Performs a dma transfer on the pcie-bus from Main to FPGA memory
	this function can be called from user-space as a system call and is thread-safe
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @param buf Pointer to user space buffer
 * @param count Bytes to be transferred
 * @param f_pos Offset in file, currently not supported
 * @return Zero, if transfer was successful, error code otherwise
 * */
static ssize_t dma_write(struct file *filp, const char __user *buf, size_t count, loff_t *f_pos)
{
	int err = 0;
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	fflink_notice("Called for device minor %d\n", 0);

	if (mutex_lock_interruptible(&p->write_mutex)) {
		fflink_warn("got killed while aquiring the mutex\n");
		return -EACCES;
	}

	err = write_device(count, buf, p->mem_addr_h2l, p);
	mutex_unlock(&p->write_mutex);

	return err;
}

/******************************************************************************/
/* function for user-space interaction */

/**
 * @brief User space communication to set fpga memory address and zero copy calls
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @param ioctl_num magic number from ioctl_calls header
 * @param ioctl_param pointer to arguments from user corresponding to provided commands
 * @return Zero, if command could be executed successfully, otherwise error code
 * */
static long dma_ioctl(struct file *filp, unsigned int ioctl_num, unsigned long ioctl_param)
{
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	struct dma_ioctl_params params;
	fflink_notice("Called with number %X for minor %u\n", ioctl_num, 0);

	if (_IOC_SIZE(ioctl_num) != sizeof(struct dma_ioctl_params)) {
		fflink_warn("Wrong size to read out registers %d vs %ld\n", _IOC_SIZE(ioctl_num), sizeof(struct dma_ioctl_params));
		return -EACCES;
	}
	if (copy_from_user(&params, (void *)ioctl_param, _IOC_SIZE(ioctl_num))) {
		fflink_warn("Couldn't copy all bytes\n");
		return -EACCES;
	}

	switch (ioctl_num) {
	case IOCTL_CMD_DMA_SET_MEM_H2L:
		fflink_info("IOCTL_CMD_DMA_SET_MEM_H2L with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
		fflink_info("Set new H2L addr to %llX:\n", params.fpga_addr);

		p->mem_addr_h2l = (void *) params.fpga_addr;
		break;
	case IOCTL_CMD_DMA_SET_MEM_L2H:
		fflink_info("IOCTL_CMD_DMA_SET_MEM_H2L with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
		fflink_info("Set new H2L addr to %llX:\n", params.fpga_addr);

		p->mem_addr_l2h = (void *) params.fpga_addr;
		break;
	case IOCTL_CMD_DMA_READ_BUF:
		fflink_info("IOCTL_CMD_DMA_READ_BUF with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
		fflink_info("Host_addr %llX Fpga_addr %llX btt %u\n", params.host_addr, params.fpga_addr, params.btt);

		if (mutex_lock_interruptible(&p->read_mutex)) {
			fflink_warn("got killed while aquiring the mutex\n");
			return -EACCES;
		}

		read_device(params.btt, (char __user *) params.host_addr, (void *) params.fpga_addr, p);

		mutex_unlock(&p->read_mutex);
		break;
	case IOCTL_CMD_DMA_WRITE_BUF:
		fflink_info("IOCTL_CMD_DMA_WRITE_BUF with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
		fflink_info("Host_addr %llX Fpga_addr %llX btt %d\n", params.host_addr, params.fpga_addr, params.btt);

		if (mutex_lock_interruptible(&p->write_mutex)) {
			fflink_warn("got killed while aquiring the mutex\n");
			return -EACCES;
		}

		write_device(params.btt, (char __user *) params.host_addr, (void *) params.fpga_addr, p);

		mutex_unlock(&p->write_mutex);
		break;
	default:
		fflink_warn("default case - nothing to do here\n");
		break;
	}
	return 0;
}

/******************************************************************************/
/* helper functions externally called e.g. to (un/)load this char device */

/**
 * @brief Get phsical address of dma engine
 * @param i The minor number of the device
 * @return Pointer to physical dma address of corresponding minor node
 * */
void * get_dev_addr(int i)
{
	return priv_data.device_base_addr;
}

/**
 * @brief Increas corresponding counter and wake up queue
 * @param i The minor number of the device
 * @return none
 * */
void wake_up_queue(bool write)
{
	if (write) {
		atomic64_inc(&priv_data.writes_processed);
		wake_up_interruptible_sync(&priv_data.write_wait_queue);
	} else {
		atomic64_inc(&priv_data.reads_processed);
		wake_up_interruptible_sync(&priv_data.read_wait_queue);
	}
}

/**
 * @brief Registers char device with multiple minor nodes in /dev
 * @param none
 * @return Returns error code or zero if successful
 * */
int char_dma_register(void)
{
	int err = 0;
	struct device *device = NULL;

	fflink_info("Try to add char_device to /dev\n");

	/* create device class to register under sysfs */
	err = alloc_chrdev_region(&char_dma_dev_t, 0, 1, FFLINK_DMA_NAME);
	if (err < 0 || MINOR(char_dma_dev_t) != 0) {
		fflink_warn("failed to allocate chrdev with %d minors\n", 1);
		goto error_no_device;
	}

	/* create device class to register under udev/sysfs */
	if (IS_ERR((char_dma_class = class_create(THIS_MODULE, FFLINK_DMA_NAME)))) {
		fflink_warn("failed to create class\n");
		goto error_class_invalid;
	}

	/* initialize char dev with fops to prepare for adding */
	cdev_init(&char_dma_cdev, &dma_fops);
	char_dma_cdev.owner = THIS_MODULE;

	/* try to add char dev */
	err = cdev_add(&char_dma_cdev, char_dma_dev_t, 1);
	if (err) {
		fflink_warn("failed to add char dev\n");
		goto error_add_to_system;
	}

	/* create device file via udev */
	device = device_create(char_dma_class, NULL, MKDEV(MAJOR(char_dma_dev_t), MINOR(char_dma_dev_t)), NULL, FFLINK_DMA_NAME "_%d", MINOR(char_dma_dev_t));
	if (IS_ERR(device)) {
		err = PTR_ERR(device);
		fflink_warn("failed while device create %d\n", MINOR(char_dma_dev_t));
		goto error_device_create;
	}

	dma_ctrl_init((void *) DMA_BASE_ADDR_0);

	return dma_initialize();

	/* tidy up for everything successfully allocated */
error_device_create:
	device_destroy(char_dma_class, MKDEV(MAJOR(char_dma_dev_t), MINOR(char_dma_dev_t)));
	cdev_del(&char_dma_cdev);
error_add_to_system:
	class_destroy(char_dma_class);
error_class_invalid:
	unregister_chrdev_region(char_dma_dev_t, 1);
error_no_device:
	return -ENODEV;
}

/**
 * @brief Unregisters char device, which was initialized with dma_register before
 * @param none
 * @return none
 * */
void char_dma_unregister(void)
{
	fflink_info("Tidy up\n");

	dma_deinit();

	device_destroy(char_dma_class, MKDEV(MAJOR(char_dma_dev_t), MINOR(char_dma_dev_t)));

	cdev_del(&char_dma_cdev);

	class_destroy(char_dma_class);

	unregister_chrdev_region(char_dma_dev_t, 1);
}

/******************************************************************************/
