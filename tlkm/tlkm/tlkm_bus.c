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
#include "pcie/pcie_device.h"

static DEFINE_MUTEX(_tlkm_bus_mtx);

static
struct tlkm_bus {
	struct list_head devices;
	size_t num_devs;
} _tlkm_bus = {
	.devices = LIST_HEAD_INIT(_tlkm_bus.devices),
	.num_devs = 0,
};

static struct tlkm_class *const _tlkm_class[] = {
	(struct tlkm_class *)&zynq_cls,
	(struct tlkm_class *)&pcie_cls,
};

static
void tlkm_bus_add_device(struct tlkm_device *pdev)
{
	mutex_lock(&_tlkm_bus_mtx);
	list_add(&pdev->device, &_tlkm_bus.devices);
	pdev->dev_id = _tlkm_bus.num_devs++;
	mutex_unlock(&_tlkm_bus_mtx);
	LOG(TLKM_LF_BUS, "added device '%s' to bus", pdev->name);
}

static
void tlkm_bus_del_device(struct tlkm_device *pdev)
{
	mutex_lock(&_tlkm_bus_mtx);
	list_del(&_tlkm_bus.devices);
	--_tlkm_bus.num_devs;
	mutex_unlock(&_tlkm_bus_mtx);
	LOG(TLKM_LF_BUS, "removed device '%s' from bus", pdev->name);
}

struct tlkm_device *tlkm_bus_new_device(struct tlkm_class *cls, const char *name, int vendor_id, int product_id, void *data)
{
	int ret = 0;
	struct tlkm_device *dev = (struct tlkm_device *)kzalloc(sizeof(*dev), GFP_KERNEL);
	if (dev) {
		strncpy(dev->name, name, sizeof(dev->name));
		dev->vendor_id = vendor_id;
		dev->product_id = product_id;
		dev->cls = cls;
		tlkm_bus_add_device(dev);
		if ((ret = tlkm_device_init(dev, data))) {
			DEVERR(dev->dev_id, "could not initialize device: %d", ret);
			tlkm_bus_del_device(dev);
			kfree(dev);
			return NULL;
		}
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

ssize_t tlkm_bus_enumerate(void)
{
	int i;
	ssize_t ret = 0;
	for (i = 0; i < sizeof(_tlkm_class)/sizeof(*_tlkm_class); ++i) {
		ssize_t r = _tlkm_class[i]->probe(_tlkm_class[i]);
		if (r < 0)
			ERR("error occurred while probing class '%s': %zd", _tlkm_class[i]->name, r);
		else
			ret += r;
	}
	return ret;
}

int tlkm_bus_init(void)
{
	int ret = 0;
	ssize_t n;
	LOG(TLKM_LF_BUS, "detecting TaPaSCo devices ...");
	n = tlkm_bus_enumerate();
	if (n < 0) {
		ERR("could not detect devices, error: %zd", n);
		return n;
	}
	if (! n) {
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
	list_for_each_safe(lh, tmp, &_tlkm_bus.devices) {
		struct tlkm_device *d = container_of(lh, struct tlkm_device, device);
		LOG(TLKM_LF_BUS, "TaPaSCo device '%s' (%04x:%04x)", d->name,
				d->vendor_id, d->product_id);
		if (d->cls->destroy)
			d->cls->destroy(d);
	}
	for (i = 0; i < sizeof(_tlkm_class)/sizeof(*_tlkm_class); ++i)
		_tlkm_class[i]->remove(_tlkm_class[i]);
	tlkm_exit();
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
	while (! list_empty(lh) && idx > 0) {
		lh = lh->next;
		--idx;
	}
#ifndef NDEBUG
	if (list_empty(lh))
		ERR("invalid device index #%zd", idx);
#endif
	return list_empty(lh) ?
			NULL  :
			container_of(lh, struct tlkm_device, device);
}
