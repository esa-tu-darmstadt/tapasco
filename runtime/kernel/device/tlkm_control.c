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

#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/fs.h>
#include <linux/version.h>
#include <linux/eventfd.h>
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 11, 0)
#include <linux/sched.h>
#else
#include <linux/sched/signal.h>
#endif
#include "tlkm_logging.h"
#include "tlkm_control.h"
#include "tlkm_perfc.h"
#include "tlkm_device_ioctl.h"
#include "tlkm_device_mmap.h"
#include "user/tlkm_device_ioctl_cmds.h"
#include "tlkm_bus.h"

static const struct file_operations _tlkm_control_fops = {
	.unlocked_ioctl = tlkm_device_ioctl,
	.mmap = tlkm_device_mmap,
	.release = tlkm_control_release,
};

static int init_miscdev(struct tlkm_control *pctl)
{
	char fn[16];
	snprintf(fn, 16, TLKM_DEV_IOCTL_FN, pctl->dev_id);
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "creating miscdevice %s", fn);
	pctl->miscdev.minor = MISC_DYNAMIC_MINOR;
	pctl->miscdev.name = kstrdup(fn, GFP_KERNEL);
	pctl->miscdev.fops = &_tlkm_control_fops;
	return misc_register(&pctl->miscdev);
}

static void exit_miscdev(struct tlkm_control *pctl)
{
	misc_deregister(&pctl->miscdev);
	kfree(pctl->miscdev.name);
	pctl->miscdev.name = NULL;
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "destroyed miscdevice");
}

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

int tlkm_control_release(struct inode *inode, struct file *file)
{
	struct tlkm_control *c = control_from_file(file);
	struct tlkm_device *dev = device_from_file(file);
	struct list_head *ptr, *next;
	struct tlkm_irq_mapping *entry;
	DEVLOG(c->dev_id, TLKM_LF_CONTROL, "Releasing control device");

	list_for_each_safe (ptr, next, &c->interrupts) {
		entry = list_entry(ptr, struct tlkm_irq_mapping, list);
		eventfd_ctx_put(entry->eventfd);
		entry->eventfd = 0;
		dev->cls->rirq(dev, entry);
		list_del(&entry->list);
		kfree(entry);
	}

	if (dev->cls->miscdev_close) {
		dev->cls->miscdev_close(dev);
	}

	return 0;
}

int tlkm_control_init(dev_id_t dev_id, struct tlkm_control **ppctl)
{
	int ret;
	struct tlkm_control *p = (struct tlkm_control *)kzalloc(
		sizeof(struct tlkm_control), GFP_KERNEL);
	if (!p) {
		DEVERR(dev_id, "could not allocate struct tlkm_control");
		return -ENOMEM;
	}
	p->dev_id = dev_id;

	if ((ret = init_miscdev(p))) {
		DEVERR(dev_id, "could not initialize control: %d", ret);
		goto err_miscdev;
	}

	INIT_LIST_HEAD(&p->interrupts);

	*ppctl = p;
	DEVLOG(dev_id, TLKM_LF_CONTROL, "initialized control");
	return 0;

err_miscdev:
	kfree(p);
	return ret;
}

void tlkm_control_exit(struct tlkm_control *pctl)
{
	if (pctl) {
		exit_miscdev(pctl);
		DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "destroyed control");
		kfree(pctl);
	}
}
