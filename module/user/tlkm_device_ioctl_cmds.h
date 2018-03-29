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
//! @file	tlkm_device_ioctl.h
//! @brief	Defines ioctl commands for the TLKM device control files.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TLKM_DEVICE_IOCTL_CMDS_H__
#define TLKM_DEVICE_IOCTL_CMDS_H__

#include "tlkm_types.h"
#include "tlkm_ioctl_cmds.h"

#ifndef __KERNEL__
#include <sys/ioctl.h>
#else
#include <linux/ioctl.h>
#endif

struct tlkm_mm_cmd {
	size_t			sz;
	dev_addr_t		dev_addr;
};

struct tlkm_copy_cmd {
	size_t			length;
	void 			*user_addr;
	dev_addr_t 		dev_addr;
};

struct tlkm_bulk_cmd {
	struct tlkm_mm_cmd	mm;
	struct tlkm_copy_cmd	copy;
};

struct tlkm_dev_cmd {
	size_t			length;
	dev_addr_t		dev_addr;
	void			*user_addr;
};

#define TLKM_DEV_IOCTL_FN		"tlkm_%03u"

#ifdef _TLKM_DEV_IOCTL
	#undef _TLKM_DEV_IOCTL
#endif

#define TLKM_DEV_IOCTL_CMDS \
	_TLKM_DEV_IOCTL(INFO,		0x01, 	struct tlkm_device_info)

	/*
	_TLKM_DEV_IOCTL(ALLOC,		0x10, 	struct tlkm_mm_cmd) \
	_TLKM_DEV_IOCTL(FREE,		0x11,	struct tlkm_mm_cmd) \
	_TLKM_DEV_IOCTL(COPYTO,		0x12,	struct tlkm_copy_cmd) \
	_TLKM_DEV_IOCTL(COPYFROM,	0x13,	struct tlkm_copy_cmd) \
	_TLKM_DEV_IOCTL(ALLOC_COPYTO,	0x20,	struct tlkm_bulk_cmd) \
	_TLKM_DEV_IOCTL(COPYFROM_FREE,	0x21,	struct tlkm_bulk_cmd) \
	_TLKM_DEV_IOCTL(READ,		0x30,	struct tlkm_dev_cmd) \
	_TLKM_DEV_IOCTL(WRITE,		0x31,	struct tlkm_dev_cmd)*/

enum {
#define _TLKM_DEV_IOCTL(name, id, dt) \
	TLKM_DEV_IOCTL_ ## name = _IOWR('d', id, dt),
	TLKM_DEV_IOCTL_CMDS
#undef _TLKM_DEV_IOCTL
};

#endif /* TLKM_DEVICE_IOCTL_CMDS_H__ */
