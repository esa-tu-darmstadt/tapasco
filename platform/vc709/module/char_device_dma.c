//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
	.write          = dma_write,
	.mmap			= dma_mmap
};

/* private data used to hold additional information throughout multiple system calls */
static struct priv_data_struct priv_data[FFLINK_DMA_NODES];

/* char device structure basically for dev_t and fops */
static struct cdev char_dma_cdev;	
/* char device number for f3_char_driver major and minor number */
static dev_t char_dma_dev_t;
/* device class entry for sysfs */
struct class *char_dma_class;

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
static void transmit_to_user(void * user_buffer, void * kvirt_buffer, dma_addr_t dma_handle, int btt)
{
	int copy_count;
	fflink_info("user_buf %lX kvirt_buf %lX \nsize %d dma_handle %lX\n", (unsigned long) user_buffer, (unsigned long) kvirt_buffer, btt, (unsigned long) dma_handle);
	
	dma_sync_single_for_cpu(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_FROMDEVICE);

	copy_count = copy_to_user(user_buffer, kvirt_buffer, btt);
	if(copy_count)
		fflink_warn("left copy %u bytes - cache flush %u bytes\n", copy_count, dma_cache_fit(btt));
	
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
static void transmit_from_user(void * user_buffer, void * kvirt_buffer, dma_addr_t dma_handle, int btt)
{
	int copy_count;
	fflink_info("user_buf %lX kvirt_buf %lX \nsize %d dma_handle %lX\n", (unsigned long) user_buffer, (unsigned long) kvirt_buffer, btt, (unsigned long) dma_handle);
	
	dma_sync_single_for_cpu(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_TODEVICE);
	// copy data from user
	copy_count = copy_from_user(kvirt_buffer, user_buffer, btt);
	if(copy_count)
		fflink_warn("left copy %u bytes - cache flush %u bytes\n", copy_count, dma_cache_fit(btt));
	
	dma_sync_single_for_device(&get_pcie_dev()->dev, dma_handle, dma_cache_fit(btt), PCI_DMA_TODEVICE);
}

/**
 * @brief Exchanges data between both pointers
 * @param a Pointer to first date
 * @param b Pointer to second date
 * @return none
 * */
static void switch_index(unsigned int * a, unsigned int * b)
{
	unsigned int tmp = *a;
	
	*a = *b;
	*b = tmp;
}

/**
 * @brief Ensures that return value is always >= btt and multiple of cache_line_size
 * 	to invalidate/flush only complete cache lines
 * @param btt Bytes to transfer
 * @return BTT as multiple of cache_line_size
 * */
static unsigned int dma_cache_fit(unsigned int btt)
{
	if((btt & (priv_data[0].cache_lsize -1)) > 0)
		return (btt & priv_data[0].cache_mask) + priv_data[0].cache_lsize;
	else
		return btt & priv_data[0].cache_mask;
	
}

/**
 * @brief Determines the size of each transfer, when using double_buffering
 * @param count Total number of bytes to transfer
 * @return Byte size for one transfer
 * */
static unsigned int calc_transfer_size(int count)
{
	if(count > DOUBLE_BUFFER_LIMIT && count <= 2*BUFFER_SIZE_USED)
		return count/2;	
	else if(count <= DOUBLE_BUFFER_LIMIT)
		return count;
	else
		return BUFFER_SIZE_USED;
}

/**
 * @brief Determines the kernel virtual addresses of all buffers
 * @param p Priv_data for corresponding minor node
 * @return none
 * */
static void dma_page_to_virt(struct priv_data_struct * p) 
{
	 int i;
	 
	 for(i = 0; i < PBUF_SIZE; i++) {
		 p->kvirt_pbuf_h2l[i] = page_address(p->pbuf_h2l[i]);
		 p->kvirt_pbuf_l2h[i] = page_address(p->pbuf_l2h[i]);
	 }
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
static int dma_alloc_pbufs(struct page * p[], dma_addr_t handle[], gfp_t zone, int direction) 
{
	int i, dma_err, err = 0;
	void *page_ptr;
	
	fflink_notice("Allocate %d tuple of 2^%d Pages or %lu Byte\n or %lu MByte with Bit-Mask %llX in direction %d (1=H2L 2=L2H)\n", 
	PBUF_SIZE, BUFFER_ORDER, BUFFER_SIZE, (BUFFER_SIZE/(1024*1024)), DMA_BIT_MASK(DMA_MAX_BIT), direction);

	for(i = 0; i < PBUF_SIZE; i++) {
		p[i] = 0;
		handle[i] = 0;
		
		if(IS_ERR(p[i] = alloc_pages(zone, BUFFER_ORDER))) {
			fflink_warn("Cannot allocate 2^%d Pages in iteration %d\n", BUFFER_ORDER, i);
			err = -ENOMEM;
		} else {
			page_ptr = page_address(p[i]);
			handle[i] = pci_map_single(get_pcie_dev(), page_ptr, BUFFER_SIZE, direction);
			fflink_info("PCI-Mapping Address (Handle map_single): %llX\n", (unsigned long long int) handle[i]);
			}	
		}
		
		dma_err = pci_dma_mapping_error(get_pcie_dev(), handle[i]);
		if(dma_err) {
			fflink_warn("pci_map mapping error in iteration %d\n", i);
			err = -EFAULT;
			handle[i] = 0;
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
static void dma_free_pbufs(struct page * p[], dma_addr_t handle[], int direction)
{
	int i;
	
	for(i = 0; i < PBUF_SIZE; i++) {
		if(handle[i]) {
			//fflink_driver_info("Unmap pci-mapping in iteration %d\n", i);
			pci_unmap_single(get_pcie_dev(), handle[i], BUFFER_SIZE, direction);
		} else {
			fflink_notice("No pci-mapping in iteration %d\n", i);
		}
		if(p[i]) {
			//fflink_info("Free 2^%d Pages at %llX\n", order, (unsigned long long) p[i]);
			__free_pages(p[i], BUFFER_ORDER);
		} else {
			fflink_notice("No Pages in iteration %d\n", i);
		}
	}
}

/**
 * @brief Initializes priv_data for corresponding minor node
 * @param p Pointer to privade data for minor node
 * @param node Minor number
 * @return none
 * */
static void dma_init_pdata(struct priv_data_struct * p, int node) 
{
	/* cache size and mask needed for alignemt */
	p->cache_lsize = cache_line_size();
	p->cache_mask = ~(cache_line_size() -1);
	
	p->minor = node;
	p->ctrl_base_addr = (void *) AXI_CTRL_BASE_ADDR;
	
	/* init control structures for synchron sys-calls */
	mutex_init(&p->rw_mutex);
	init_waitqueue_head(&p->rw_wait_queue);
	p->condition_rw = false;
	mutex_init(&p->mmap_rbuf_mutex);
	mutex_init(&p->mmap_wbuf_mutex);
	
	/* additional information for sys-calls depending on minor number*/
	switch(node) {
		case 0:
			p->mem_addr_h2l = (void *) RAM_BASE_ADDR_0;
			p->mem_addr_l2h = (void *) RAM_BASE_ADDR_0;
			p->device_base_addr = (void *) DMA_BASE_ADDR_0;
			break;
		case 1: 
			p->mem_addr_h2l = (void *) RAM_BASE_ADDR_1;
			p->mem_addr_l2h = (void *) RAM_BASE_ADDR_1;
			p->device_base_addr = (void *) DMA_BASE_ADDR_1;
			break;
		case 2: 
			p->mem_addr_h2l = (void *) RAM_BASE_ADDR_2;
			p->mem_addr_l2h = (void *) RAM_BASE_ADDR_2;
			p->device_base_addr = (void *) DMA_BASE_ADDR_2;
			break;
		case 3: 
			p->mem_addr_h2l = (void *) RAM_BASE_ADDR_3;
			p->mem_addr_l2h = (void *) RAM_BASE_ADDR_3;
			p->device_base_addr = (void *) DMA_BASE_ADDR_3;
			break;
		default: 
			fflink_warn("wrong minor node opened %d\n", node);
			break;
	}
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
static inline int read_device(int count, char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	if(FFLINK_DOUBLE_BUFFERING == 1)
		return read_with_double(count, buf, mem_addr, p);
	else
		return read_with_bounce(count, buf, mem_addr, p);
}

/**
 * @brief Double-buffering implementation to transfer data from FPGA to Main memory
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static int read_with_double(int count, char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	int current_count = count;
	unsigned int copy_size = calc_transfer_size(count), tic = 1, toc = 2;
	fflink_notice("outstanding %d bytes - \n\t\t user addr %lX - mem addr %lx - with copy_size: %u\n", current_count, (unsigned long) buf, (unsigned long) mem_addr, copy_size);
	
	transmit_from_device(mem_addr, p->dma_handle_l2h[tic], copy_size, p->device_base_addr);
	current_count -= copy_size;
	mem_addr += copy_size;
	
	while(current_count > 0) {
		fflink_info("outstanding %d bytes - \n\t\t user addr %lX - mem addr %lx - tic %d - toc %d\n", current_count, (unsigned long) buf, (unsigned long) mem_addr, tic, toc);
		if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
			fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
		}
		p->condition_rw = false;
		
		if(current_count <= BUFFER_SIZE_USED) {
			transmit_from_device(mem_addr, p->dma_handle_l2h[toc], current_count, p->device_base_addr);
			transmit_to_user(buf, p->kvirt_pbuf_l2h[tic], p->dma_handle_l2h[tic], current_count);			
		} else {
			transmit_from_device(mem_addr, p->dma_handle_l2h[toc], BUFFER_SIZE_USED, p->device_base_addr);
			transmit_to_user(buf, p->kvirt_pbuf_l2h[tic], p->dma_handle_l2h[tic], BUFFER_SIZE_USED);
		}
		
		current_count -= copy_size;
		buf += copy_size;
		mem_addr += copy_size;
		switch_index(&tic, &toc);	
	}
	
	if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
		fflink_warn("got killed while hanging in waiting queue\n");
		return -EACCES;
	}
	p->condition_rw = false;
	transmit_to_user(buf, p->kvirt_pbuf_l2h[tic], p->dma_handle_l2h[tic], copy_size);
	
	return 0;
}

/**
 * @brief Bounce-buffering implementation to transfer data from FPGA to Main memory
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static int read_with_bounce(int count, char __user *buf, void * mem_addr, struct priv_data_struct *p)
{	
	int current_count = count;
	unsigned int copy_size;
	fflink_notice("Using bounce buffering\n");
	
	while(current_count > 0) {
		fflink_info("outstanding %d bytes - \n\t\t user addr %lX - mem addr %lx\n", current_count, (unsigned long) buf, (unsigned long) mem_addr);
		if(current_count <= BUFFER_SIZE)
			copy_size = current_count;
		else
			copy_size = BUFFER_SIZE;
		
		transmit_from_device(mem_addr, p->dma_handle_l2h[1], copy_size, p->device_base_addr);
		if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
			fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
		}
		p->condition_rw = false;
		transmit_to_user(buf, p->kvirt_pbuf_l2h[1], p->dma_handle_l2h[1], copy_size);
		
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
static inline int write_device(int count, const char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	if(FFLINK_DOUBLE_BUFFERING == 1)
		return write_with_double(count, buf, mem_addr, p);
	else
		return write_with_bounce(count, buf, mem_addr, p);
}

/**
 * @brief Double-buffering implementation to transfer data from Main to FPGA memory
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static int write_with_double(int count, const char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	int current_count = count;
	unsigned int copy_size = calc_transfer_size(count), tic = 1, toc = 2;
	fflink_notice("outstanding %d bytes - \n\t\t user addr %lX - mem addr %lx - with copy_size: %u\n", current_count, (unsigned long) buf, (unsigned long) mem_addr, copy_size);

	transmit_from_user((void *) buf, p->kvirt_pbuf_h2l[tic], p->dma_handle_h2l[tic], copy_size);
	current_count -= copy_size;
	buf += copy_size;
	
	while(current_count > 0) {
		fflink_info("outstanding %d bytes - \n\t\t user addr %lX - mem addr %lx\n", current_count, (unsigned long) buf, (unsigned long) p->mem_addr_h2l);
		if(current_count <= BUFFER_SIZE_USED) {
			transmit_to_device(mem_addr, p->dma_handle_h2l[tic], current_count, p->device_base_addr);
			transmit_from_user((void *) buf, p->kvirt_pbuf_h2l[toc], p->dma_handle_h2l[toc], current_count);
		} else {
			transmit_to_device(mem_addr, p->dma_handle_h2l[tic], BUFFER_SIZE_USED , p->device_base_addr);
			transmit_from_user((void *) buf, p->kvirt_pbuf_h2l[toc], p->dma_handle_h2l[toc], BUFFER_SIZE_USED);
		}
		
		current_count -= copy_size;
		buf += copy_size;
		mem_addr += copy_size;
		switch_index(&tic, &toc);
		
		if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
			fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
		}
		p->condition_rw = false;
	}
	
	transmit_to_device(mem_addr, p->dma_handle_h2l[tic], copy_size , p->device_base_addr);
	if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
		fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
	}
	p->condition_rw = false;	
	
	return 0;
}

/**
 * @brief Bounce-buffering implementation to transfer data from Main to FPGA memory
 * @param count Bytes to be transferred
 * @param buf Pointer to user space buffer
 * @param mem_addr Hardware address on the FPGA
 * @param p Pointer to priv_data of associated minor node, needed for kernel buffers and sleeping
 * @return Zero, if transfer was successful, error code otherwise
 * */
static int write_with_bounce(int count, const char __user *buf, void * mem_addr, struct priv_data_struct *p)
{
	int current_count = count;
	fflink_notice("Using bounce buffering\n");
	
	while(current_count > 0) {
		fflink_info("outstanding %d bytes - \n\t\t user addr %lX - mem addr %lx\n", current_count, (unsigned long) buf, (unsigned long) mem_addr);
		if(current_count <= BUFFER_SIZE) {
			transmit_from_user((void *) buf, p->kvirt_pbuf_h2l[1], p->dma_handle_h2l[1], current_count);
			transmit_to_device(mem_addr, p->dma_handle_h2l[1], current_count, p->device_base_addr);
		} else {
			transmit_from_user((void *) buf, p->kvirt_pbuf_h2l[1], p->dma_handle_h2l[1], BUFFER_SIZE);
			transmit_to_device(mem_addr, p->dma_handle_h2l[1], BUFFER_SIZE , p->device_base_addr);
		}
		buf += BUFFER_SIZE;
		mem_addr += BUFFER_SIZE;
		current_count -= BUFFER_SIZE;
		
		if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
			fflink_warn("got killed while hanging in waiting queue\n");
			return -EACCES;
		}
		p->condition_rw = false;
	}	
	return 0;
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
	int err_1 = 0, err_2 = 0;
	fflink_notice("Called for device (<%d,%d>)\n", imajor(inode), iminor(inode));
	
	/* currently maximal four engines are supported - see switch case in dma_init */
	if(iminor(inode) < FFLINK_DMA_NODES && iminor(inode) >= 0 && iminor(inode) < 4)
		dma_init_pdata(&priv_data[iminor(inode)], iminor(inode));
	else
		return -ENODEV;
	
	/* set filp for further sys calls to this minor number */
	filp->private_data = &priv_data[iminor(inode)];

	/* get buffers for dma, this could possibly go wrong */
	if(DMA_MAX_BIT == 32) {
		err_1 = dma_alloc_pbufs(priv_data[iminor(inode)].pbuf_h2l, priv_data[iminor(inode)].dma_handle_h2l, GFP_DMA32, PCI_DMA_TODEVICE);
		err_2 = dma_alloc_pbufs(priv_data[iminor(inode)].pbuf_l2h, priv_data[iminor(inode)].dma_handle_l2h, GFP_DMA32, PCI_DMA_FROMDEVICE);
	} else if (DMA_MAX_BIT == 64) {
		err_1 = dma_alloc_pbufs(priv_data[iminor(inode)].pbuf_h2l, priv_data[iminor(inode)].dma_handle_h2l, GFP_KERNEL, PCI_DMA_TODEVICE);
		err_2 = dma_alloc_pbufs(priv_data[iminor(inode)].pbuf_l2h, priv_data[iminor(inode)].dma_handle_l2h, GFP_KERNEL, PCI_DMA_FROMDEVICE);
	} else {
		fflink_warn("Wrong bit mask setting - only 32/64 supported, but have %d\n", DMA_MAX_BIT);
		return -EFAULT;
	}
	
	dma_page_to_virt(&priv_data[iminor(inode)]);
	
	if(err_1 != 0 || err_2 != 0) {
		fflink_warn("Error is here %d %d %d %d\n", err_1, err_2, imajor(inode), iminor(inode));
		dma_free_pbufs(priv_data[iminor(inode)].pbuf_h2l, priv_data[iminor(inode)].dma_handle_h2l, PCI_DMA_TODEVICE);
		dma_free_pbufs(priv_data[iminor(inode)].pbuf_l2h, priv_data[iminor(inode)].dma_handle_l2h, PCI_DMA_FROMDEVICE);
		return -ENOSPC;
	}
	
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
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	fflink_notice("Close called for device (<%d,%d>)\n", imajor(inode), iminor(inode));
	
	// release mutex, which might be locked from mmap call
	// shall be refactored to more general approach, when using multiple mmap buffers
	mutex_trylock(&p->mmap_rbuf_mutex);
	mutex_unlock(&p->mmap_rbuf_mutex);
	mutex_trylock(&p->mmap_wbuf_mutex);
	mutex_unlock(&p->mmap_wbuf_mutex);
	
	dma_free_pbufs(priv_data[iminor(inode)].pbuf_h2l, priv_data[iminor(inode)].dma_handle_h2l, PCI_DMA_TODEVICE);
	dma_free_pbufs(priv_data[iminor(inode)].pbuf_l2h, priv_data[iminor(inode)].dma_handle_l2h, PCI_DMA_FROMDEVICE);
	
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
	fflink_notice("Called for device minor %d\n", p->minor);
	
	if(mutex_lock_interruptible(&p->rw_mutex)) {
		fflink_warn("got killed while aquiring the mutex\n");
		return -EACCES;
	}
	
	err = read_device(count, buf, p->mem_addr_l2h, p);
	mutex_unlock(&p->rw_mutex);
	
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
	fflink_notice("Called for device minor %d\n", p->minor);
	
	if(mutex_lock_interruptible(&p->rw_mutex)) {
		fflink_warn("got killed while aquiring the mutex\n");
		return -EACCES;
	}
	
	err = write_device(count, buf, p->mem_addr_h2l, p);
	mutex_unlock(&p->rw_mutex);
	
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
	fflink_notice("Called with number %X for minor %u\n", ioctl_num, p->minor);
	
	if(_IOC_SIZE(ioctl_num) != sizeof(struct dma_ioctl_params)) {
		fflink_warn("Wrong size to read out registers %d vs %ld\n", _IOC_SIZE(ioctl_num), sizeof(struct dma_ioctl_params));
		return -EACCES;
	}
	if(copy_from_user(&params, (void *)ioctl_param, _IOC_SIZE(ioctl_num))) {
		fflink_warn("Couldn't copy all bytes\n");
		return -EACCES;
	}
	if(mutex_lock_interruptible(&p->rw_mutex)) {
		fflink_warn("got killed while aquiring the mutex\n");
		return -EACCES;
	}
	
	switch(ioctl_num) {
		case IOCTL_CMD_DMA_READ_MMAP:
			fflink_info("IOCTL_CMD_DMA_READ_MMAP with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
			fflink_info("Btt: %d\n", params.btt);
			
			dma_sync_single_for_device(&get_pcie_dev()->dev, p->dma_handle_l2h[0], dma_cache_fit(params.btt), PCI_DMA_TODEVICE);
			transmit_from_device(p->mem_addr_l2h, p->dma_handle_l2h[0], params.btt, p->device_base_addr);
			if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
				fflink_warn("got killed while hanging in waiting queue\n");
				break;
			}
			p->condition_rw = false;	
				
			dma_sync_single_for_cpu(&get_pcie_dev()->dev, p->dma_handle_l2h[0], dma_cache_fit(params.btt), PCI_DMA_TODEVICE);
			break;
		case IOCTL_CMD_DMA_WRITE_MMAP:
			fflink_info("IOCTL_CMD_DMA_WRITE_MMAP with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
			fflink_info("Btt: %d\n", params.btt);
			
			dma_sync_single_for_device(&get_pcie_dev()->dev, p->dma_handle_h2l[0], dma_cache_fit(params.btt), PCI_DMA_TODEVICE);
			transmit_to_device(p->mem_addr_h2l, p->dma_handle_h2l[0], params.btt, p->device_base_addr);
			if(wait_event_interruptible(p->rw_wait_queue, p->condition_rw == true)) {
				fflink_warn("got killed while hanging in waiting queue\n");
				break;
			}
			p->condition_rw = false;
			
			dma_sync_single_for_cpu(&get_pcie_dev()->dev, p->dma_handle_h2l[0], dma_cache_fit(params.btt), PCI_DMA_TODEVICE);
			break;
		case IOCTL_CMD_DMA_READ_BUF:
			fflink_info("IOCTL_CMD_DMA_READ_BUF with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
			fflink_info("Host_addr %llX Fpga_addr %llX btt %u\n", params.host_addr, params.fpga_addr, params.btt);
			
			read_device(params.btt, (char __user *) params.host_addr, (void *) params.fpga_addr, p);
			break;
		case IOCTL_CMD_DMA_WRITE_BUF:
			fflink_info("IOCTL_CMD_DMA_WRITE_BUF with Param-Size: %d byte\n", _IOC_SIZE(ioctl_num));
			fflink_info("Host_addr %llX Fpga_addr %llX btt %d\n", params.host_addr, params.fpga_addr, params.btt);
			
			write_device(params.btt, (char __user *) params.host_addr, (void *) params.fpga_addr, p);
			break;
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
		default:
			fflink_warn("default case - nothing to do here\n");
			break;
	}
	
	mutex_unlock(&p->rw_mutex);
	return 0;
}

/******************************************************************************/
/* function for user-space interaction */

/**
 * @brief Tries to hand kernel buffer to user-space for zero copy
	Currently one buffer in each direction can be used for each char_device
 * @param filp Needed to identify device node and get access to corresponding buffers
 * @param vma Struct of virtual memory representation, will be modified to allow user-space access 
 * @return Zero, if memory could be mapped, error code otherwise
 * */
static int dma_mmap(struct file *filp, struct vm_area_struct *vma)
{
	struct priv_data_struct * p = (struct priv_data_struct *) filp->private_data;
	fflink_notice("Map buffer with %lu Kbyte to user space for minor %u\n", BUFFER_SIZE/1024, p->minor);
		
	/* change here vma->vm_page_prot if neccessary */
	//vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
	if(((1 << _PAGE_BIT_RW) & vma->vm_page_prot.pgprot) && p->kvirt_pbuf_h2l[0]){
		fflink_info("Give user writable physical addr %lX\n", (unsigned long) virt_to_phys(p->kvirt_pbuf_h2l[0]));
		if(mutex_lock_interruptible(&p->mmap_wbuf_mutex)) {
			fflink_warn("got killed while aquiring the mutex\n");
			return -ENOSPC;
		}
			
		dma_sync_single_for_cpu(&get_pcie_dev()->dev, p->dma_handle_h2l[0], BUFFER_SIZE, PCI_DMA_TODEVICE);
		return vm_iomap_memory(vma, virt_to_phys(p->kvirt_pbuf_h2l[0]), BUFFER_SIZE);
		
	} else if(p->kvirt_pbuf_l2h[0]) {
		fflink_info("Give user readable physical addr %lX\n", (unsigned long) virt_to_phys(p->kvirt_pbuf_l2h[0]));	
		if(mutex_lock_interruptible(&p->mmap_rbuf_mutex)) {
			fflink_warn("got killed while aquiring the mutex\n");
			return -ENOSPC;
		}
		
		dma_sync_single_for_cpu(&get_pcie_dev()->dev, p->dma_handle_l2h[0], BUFFER_SIZE, PCI_DMA_FROMDEVICE);
		return vm_iomap_memory(vma, virt_to_phys(p->kvirt_pbuf_l2h[0]), BUFFER_SIZE);
	}
	
	fflink_warn("probably wrong flags - invalid memory unlikely\n");
	return -EACCES;
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
	BUG_ON(i < 0 || i >= FFLINK_DMA_NODES);
	return priv_data[i].device_base_addr;
}

/**
 * @brief Wake up processes for corresponding minor node
 * @param i The minor number of the device
 * @return none
 * */
void wake_up_queue(int i)
{
	BUG_ON(i < 0 || i >= FFLINK_DMA_NODES);
	priv_data[i].condition_rw = true;
	wake_up_interruptible_sync(&priv_data[i].rw_wait_queue);
}
	
/**
 * @brief Registers char device with multiple minor nodes in /dev
 * @param none
 * @return Returns error code or zero if successful
 * */
int char_dma_register(void)
{
	int err = 0, i;
	struct device *device = NULL;
	
	fflink_info("Try to add char_device to /dev\n");
	
	/* create device class to register under sysfs */
	err = alloc_chrdev_region(&char_dma_dev_t, 0, FFLINK_DMA_NODES, FFLINK_DMA_NAME);
	if (err < 0 || MINOR(char_dma_dev_t) != 0) {
		fflink_warn("failed to allocate chrdev with %d minors\n", FFLINK_DMA_NODES);
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
	err = cdev_add(&char_dma_cdev, char_dma_dev_t, FFLINK_DMA_NODES);
	if (err) {
		fflink_warn("failed to add char dev\n");
		goto error_add_to_system;
	}

	for(i = 0; i < FFLINK_DMA_NODES; i++) {
		/* create device file via udev */
		device = device_create(char_dma_class, NULL, MKDEV(MAJOR(char_dma_dev_t), MINOR(char_dma_dev_t)+i), NULL, FFLINK_DMA_NAME "_%d", MINOR(char_dma_dev_t)+i);
		if (IS_ERR(device)) {
			err = PTR_ERR(device);
			fflink_warn("failed while device create %d\n", MINOR(char_dma_dev_t));
			goto error_device_create;
		}
	}
	
	return 0;
	
	/* tidy up for everything successfully allocated */
error_device_create:
	for(i = i - 1; i >= 0; i--) {
		device_destroy(char_dma_class, MKDEV(MAJOR(char_dma_dev_t), MINOR(char_dma_dev_t)+i));
	}
	cdev_del(&char_dma_cdev);
error_add_to_system:
	class_destroy(char_dma_class);
error_class_invalid:
	unregister_chrdev_region(char_dma_dev_t, FFLINK_DMA_NODES);
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
	int i;
	
	fflink_info("Tidy up\n");
	
	for(i = 0; i < FFLINK_DMA_NODES; i++) {
		device_destroy(char_dma_class, MKDEV(MAJOR(char_dma_dev_t), MINOR(char_dma_dev_t)+i));
	}
	
	cdev_del(&char_dma_cdev);
	
	class_destroy(char_dma_class);
	
	unregister_chrdev_region(char_dma_dev_t, FFLINK_DMA_NODES);
}

/******************************************************************************/
