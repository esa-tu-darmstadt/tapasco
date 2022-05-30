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
#ifndef TLKM_IOCTL_H__
#define TLKM_IOCTL_H__

#include <linux/fs.h>

struct tlkm_ioctl_dev_list_head {
	struct list_head head;
};

struct tlkm_ioctl_dev_list_entry {
	struct list_head list;
	struct tlkm_device *pdev;
	tlkm_access_t access;
};

long tlkm_ioctl_ioctl(struct file *fp, unsigned int ioctl, unsigned long data);

#endif /* TLKM_IOCTL_H__ */
