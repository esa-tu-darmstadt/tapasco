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
#include "tlkm_module.h"
#include "tlkm_perfc.h"
#include "tlkm_perfc_miscdev.h"
#include "tlkm_logging.h"

#ifndef NDEBUG
#define TLKM_PERFC_MISCDEV_BUFSZ			512

static
struct tlkm_perfc_miscdev_t {
	struct miscdevice 	miscdev;
} tlkm_perfc_miscdev;

static
ssize_t tlkm_perfc_miscdev_read(struct file *file, char __user *usr, size_t sz,
		loff_t *loff)
{
	ssize_t sl;
#define _PC(name) STR(name) ":\t%8lu\n"
	const char *const fmt = TLKM_PERFC_COUNTERS "TLKM version:\t%s\n";
#undef _PC
	char tmp[TLKM_PERFC_MISCDEV_BUFSZ];
#define _PC(name) (unsigned long int)tlkm_perfc_ ## name ## _get(),
	LOG(TLKM_LF_PERFC, "reading %zu bytes at off %lld "
			"from performance counters ...", sz, loff ? *loff : -1);
	snprintf(tmp, TLKM_PERFC_MISCDEV_BUFSZ, fmt, TLKM_PERFC_COUNTERS
			TLKM_VERSION);
	sl = strlen(tmp) + 1;
	if (sl - *loff > 0) {
	  ssize_t rl = strlen(&tmp[*loff]) + 1;
	  *loff += rl - copy_to_user(usr, tmp, strlen(&tmp[*loff]) + 1);
	  LOG(TLKM_LF_PERFC, "new loff: %lld", *loff);
	  return rl;
	}
	return 0;
}

static
const struct file_operations tlkm_perfc_miscdev_fops = {
	.owner = THIS_MODULE,
	.read  = tlkm_perfc_miscdev_read,
};

int tlkm_perfc_miscdev_init(void)
{
	int ret = 0;
	LOG(TLKM_LF_PERFC, "setup /dev/" TLKM_PERFC_MISCDEV_FILENAME " ...");
	tlkm_perfc_miscdev.miscdev.minor = MISC_DYNAMIC_MINOR;
	tlkm_perfc_miscdev.miscdev.name  = TLKM_PERFC_MISCDEV_FILENAME;
	tlkm_perfc_miscdev.miscdev.fops  = &tlkm_perfc_miscdev_fops;
	if ((ret = misc_register(&tlkm_perfc_miscdev.miscdev))) {
		ERR("could not setup /dev/" TLKM_PERFC_MISCDEV_FILENAME ": %d",
				ret);
		return ret;
	}
	LOG(TLKM_LF_PERFC, "/dev/" TLKM_PERFC_MISCDEV_FILENAME " is set up");
	return 0;
}

void tlkm_perfc_miscdev_exit(void)
{
	misc_deregister(&tlkm_perfc_miscdev.miscdev);
	LOG(TLKM_LF_PERFC, "removed performance counter miscdev");
}
#endif /* NDEBUG */
