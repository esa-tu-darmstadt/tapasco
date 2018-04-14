#include <linux/list.h>
#include <linux/perf_event.h>
#include "tlkm_bus.h"
#include "tlkm.h"
#include "tlkm_bus.h"
#include "tlkm_logging.h"
#include "zynq/zynq_enumerate.h"
#include "pcie/pcie.h"
#include "pcie/pcie_device.h"

static
struct tlkm_bus {
	struct list_head devices;
	size_t num_devs;
} _tlkm_bus = {
	.devices = LIST_HEAD_INIT(_tlkm_bus.devices),
	.num_devs = 0,
};

void tlkm_bus_add_device(struct tlkm_device *pdev)
{
	list_add(&pdev->device, &_tlkm_bus.devices);
	pdev->dev_id = _tlkm_bus.num_devs++;
	LOG(TLKM_LF_BUS, "added device '%s' to bus", pdev->name);
}

void tlkm_bus_del_device(struct tlkm_device *pdev)
{
	list_del(&_tlkm_bus.devices);
	--_tlkm_bus.num_devs;
	LOG(TLKM_LF_BUS, "removed device '%s' from bus", pdev->name);
}

ssize_t tlkm_bus_enumerate(void)
{
	return zynq_enumerate() + pcie_enumerate();
}

int tlkm_bus_init(void)
{
	int ret = 0;
	ssize_t n;
	struct list_head *lh;
	LOG(TLKM_LF_BUS, "registering drivers ...");
	if ((ret = pcie_init())) {
		ERR("error while registering PCIe driver: %d", ret);
		return ret;
	}
	LOG(TLKM_LF_BUS, "detecting TaPaSCo devices ...");
	n = tlkm_bus_enumerate();
	if (n < 0) {
		ERR("could not detect devices, error: %zd", n);
		pcie_deinit();
		return n;
	}
	if (! n) {
		ERR("did not find any TaPaSCo devices, cannot proceed");
		pcie_deinit();
		return -ENXIO;
	}
	LOG(TLKM_LF_BUS, "found %zd TaPaSCo devices", n);
	list_for_each(lh, &_tlkm_bus.devices) {
		struct tlkm_device *d = container_of(lh, struct tlkm_device,
				device);
		LOG(TLKM_LF_BUS, "TaPaSCo device '%s' (%04x:%04x)", d->name,
				d->vendor_id, d->product_id);
		tlkm_device_create(d, TLKM_ACCESS_MONITOR);
	}
	if ((ret = tlkm_init())) {
		ERR("failed to initialize ioctl file: %d", ret);
		pcie_deinit();
	}
	return ret;
}

void tlkm_bus_exit(void)
{
	struct list_head *lh;
	list_for_each(lh, &_tlkm_bus.devices) {
		struct tlkm_device *d = container_of(lh, struct tlkm_device,
				device);
		LOG(TLKM_LF_BUS, "TaPaSCo device '%s' (%04x:%04x)", d->name,
				d->vendor_id, d->product_id);
		tlkm_device_remove_all(d);
	}
	pcie_deinit();
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
