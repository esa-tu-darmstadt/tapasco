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

// TODO:
// Fix Interrupts for F1 and Zynq
// Add init function with start to interrupt list
// reg_int does nothing for them
// Interrupts iterate over list and call eventfd if necessary
// Alternative: Reg sets list start for different interrupts so iteration is faster.

long tlkm_device_reg_int(struct file *fp, unsigned int ioctl,
			 struct tlkm_register_interrupt __user *size)
{
	struct tlkm_control *c = control_from_file(fp);
	struct tlkm_device *dev = device_from_file(fp);
	struct list_head *ptr;
	struct tlkm_irq_mapping *entry;
	struct tlkm_irq_mapping *new_entry;
	long result = 0;

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

	list_for_each (ptr, &c->interrupts) {
		entry = list_entry(ptr, struct tlkm_irq_mapping, list);
		if (entry->irq_no == s.pe_id) {
			DEVERR(c->dev_id,
			       "Interrupt of platform %d already taken.",
			       s.pe_id);
			return -EFAULT;
		}
	}

	DEVLOG(c->dev_id, TLKM_LF_CONTROL,
	       "Registering FD %d for platform interrupt %d", s.fd, s.pe_id);

	new_entry = kzalloc(sizeof(struct tlkm_irq_mapping), GFP_KERNEL);
	new_entry->irq_no = s.pe_id;
	new_entry->dev = dev;

	result = dev->cls->pirq(dev, new_entry);

	if (result) {
		kfree(new_entry);
		DEVERR(c->dev_id, "Failed to register interrupt %d: %ld",
		       s.pe_id, result);
		return result;
	}

	new_entry->eventfd = eventfd_ctx_fdget(s.fd);

	if (list_empty(&c->interrupts)) {
		DEVLOG(c->dev_id, TLKM_LF_CONTROL, "Inserted at the start");
		list_add(&new_entry->list, &c->interrupts);
	} else {
		list_for_each (ptr, &c->interrupts) {
			entry = list_entry(ptr, struct tlkm_irq_mapping, list);
			if (entry->irq_no > s.pe_id) {
				list_add_tail(&new_entry->list, ptr);
				break;
			}
		}
		if (ptr == &c->interrupts) {
			list_add_tail(&new_entry->list, ptr);
		}
	}

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
	} else if (ioctl == TLKM_DEV_IOCTL_REGISTER_INTERRUPT) {
		return tlkm_device_reg_int(
			fp, ioctl,
			(struct tlkm_register_interrupt __user *)data);
	} else {
		tlkm_device_ioctl_f ioctl_f = device_from_file(fp)->cls->ioctl;
		BUG_ON(!ioctl_f);
		return ioctl_f(device_from_file(fp), ioctl, data);
	}
}
