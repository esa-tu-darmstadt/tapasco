#include <linux/list.h>
#include "tlkm_bus.h"
#include "tlkm_devices.h"
#include "tlkm_logging.h"
#include "zynq/tlkm_zynq_enumerate.h"

static
struct tlkm_bus {
	struct list_head devices;
} _tlkm_bus;

void add_device(struct tlkm_device *pdev)
{
	list_add(&pdev->device, &_tlkm_bus.devices);
	LOG(TLKM_LF_DEVICE, "added device '%s' to bus", pdev->name);
}

void del_device(struct tlkm_device *pdev)
{
	list_del(&_tlkm_bus.devices);
	LOG(TLKM_LF_DEVICE, "removed device '%s' from bus", pdev->name);
}

ssize_t tlkm_devices_enumerate(void)
{
	return tlkm_zynq_enumerate(&_tlkm_bus.devices);
}
