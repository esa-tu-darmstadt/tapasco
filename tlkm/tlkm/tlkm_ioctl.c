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
//! @file	tlkm_ioctl.c
//! @brief	Implementations of ioctl commands for control.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <linux/uaccess.h>
#include <linux/string.h>
#include "tlkm_bus.h"
#include "tlkm_module.h"
#include "tlkm_logging.h"
#include "tlkm_ioctl.h"
#include "tlkm_ioctl_cmds.h"

static const char _tlkm_version[] = TLKM_VERSION;

static
long tlkm_ioctl_version(struct file *fp, unsigned int ioctl,
		struct tlkm_ioctl_version_cmd __user *cmd)
{
	LOG(TLKM_LF_IOCTL, "version command received");
	if (copy_to_user((void __user *)cmd->version, &_tlkm_version,
			strlen(_tlkm_version))) {
		ERR("could not copy version string to user space");
		return -EACCES;
	}
	return 0;
}

static
long tlkm_ioctl_enum_devices(struct file *fp, unsigned int ioctl,
		struct tlkm_ioctl_enum_devices_cmd __user *cmd)
{
	size_t i;
	struct tlkm_ioctl_enum_devices_cmd ret;
	LOG(TLKM_LF_IOCTL, "enumerate devices command received");
	ret.num_devs = tlkm_bus_num_devices();
	LOG(TLKM_LF_IOCTL, "has %zd devices", ret.num_devs);
	for (i = 0; i < ret.num_devs; ++i) {
		struct tlkm_device *pd = tlkm_bus_get_device(i);
		if (pd) {
			strncpy(ret.devs[i].name, pd->name, TLKM_DEVNAME_SZ);
            ret.devs[i].name[TLKM_DEVNAME_SZ - 1] = '\0';
			ret.devs[i].vendor_id = pd->vendor_id;
			ret.devs[i].product_id = pd->product_id;
		} else {
			ERR("number of devices reported by bus is wrong");
			return -EFAULT;
		}
	}

	if (copy_to_user((void __user *)cmd, &ret, sizeof(ret))) {
		ERR("failed to copy enumerate data to user space");
		return -EAGAIN;
	}
	return 0;
}

static
long tlkm_ioctl_create_device(struct file *fp, unsigned int ioctl,
		struct tlkm_ioctl_device_cmd __user *cmd)
{
	struct tlkm_ioctl_device_cmd kc;
	if (copy_from_user(&kc, (void __user *)cmd, sizeof(kc))) {
		ERR("could not copy create device command from user space");
		return -EACCES;
	}
	LOG(TLKM_LF_IOCTL, "create device #%02u command received", kc.dev_id);
	return tlkm_device_acquire(tlkm_bus_get_device(kc.dev_id), kc.access);
}

static
long tlkm_ioctl_destroy_device(struct file *fp, unsigned int ioctl,
		struct tlkm_ioctl_device_cmd __user *cmd)
{
	struct tlkm_ioctl_device_cmd kc;
	if (copy_from_user(&kc, (void __user *)cmd, sizeof(kc))) {
		ERR("could not copy destroy device command from user space");
		return -EACCES;
	}
	LOG(TLKM_LF_IOCTL, "destroy device #%02u command received", kc.dev_id);
	tlkm_device_release(tlkm_bus_get_device(kc.dev_id), kc.access);
	return 0;
}

#ifdef _TLKM_IOCTL
	#undef _TLKM_IOCTL
#endif

long tlkm_ioctl_ioctl(struct file *fp, unsigned int ioctl, unsigned long data)
{
#define _TLKM_IOCTL(NAME, name, id, dt) \
	if (ioctl == TLKM_IOCTL_ ## NAME) { \
		return tlkm_ioctl_ ## name(fp, ioctl, (dt __user *)data); \
	}
	TLKM_IOCTL_CMDS
#undef _X
	ERR("illegal ioctl received: 0x%08x", ioctl);
	return -EIO;
}
