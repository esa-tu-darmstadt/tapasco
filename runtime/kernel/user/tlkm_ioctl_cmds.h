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
//! @file	tlkm_ioctl.h
//! @brief	Defines ioctl commands for the top-level TLKM device file.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TLKM_IOCTL_CMDS_H__
#define TLKM_IOCTL_CMDS_H__

#include "tlkm_types.h"
#include "tlkm_access.h"

#define TLKM_DEVNAME_SZ 30
#define TLKM_VERSION_SZ 30
#define TLKM_DEVS_SZ 10

#ifndef __KERNEL__
#include <sys/ioctl.h>
#include <stdlib.h>
#else
#include <linux/ioctl.h>
#endif

typedef u32 dev_id_t;
typedef struct tlkm_device_info {
	dev_id_t dev_id;
	u32 vendor_id;
	u32 product_id;
	char name[TLKM_DEVNAME_SZ];
} tlkm_device_info_t;

struct tlkm_ioctl_version_cmd {
	char version[TLKM_VERSION_SZ];
};

struct tlkm_ioctl_enum_devices_cmd {
	size_t num_devs;
	tlkm_device_info_t devs[10];
};

struct tlkm_ioctl_device_cmd {
	dev_id_t dev_id;
	tlkm_access_t access;
};

#define TLKM_IOCTL_FN "tlkm"

#ifdef _TLKM_IOCTL
#undef _TLKM_IOCTL
#endif

#define TLKM_IOCTL_CMDS                                                        \
	_TLKM_IOCTL(VERSION, version, 1, struct tlkm_ioctl_version_cmd)        \
	_TLKM_IOCTL(ENUM_DEVICES, enum_devices, 2,                             \
		    struct tlkm_ioctl_enum_devices_cmd)                        \
	_TLKM_IOCTL(CREATE_DEVICE, create_device, 3,                           \
		    struct tlkm_ioctl_device_cmd)                              \
	_TLKM_IOCTL(DESTROY_DEVICE, destroy_device, 4,                         \
		    struct tlkm_ioctl_device_cmd)

enum {
#define _TLKM_IOCTL(NAME, name, id, dt) TLKM_IOCTL_##NAME = _IOWR('t', id, dt),
	TLKM_IOCTL_CMDS
#undef _X
};

#endif /* TLKM_IOCTL_CMDS_H__ */
