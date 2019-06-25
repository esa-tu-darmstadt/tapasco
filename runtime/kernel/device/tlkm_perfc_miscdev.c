//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
//! @file	tlkm_perfc_miscdev.h
//! @brief	Misc device interface to TaPaSCo performance counters.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/miscdevice.h>
#include <linux/uaccess.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include "tlkm_module.h"
#include "tlkm_perfc.h"
#include "tlkm_perfc_miscdev.h"
#include "tlkm_logging.h"
#include "tlkm_device_ioctl_cmds.h"

#ifndef NPERFC
#define TLKM_PERFC_MISCDEV_BUFSZ			768

inline static
dev_id_t get_dev_id_from_file(struct file *file)
{
	struct miscdevice *dev = (struct miscdevice *)file->private_data;
	struct tlkm_device *inst = container_of(dev,
			struct tlkm_device, perfc_dev);
	return inst->dev_id;
}

static
ssize_t tlkm_perfc_miscdev_read(struct file *file, char __user *usr, size_t sz,
		loff_t *loff)
{
	ssize_t sl;
	dev_id_t dev_id = get_dev_id_from_file(file);
#define _PC(name) STR(name) ":\t%8lu\n"
	const char *const fmt = TLKM_PERFC_COUNTERS "TLKM version:\t%s\n";
#undef _PC
	char tmp[TLKM_PERFC_MISCDEV_BUFSZ];
#define _PC(name) (unsigned long int)tlkm_perfc_ ## name ## _get(dev_id),
	snprintf(tmp, TLKM_PERFC_MISCDEV_BUFSZ, fmt, TLKM_PERFC_COUNTERS
			TLKM_VERSION);
	sl = strlen(tmp) + 1;
	if (sl - *loff > 0) {
		ssize_t rl = strlen(&tmp[*loff]) + 1;
		*loff += rl - copy_to_user(usr, tmp, strlen(&tmp[*loff]) + 1);
		return rl;
	}
	return 0;
}

static
const struct file_operations tlkm_perfc_miscdev_fops = {
	.owner = THIS_MODULE,
	.read  = tlkm_perfc_miscdev_read,
};

int tlkm_perfc_miscdev_init(struct tlkm_device *dev)
{
	int ret = 0;
	char fn[256];
	snprintf(fn, 256, TLKM_DEV_PERFC_FN, dev->dev_id);
	DEVLOG(dev->dev_id, TLKM_LF_PERFC, "setting up performance counter file %s ...", fn);
	dev->perfc_dev.minor = MISC_DYNAMIC_MINOR;
	dev->perfc_dev.name  = kstrdup(fn, GFP_KERNEL);
	dev->perfc_dev.fops  = &tlkm_perfc_miscdev_fops;
	if ((ret = misc_register(&dev->perfc_dev))) {
		DEVERR(dev->dev_id, "could not setup %s: %d", fn, ret);
		return ret;
	}
	DEVLOG(dev->dev_id, TLKM_LF_PERFC, "%s is set up", fn);
	return 0;
}

void tlkm_perfc_miscdev_exit(struct tlkm_device *dev)
{
	kfree(dev->perfc_dev.name);
	misc_deregister(&dev->perfc_dev);
	memset(&dev->perfc_dev, 0, sizeof(dev->perfc_dev));
	DEVLOG(dev->dev_id, TLKM_LF_PERFC, "removed performance counter miscdev");
}
#endif /* NPERFC */
