//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
//! @file	zynq_chardev.c
//! @brief	Character device controlling Tapasco threadpools for
//!		the zynq TPC Platform.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/fs.h>
#include <linux/dma-mapping.h>
#include <linux/sched.h>
#include <linux/time.h>
#include "zynq_device.h"
#include "zynq_logging.h"
#include "zynq_dmamgmt.h"

struct zynq_device zynq_dev;

static int zynq_device_mmap(struct file *filp, struct vm_area_struct *vma)
{
	size_t size;
	unsigned int minor;
	unsigned long start_addr;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	size = vma->vm_end - vma->vm_start;
	minor = iminor(filp->f_path.dentry->d_inode);
	if (minor == zynq_dev.miscdev[0].minor) {
		start_addr = ZYNQ_DEVICE_THREADS_BASE;
	} else if (minor == zynq_dev.miscdev[1].minor) {
		start_addr = ZYNQ_DEVICE_INTC_BASE;
	} else {
		start_addr = ZYNQ_DEVICE_TAPASCO_STATUS_BASE;
	}

	LOG(ZYNQ_LL_DEVICE, "d%u: mmapping %zu bytes, from 0x%08lx-0x%08lx",
			minor, size, start_addr, start_addr + size);

	vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);

	if (io_remap_pfn_range(vma, vma->vm_start, start_addr >> PAGE_SHIFT,
			size, vma->vm_page_prot)) {
		WRN("io_remap_pfn_range failed");
		return -EAGAIN;
	}

	LOG(ZYNQ_LL_DEVICE, "d%u: register space mapped successfully", minor);
	LOG(ZYNQ_LL_ENTEREXIT, "exit");
	return 0;
}

static struct file_operations zynq_device_fops = {
	.owner = THIS_MODULE,
	.mmap  = zynq_device_mmap
};

/******************************************************************************/
static ssize_t zynq_device_wait(struct device *dev,
		struct device_attribute *attr, char const *buf, size_t count)
{
	u32 id, cd = 0;
	long got_ev, wait_ret;
	LOG(ZYNQ_LL_ENTEREXIT, "enter");
	id = *(u32 *)buf;
	LOG(ZYNQ_LL_DEVICE, "checking for %u", id);

	while ((got_ev = zynq_dev.pending_ev[id]) <= 0) {
		++cd;
		LOG(ZYNQ_LL_DEVICE, "sleeping on %u", id);
		wait_ret = wait_event_interruptible_timeout(zynq_dev.ev_q[id],
				zynq_dev.pending_ev[id] != 0,
				10 * HZ);
		if (wait_ret < 0) {
			WRN("wait for %u interrupted by signal %ld!", id, wait_ret);
			return wait_ret;
		}
	}

	if (! got_ev) {
		WRN("TIMEOUT: did not get event %u", id);
		return -ETIMEDOUT;
	}

	__atomic_fetch_sub(&zynq_dev.pending_ev[id], 1, __ATOMIC_SEQ_CST);

	LOG(ZYNQ_LL_ENTEREXIT, "exit");
	return 0;
}

static ssize_t zynq_device_pending_ev(struct device *dev,
		struct device_attribute *attr, char *buf)
{
	int i;
	ssize_t r = 0;
	for (i = 0; i < ZYNQ_DEVICE_THREADS_NUM; ++i)
		r += sprintf(&buf[i * 16], "%03d: %10ld\n", i, zynq_dev.pending_ev[i]);
	return r;
}

static ssize_t zynq_device_total_ev(struct device *dev,
		struct device_attribute *attr, char *buf)
{
	return sprintf(buf, "%lu\n", zynq_dev.total_ev);
}

static int init_misc_devs(void)
{
	int retval;
	zynq_dev.miscdev[0].minor = MISC_DYNAMIC_MINOR;
	zynq_dev.miscdev[0].name  = ZYNQ_DEVICE_CLSNAME "_" ZYNQ_DEVICE_DEVNAME "_gp0";
	zynq_dev.miscdev[0].fops  = &zynq_device_fops;

	retval = misc_register(&zynq_dev.miscdev[0]);
	if (retval < 0) {
		ERR("could not create misc device '%s'", zynq_dev.miscdev[0].name);
		goto err;
	}

	zynq_dev.miscdev[1].minor = MISC_DYNAMIC_MINOR;
	zynq_dev.miscdev[1].name  = ZYNQ_DEVICE_CLSNAME "_" ZYNQ_DEVICE_DEVNAME "_gp1";
	zynq_dev.miscdev[1].fops  = &zynq_device_fops;

	retval = misc_register(&zynq_dev.miscdev[1]);
	if (retval < 0) {
		ERR("could not create misc device '%s'", zynq_dev.miscdev[1].name);
		goto err_gp1;
	}

	zynq_dev.miscdev[2].minor = MISC_DYNAMIC_MINOR;
	zynq_dev.miscdev[2].name  = ZYNQ_DEVICE_CLSNAME "_" ZYNQ_DEVICE_DEVNAME "_tapasco_status";
	zynq_dev.miscdev[2].fops  = &zynq_device_fops;

	retval = misc_register(&zynq_dev.miscdev[2]);
	if (retval < 0) {
		ERR("could not create misc device '%s'", zynq_dev.miscdev[2].name);
		goto err_tapasco_status;
	}
	return retval;

err_tapasco_status:
	misc_deregister(&zynq_dev.miscdev[1]);
err_gp1:
	misc_deregister(&zynq_dev.miscdev[0]);
err:
	return retval;
}

static void exit_misc_devs(void)
{
	misc_deregister(&zynq_dev.miscdev[2]);
	misc_deregister(&zynq_dev.miscdev[1]);
	misc_deregister(&zynq_dev.miscdev[0]);
}

static DEVICE_ATTR(wait, S_IWUSR | S_IWGRP, NULL, zynq_device_wait);
static DEVICE_ATTR(pending_ev, S_IRUSR | S_IRGRP, zynq_device_pending_ev, NULL);
static DEVICE_ATTR(total_ev, S_IRUSR | S_IRGRP, zynq_device_total_ev, NULL);

static int init_sysfs_files(void)
{
	int retval;

	retval = device_create_file(zynq_dev.miscdev[2].this_device, &dev_attr_wait);
	if (retval < 0) {
		ERR("failed to create 'wait' device file");
		goto err_wait;
	}
	retval = device_create_file(zynq_dev.miscdev[2].this_device, &dev_attr_pending_ev);
	if (retval < 0) {
		ERR("failed to create 'pending_ev' device file");
		goto err_pending_ev;
	}
	retval = device_create_file(zynq_dev.miscdev[2].this_device, &dev_attr_total_ev);
	if (retval < 0) {
		ERR("failed to create 'total_ev' device file");
		goto err_total_ev;
	}

	return retval;


	device_remove_file(zynq_dev.miscdev[2].this_device, &dev_attr_total_ev);
err_total_ev:
	device_remove_file(zynq_dev.miscdev[2].this_device, &dev_attr_pending_ev);
err_pending_ev:
	device_remove_file(zynq_dev.miscdev[2].this_device, &dev_attr_wait);
err_wait:
	return retval;
}

static void exit_sysfs_files(void)
{
	device_remove_file(zynq_dev.miscdev[2].this_device, &dev_attr_total_ev);
	device_remove_file(zynq_dev.miscdev[2].this_device, &dev_attr_pending_ev);
	device_remove_file(zynq_dev.miscdev[2].this_device, &dev_attr_wait);
}

static int init_iomapping(void)
{
	int retval = 0;
	zynq_dev.gp_map[0] = ioremap_nocache(ZYNQ_DEVICE_THREADS_BASE,
			ZYNQ_DEVICE_THREADS_OFFS * ZYNQ_DEVICE_THREADS_NUM);
	if (IS_ERR(zynq_dev.gp_map[0])) {
		ERR("could not ioremap the AXI register space at 0x%08x-0x%08x",
				ZYNQ_DEVICE_THREADS_BASE,
				ZYNQ_DEVICE_THREADS_BASE +
				ZYNQ_DEVICE_THREADS_NUM *
				ZYNQ_DEVICE_THREADS_OFFS);
		retval = PTR_ERR(zynq_dev.gp_map[0]);
		goto err_gp0;
	}

	zynq_dev.gp_map[1] = ioremap_nocache(ZYNQ_DEVICE_INTC_BASE,
			ZYNQ_DEVICE_INTC_NUM * ZYNQ_DEVICE_INTC_OFFS);
	if (IS_ERR(zynq_dev.gp_map[1])) {
		ERR("could not ioremap the AXI register space at 0x%08x-0x%08x",
				ZYNQ_DEVICE_INTC_BASE,
				ZYNQ_DEVICE_INTC_BASE +
				ZYNQ_DEVICE_INTC_NUM *
				ZYNQ_DEVICE_INTC_OFFS);
		retval = PTR_ERR(zynq_dev.gp_map[0]);
		goto err_gp1;
	}

	zynq_dev.tapasco_status = ioremap_nocache(ZYNQ_DEVICE_TAPASCO_STATUS_BASE,
			ZYNQ_DEVICE_TAPASCO_STATUS_SIZE);
	if (IS_ERR(zynq_dev.tapasco_status)) {
		ERR("could not ioremap the AXI register space at 0x%08x-0x%08x",
				ZYNQ_DEVICE_TAPASCO_STATUS_BASE,
				ZYNQ_DEVICE_TAPASCO_STATUS_BASE +
				ZYNQ_DEVICE_TAPASCO_STATUS_SIZE);
		retval = PTR_ERR(zynq_dev.tapasco_status);
		goto err_tapasco_status;
	}
	return retval;

err_tapasco_status:
	iounmap(zynq_dev.gp_map[1]);
err_gp1:
	iounmap(zynq_dev.gp_map[0]);
err_gp0:
	return retval;
}

static void exit_iomapping(void)
{
	iounmap(zynq_dev.tapasco_status);
	iounmap(zynq_dev.gp_map[1]);
	iounmap(zynq_dev.gp_map[0]);
}

/******************************************************************************/
int zynq_device_init(void)
{
	int retval;
	LOG(ZYNQ_LL_ENTEREXIT, "enter" );

	for (retval = 0; retval < ZYNQ_DEVICE_THREADS_NUM; ++retval) {
		zynq_dev.pending_ev[retval] = 0;
		init_waitqueue_head(&zynq_dev.ev_q[retval]);
	}
	zynq_dev.total_ev = 0;

	retval = init_misc_devs();
	if (retval < 0) {
		ERR("misc device init failed!");
		goto err_miscdev;
	}

	retval = init_sysfs_files();
	if (retval < 0) {
		ERR("alloc/dealloc files could not be created!");
		goto err_sysfs_files;
	}

	retval = init_iomapping();
	if (retval < 0) {
		ERR("I/O remapping failed!");
		goto err_iomapping;
	}

	LOG(ZYNQ_LL_ENTEREXIT, "exit" );
	return 0;

	exit_iomapping();
err_iomapping:
	exit_sysfs_files();
err_sysfs_files:
	exit_misc_devs();
err_miscdev:
	LOG(ZYNQ_LL_ENTEREXIT, "exit with error %d", retval);
	return retval;
}

void zynq_device_exit(void)
{
	LOG(ZYNQ_LL_ENTEREXIT, "enter" );
	LOG(ZYNQ_LL_DEVICE, "unmapping I/O areas");
	exit_iomapping();
	LOG(ZYNQ_LL_DEVICE, "releasing sysfs device files");
	exit_sysfs_files();
	LOG(ZYNQ_LL_DEVICE, "releasing devices");
	exit_misc_devs();
	LOG(ZYNQ_LL_ENTEREXIT, "exit" );
}
