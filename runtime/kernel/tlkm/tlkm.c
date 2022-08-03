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
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/module.h>
#include <linux/atomic.h>
#include <linux/slab.h>
#include "tlkm.h"
#include "tlkm_ioctl_cmds.h"
#include "tlkm_ioctl.h"
#include "tlkm_logging.h"
#include "tlkm_device.h"

static struct {
	struct miscdevice miscdev;
	int is_setup;
} _tlkm;

static int tlkm_miscdev_open(struct inode *inode, struct file *filp);
static int tlkm_miscdev_release(struct inode *inode, struct file *filp);

static const struct file_operations _tlkm_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = tlkm_ioctl_ioctl,
	.open = tlkm_miscdev_open,
	.release = tlkm_miscdev_release
};

static atomic_t opened_counter;

int tlkm_init(void)
{
	atomic_set(&opened_counter, 0);
	LOG(TLKM_LF_MODULE, "initializing ioctl file " TLKM_IOCTL_FN " ...");
	_tlkm.miscdev.minor = MISC_DYNAMIC_MINOR;
	_tlkm.miscdev.name = TLKM_IOCTL_FN;
	_tlkm.miscdev.fops = &_tlkm_fops;
	_tlkm.miscdev.mode = 0666;
	_tlkm.is_setup = 1;
	return misc_register(&_tlkm.miscdev);
}

void tlkm_exit(void)
{
	if (_tlkm.is_setup)
		misc_deregister(&_tlkm.miscdev);
	LOG(TLKM_LF_MODULE, "removed ioctl file " TLKM_IOCTL_FN);
}

static int tlkm_miscdev_open(struct inode *inode, struct file *filp)
{
	tlkm_ioctl_data *tmp = NULL;
	atomic_inc(&opened_counter);
	LOG(TLKM_LF_MODULE, "Device is now opened %d times.",
	    atomic_read(&opened_counter));
	filp->private_data =
		(tlkm_ioctl_data *)kmalloc(sizeof(tlkm_ioctl_data), GFP_KERNEL);
	if (!filp->private_data)
		return -ENODEV;
	tmp = (tlkm_ioctl_data *)filp->private_data;
	tmp->pdev = NULL;
	return 0;
}

static int tlkm_miscdev_release(struct inode *inode, struct file *filp)
{
	tlkm_ioctl_data *tmp = NULL;
	atomic_dec(&opened_counter);
	LOG(TLKM_LF_MODULE, "Device is still opened %d times.",
	    atomic_read(&opened_counter));
	if (filp->private_data != NULL) {
		tmp = (tlkm_ioctl_data *)filp->private_data;
		if (tmp->pdev) {
			tlkm_device_release(tmp->pdev, tmp->access);
		}
		kfree(filp->private_data);
		filp->private_data = NULL;
	}
	return 0;
}
