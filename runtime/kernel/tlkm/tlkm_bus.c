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
#include <linux/list.h>
#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/string.h>
#include <linux/mutex.h>
#include <linux/perf_event.h>
#include "tlkm_bus.h"
#include "tlkm_class.h"
#include "tlkm.h"
#include "tlkm_bus.h"
#include "tlkm_logging.h"
#include "pcie/pcie.h"
#include "zynq/zynq.h"
#include "zynq/zynqmp.h"
#include "pcie/pcie_device.h"

#ifdef ENABLE_SIM
#include "sim/sim.h"
#endif

static DEFINE_MUTEX(_tlkm_bus_mtx);

static struct tlkm_bus {
	struct list_head devices;
	size_t num_devs;
} _tlkm_bus = {
	.num_devs = 0,
};

static struct tlkm_class *const _tlkm_class[] = {
	(struct tlkm_class *)&zynq_cls,
	(struct tlkm_class *)&zynqmp_cls,
	(struct tlkm_class *)&pcie_cls,
	(struct tlkm_class *)&pcie_aws_cls,
#ifdef ENABLE_SIM
	(struct tlkm_class *)&sim_cls,
#endif
};

static void tlkm_bus_add_device(struct tlkm_device *pdev)
{
	mutex_lock(&_tlkm_bus_mtx);
	list_add_tail(&pdev->device, &_tlkm_bus.devices);
	pdev->dev_id = _tlkm_bus.num_devs++;
	mutex_unlock(&_tlkm_bus_mtx);
	LOG(TLKM_LF_BUS, "added '%s' device to bus", pdev->cls->name);
}

static void tlkm_bus_del_device(struct tlkm_device *pdev)
{
	mutex_lock(&_tlkm_bus_mtx);
	list_del(&pdev->device);
	--_tlkm_bus.num_devs;
	mutex_unlock(&_tlkm_bus_mtx);
	LOG(TLKM_LF_BUS, "removed '%s' device from bus", pdev->cls->name);
}

struct tlkm_device *tlkm_bus_new_device(struct tlkm_class *cls, int vendor_id,
					int product_id, void *data)
{
	int ret = 0;
	struct tlkm_device *dev =
		(struct tlkm_device *)kzalloc(sizeof(*dev), GFP_KERNEL);
	if (dev) {
		dev->vendor_id = vendor_id;
		dev->product_id = product_id;
		dev->cls = cls;
		tlkm_bus_add_device(dev);
		if ((ret = tlkm_device_init(dev, data))) {
			DEVERR(dev->dev_id, "could not initialize device: %d",
			       ret);
			tlkm_bus_del_device(dev);
			kfree(dev);
			return NULL;
		}
		strncpy(dev->name, cls->name, TLKM_DEVICE_NAME_LEN);
		dev->name[TLKM_DEVICE_NAME_LEN - 1] = '\0';
		mutex_init(&dev->mtx);
		return dev;
	} else {
		ERR("could not allocate new tlkm_device");
		return NULL;
	}
}

void tlkm_bus_delete_device(struct tlkm_device *dev)
{
	if (dev) {
		tlkm_device_exit(dev);
		tlkm_bus_del_device(dev);
		kfree(dev);
	}
}

void tlkm_bus_enumerate(void)
{
	int i, r;
	for (i = 0; i < sizeof(_tlkm_class) / sizeof(*_tlkm_class); ++i) {
		if ((r = _tlkm_class[i]->probe(_tlkm_class[i])))
			ERR("error occurred while probing class '%s': %d",
			    _tlkm_class[i]->name, r);
	}
}

int tlkm_bus_init(void)
{
	int ret = 0;
	ssize_t n;
	INIT_LIST_HEAD(&_tlkm_bus.devices);
	LOG(TLKM_LF_BUS, "detecting TaPaSCo devices ...");
	tlkm_bus_enumerate();
	n = tlkm_bus_num_devices();
	if (!n) {
		ERR("did not find any TaPaSCo devices, cannot proceed");
		ret = -ENXIO;
		goto err;
	}
	LOG(TLKM_LF_BUS, "found %zd TaPaSCo devices", n);
	if ((ret = tlkm_init())) {
		ERR("failed to initialize main ioctl file: %d", ret);
		goto err;
	}
	return ret;

err:
	tlkm_bus_exit();
	return ret;
}

void tlkm_bus_exit(void)
{
	struct list_head *lh;
	struct list_head *tmp;
	int i;
	LOG(TLKM_LF_BUS, "removing ioctl file ...");
	tlkm_exit();
	LOG(TLKM_LF_BUS, "removing devices ...");
	list_for_each_safe (lh, tmp, &_tlkm_bus.devices) {
		struct tlkm_device *d =
			list_entry(lh, struct tlkm_device, device);
		LOG(TLKM_LF_BUS, "TaPaSCo device #%02u '%s' (%04x:%04x)",
		    d->dev_id, d->name, d->vendor_id, d->product_id);
		tlkm_bus_delete_device(d);
	}
	LOG(TLKM_LF_BUS, "removing classes ...");
	for (i = 0; i < sizeof(_tlkm_class) / sizeof(*_tlkm_class); ++i) {
		LOG(TLKM_LF_BUS, "removing class %s", _tlkm_class[i]->name);
		_tlkm_class[i]->remove(_tlkm_class[i]);
	}
	LOG(TLKM_LF_BUS, "removed TaPaSCo interfaces, bye");
}

size_t tlkm_bus_num_devices(void)
{
	return _tlkm_bus.num_devs;
}

struct tlkm_device *tlkm_bus_get_device(size_t idx)
{
	struct list_head *lh;
	lh = _tlkm_bus.devices.next;
	while (!list_empty(lh) && idx > 0) {
		lh = lh->next;
		--idx;
	}
#ifndef NDEBUG
	if (list_empty(lh))
		ERR("invalid device index #%zd", idx);
#endif
	return list_empty(lh) ? NULL :
				container_of(lh, struct tlkm_device, device);
}
