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
#include <linux/uaccess.h>
#include <linux/string.h>
#include <linux/miscdevice.h>
#include <linux/eventfd.h>
#include "tlkm_logging.h"
#include "tlkm_device_ioctl_cmds.h"
#include "tlkm_bus.h"
#include "tlkm_control.h"

static struct tlkm_control *control_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	return (struct tlkm_control *)container_of(m, struct tlkm_control,
						   miscdev);
}

static struct tlkm_device *device_from_file(struct file *fp)
{
	struct miscdevice *m = (struct miscdevice *)fp->private_data;
	struct tlkm_control *c = (struct tlkm_control *)container_of(
		m, struct tlkm_control, miscdev);
	return tlkm_bus_get_device(c->dev_id);
}

long tlkm_device_ioctl_info(struct file *fp, unsigned int ioctl,
			    struct tlkm_device_info __user *info)
{
	struct tlkm_device_info kinfo;
	struct tlkm_device *kdev;
	struct tlkm_control *c = control_from_file(fp);
	if (!c) {
		ERR("received invalid file pointer");
		return -EFAULT;
	}
	kdev = tlkm_bus_get_device(c->dev_id);
	if (!kdev) {
		ERR("bus has become invalid");
		return -EFAULT;
	}
	kinfo.dev_id = c->dev_id;
	kinfo.vendor_id = kdev->vendor_id;
	kinfo.product_id = kdev->product_id;
	strncpy(kinfo.name, kdev->cls->name, TLKM_DEVNAME_SZ);
	kinfo.name[TLKM_DEVNAME_SZ - 1] = '\0';
	if (copy_to_user((void __user *)info, &kinfo, sizeof(kinfo))) {
		ERR("could not copy all bytes to user space");
		return -EAGAIN;
	}
	return 0;
}

long tlkm_device_ioctl_size(struct file *fp, unsigned int ioctl,
			    struct tlkm_size_cmd __user *size)
{
	struct tlkm_size_cmd ksize;
	struct tlkm_device *kdev;
	struct tlkm_control *c = control_from_file(fp);
	if (!c) {
		ERR("received invalid file pointer");
		return -EFAULT;
	}
	kdev = tlkm_bus_get_device(c->dev_id);
	if (!kdev) {
		ERR("bus has become invalid");
		return -EFAULT;
	}
	ksize.status = 8192;
	ksize.arch = kdev->status.arch_base.size;
	ksize.platform = kdev->status.platform_base.size;
	if (copy_to_user((void __user *)size, &ksize, sizeof(ksize))) {
		ERR("could not copy all bytes to user space");
		return -EAGAIN;
	}
	return 0;
}

long tlkm_device_reg_plat_int(struct file *fp, unsigned int ioctl,
			      struct tlkm_register_interrupt __user *size)
{
	struct tlkm_control *c = control_from_file(fp);
	struct tlkm_register_interrupt s;
	if (!c) {
		ERR("received invalid file pointer");
		return -EFAULT;
	}
	if (copy_from_user(&s, (void __user *)size,
			   sizeof(struct tlkm_register_interrupt))) {
		DEVERR(c->dev_id, "could not copy ioctl data from user space");
		return -EFAULT;
	}
	if (s.pe_id < 0 || s.pe_id >= TLKM_PLATFORM_INTERRUPTS) {
		DEVERR(c->dev_id, "Platform interrupt ID %d out of range.",
		       s.pe_id);
		return -EFAULT;
	}

	if (c->platform_interrupts[s.pe_id] != 0) {
		DEVERR(c->dev_id, "Interrupt of platform %d already taken.",
		       s.pe_id);
		return -EFAULT;
	}

	DEVLOG(c->dev_id, TLKM_LF_CONTROL,
	       "Registering FD %d for platform interrupt %d", s.fd, s.pe_id);
	c->platform_interrupts[s.pe_id] = eventfd_ctx_fdget(s.fd);

	return 0;
}

long tlkm_device_reg_user_int(struct file *fp, unsigned int ioctl,
			      struct tlkm_register_interrupt __user *size)
{
	struct tlkm_control *c = control_from_file(fp);
	struct tlkm_register_interrupt s;
	if (!c) {
		ERR("received invalid file pointer");
		return -EFAULT;
	}
	if (copy_from_user(&s, (void __user *)size,
			   sizeof(struct tlkm_register_interrupt))) {
		DEVERR(c->dev_id, "could not copy ioctl data from user space");
		return -EFAULT;
	}
	if (s.pe_id < 0 || s.pe_id >= PLATFORM_NUM_SLOTS) {
		DEVERR(c->dev_id, "PE ID %d out of range.", s.pe_id);
		return -EFAULT;
	}

	if (c->user_interrupts[s.pe_id] != 0) {
		DEVERR(c->dev_id, "Interrupt of PE ID %d already taken.",
		       s.pe_id);
		return -EFAULT;
	}

	DEVLOG(c->dev_id, TLKM_LF_CONTROL,
	       "Registering FD %d for user interrupt %d", s.fd, s.pe_id);
	c->user_interrupts[s.pe_id] = eventfd_ctx_fdget(s.fd);

	return 0;
}

long tlkm_device_ioctl(struct file *fp, unsigned int ioctl, unsigned long data)
{
	tlkm_perfc_control_ioctls_inc(device_from_file(fp)->dev_id);
	if (ioctl == TLKM_DEV_IOCTL_INFO) {
		return tlkm_device_ioctl_info(
			fp, ioctl, (struct tlkm_device_info __user *)data);
	} else if (ioctl == TLKM_DEV_IOCTL_SIZE) {
		return tlkm_device_ioctl_size(
			fp, ioctl, (struct tlkm_size_cmd __user *)data);
	} else if (ioctl == TLKM_DEV_IOCTL_REGISTER_PLATFORM_INTERRUPT) {
		return tlkm_device_reg_plat_int(
			fp, ioctl,
			(struct tlkm_register_interrupt __user *)data);
	} else if (ioctl == TLKM_DEV_IOCTL_REGISTER_USER_INTERRUPT) {
		return tlkm_device_reg_user_int(
			fp, ioctl,
			(struct tlkm_register_interrupt __user *)data);
	} else {
		tlkm_device_ioctl_f ioctl_f = device_from_file(fp)->cls->ioctl;
		BUG_ON(!ioctl_f);
		return ioctl_f(device_from_file(fp), ioctl, data);
	}
}
